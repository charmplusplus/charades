#ifndef VLSI_NETLIST_H_
#define VLSI_NETLIST_H_

/*
 * The VLSI workload (RESULTS.md section 190): gate-level simulation of an
 * ITC'99 netlist (.bench), N copies joined in a ring, as ITC'99 itself builds
 * b17, b18 and b19 from smaller circuits joined on their data buses.
 *
 * Copy k's bus inputs (inputs named IN*, the ITC'99 convention) become XOR
 * gates of a random external input and a ring flip-flop, which samples an
 * output of copy k-1 at each clock edge. The flip-flop keeps the ring free of
 * combinational paths between copies. Constant inputs (LOGIC0, LOGIC1) keep
 * their value; the other inputs take a new random value at each clock edge,
 * from a hash of (seed, copy, net, cycle), so they need no random state and
 * do not depend on the layout.
 *
 * Timing: integer ps, a linear delay model (an intrinsic delay by gate type,
 * plus 2 ps per input beyond two and 2 ps per fanout up to eight). ITC'99
 * netlists carry no timing. Every delay is even: a pin change arrives at an
 * even time, and the gate evaluates once, 1 ps later, at an odd time, after
 * every pin change of that time has arrived. Simultaneous pin changes are
 * thus applied together and a pin change never shares a timestamp with an
 * evaluation, so the results do not depend on the order of equal-timestamp
 * events. The clock period exceeds the longest path, so no pin change
 * reaches a flip-flop at a clock edge.
 *
 * Layout (gid order; the model's behaviour does not depend on it). Copies
 * come in groups of --span=s, each group laid over its own range of gids.
 * - Balanced (--chunk=c > 0, the default, RESULTS.md section 192): each
 *   copy is cut into chunks of c nets in file order. A short unit-delay
 *   simulation of one copy (fixed inputs, so the layout depends only on the
 *   circuit) estimates each chunk's events. The group's range is split
 *   into `bins` equal bins of whole chunk slots, and chunks go, heaviest
 *   first, to the least-loaded bin with a free slot; slots not filled, and
 *   the tail of a copy's last chunk, hold inert LPs. With bins = PEs per
 *   group and an engine that block-maps gids evenly, each PE gets one bin.
 *   With span s > 1 a copy's chunks spread over every bin of its group,
 *   with no regard to locality.
 * - File order (--chunk=0, RESULTS.md sections 190-192): with one copy per
 *   node, span s places each copy's i-th slice (file order) on node i of
 *   its group of s nodes, together with the i-th slices of the group's
 *   other copies. ITC'99's .bench files list every flip-flop first, so the
 *   first PE of a copy gets them all (9.8x the mean load for b19).
 *
 * This file and netlist.C use only standard C++, so the ROSS and Devastator
 * ports can share them.
 */

#include <cstdint>
#include <string>
#include <vector>

namespace vlsi {

enum GateType : uint8_t {
  G_CONST0, G_CONST1, G_INPUT, G_DFF,
  G_NOT, G_BUFF, G_AND, G_NAND, G_OR, G_NOR, G_XOR, G_XNOR
};

const uint64_t CLK_TO_Q = 20;      ///< ps from a clock edge to a flip-flop's output change
const uint64_t INPUT_DELAY = 10;   ///< ps from a clock edge to an input's change
const uint64_t EVAL_STEP = 1;      ///< ps from a pin change to the gate's evaluation

struct Fanout {
  uint32_t dest;   ///< local id of the receiving net, in the same copy
  uint8_t pin;
};

/** The output of a gate of type t whose pins (bit i = pin i) are given */
inline int eval(uint8_t t, uint32_t pins, uint8_t nin) {
  uint32_t mask = (nin >= 32) ? 0xffffffffu : ((1u << nin) - 1);
  uint32_t p = pins & mask;
  switch (t) {
    case G_NOT:  return !(p & 1);
    case G_BUFF: return p & 1;
    case G_AND:  return p == mask;
    case G_NAND: return p != mask;
    case G_OR:   return p != 0;
    case G_NOR:  return p == 0;
    case G_XOR:  return __builtin_popcount(p) & 1;
    case G_XNOR: return !(__builtin_popcount(p) & 1);
  }
  return 0;
}

struct Netlist {
  // ---- one copy: original nets (inputs, then gates, in file order), then
  // one external input and one ring flip-flop per bus input
  uint32_t nets = 0, orig = 0;
  std::vector<uint8_t> type, nin, init;
  std::vector<uint16_t> delay;                     ///< gates: pin change to output change, ps
  std::vector<uint32_t> fanin_start, fanin;        ///< CSR, local ids
  std::vector<uint32_t> fan_start;                 ///< CSR fanout within the copy
  std::vector<Fanout> fan;
  std::vector<uint32_t> ring_start, ring;          ///< ring flip-flops in the NEXT copy each net drives (pin 0)
  std::vector<uint32_t> bus, outputs;
  uint32_t gates = 0, flops = 0, random_inputs = 0;
  uint64_t longest_path = 0, period = 0;
  // ---- the composition
  uint32_t copies = 1, span = 1;
  uint64_t seed = 1;
  std::string name;

  /** Reads path and builds one copy; aborts with a message on bad input */
  void load(const std::string& path, uint32_t copies, uint32_t span, uint64_t period, uint64_t seed);

  // ---- the balanced layout (chunk > 0); see the comment at the top
  uint32_t chunk = 0, bins = 1, slots = 0, nchunks = 0;
  uint64_t group_size = 0;
  std::vector<uint32_t> item_slot, slot_item;      ///< item = copy in group * nchunks + chunk
  std::vector<uint64_t> activity;                  ///< estimated events per net (per copy, summed over the profile's cycles)
  double busiest = 1.0;                            ///< the busiest bin's estimated events / the mean bin's

  /** Lays copies out in balanced chunks of `chunk` nets over `bins` bins per
   *  group of span copies (0: file order); call after load() */
  void balance(uint32_t chunk, uint32_t bins);
  /** Fills `activity` (balance() calls it) */
  void profile();

  /** LPs in the layout, inert ones included */
  uint64_t total() const { return chunk ? (uint64_t)(copies / span) * group_size : (uint64_t)copies * nets; }
  uint64_t gid(uint32_t copy, uint32_t local) const;
  /** The net at gid; false for an inert LP (padding) */
  bool locate(uint64_t gid, uint32_t* copy, uint32_t* local) const;
  /** A random input's value from clock edge `cycle` on */
  int input_value(uint32_t copy, uint32_t local, uint64_t cycle) const;
  /** The initial values of a net's pins, as a bitmask */
  uint32_t init_pins(uint32_t local) const;
  /** Fanout count, ring flip-flops included */
  uint32_t fanout(uint32_t local) const {
    return fan_start[local + 1] - fan_start[local] + ring_start[local + 1] - ring_start[local];
  }

 private:
  uint64_t lo(uint32_t part) const { return ((uint64_t)part * nets + span - 1) / span; }
};

}  // namespace vlsi

#endif
