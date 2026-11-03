#ifndef VLSI_H_
#define VLSI_H_

#include "charades.h"
#include "netlist.h"

/** The composed netlist, read once per process before the LPs are created */
extern vlsi::Netlist g_netlist;

/** A pin of the receiving gate changes to value (sent at even times) */
struct PinMsg {
  Time saved_pending;   ///< for reverse: the gate's pending evaluation time before this event
  uint8_t pin;
  uint8_t value;
};

/** The gate evaluates its output, once per time with pin changes (odd times) */
struct EvalMsg {};

/** A clock edge, for flip-flops and random inputs (multiples of the period) */
struct ClockMsg {};

struct VlsiStats {
  uint64_t gate_changes;    ///< committed output changes of combinational gates
  uint64_t flop_changes;    ///< committed flip-flop output changes
  uint64_t input_changes;   ///< committed random input changes
  uint64_t pin_events;      ///< committed pin changes received (= messages)
  uint64_t evaluations;     ///< committed evaluations
};
void add_stats(const VlsiStats& s);

/** The copy number of the inert LPs that pad the LP count */
const uint32_t PAD_COPY = 0xffffffffu;
void report_stats();

class GateLP : public LP<GateLP, PinMsg, EvalMsg, ClockMsg> {
  private:
    uint32_t copy, local;
    uint32_t pins;
    uint8_t type, nin, out;
    Time pending;   ///< the time of this gate's last scheduled evaluation
    VlsiStats stats;

    void send_output(Time offset);

  public:
    GateLP(uint32_t c, uint32_t l);

    virtual void pup(PUP::er& p) {
      LPBase::pup(p);
      p | copy; p | local; p | pins; p | type; p | nin; p | out; p | pending;
      PUParray(p, (char*)&stats, sizeof(stats));
    }

    void initialize();
    void finalize();

    void forward(PinMsg* msg, tw_bf* bf);
    void reverse(PinMsg* msg, tw_bf* bf);
    void commit(PinMsg* msg, tw_bf* bf);

    void forward(EvalMsg* msg, tw_bf* bf);
    void reverse(EvalMsg* msg, tw_bf* bf);
    void commit(EvalMsg* msg, tw_bf* bf);

    void forward(ClockMsg* msg, tw_bf* bf);
    void reverse(ClockMsg* msg, tw_bf* bf);
    void commit(ClockMsg* msg, tw_bf* bf);
};

class GateFactory : public LPFactory {
  public:
    LPBase* create_lp(uint64_t gid) const {
      // Padding (unfilled chunk slots of the balanced layout, and LPs past
      // the layout that fill the last chare): inert LPs that never send
      uint32_t c, l;
      if (!g_netlist.locate(gid, &c, &l)) return new GateLP(PAD_COPY, 0);
      return new GateLP(c, l);
    }
};

#endif
