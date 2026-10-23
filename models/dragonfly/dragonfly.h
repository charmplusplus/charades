#ifndef DRAGONFLY_H_
#define DRAGONFLY_H_

/**
 * \file dragonfly.h
 * Dragonfly network model (derived from the CODES dragonfly model), ported
 * from the ROSS-style C API to the Charades LP API.
 *
 * Topology: groups of routers-per-group (a) routers, fully connected inside a
 * group by local channels; each router has global-channels (h, even) global
 * channels to other groups and terminals-per-router (p) compute-node
 * terminals. There are a*h + 1 groups, so every pair of groups is joined by
 * exactly one global channel. Each terminal has one MPI process LP that
 * generates messages according to the traffic pattern.
 *
 * LP global ids: routers [0, R), terminals [R, R + T), MPI processes
 * [R + T, R + 2T), with R = a * groups and T = p * R. Router r owns
 * terminals R + r*p .. R + r*p + p-1 and the MPI processes behind them. The
 * mapper puts routers-per-chare routers on each chare together with their
 * terminals and MPI processes (the original model: one router per chare).
 *
 * Time unit: model parameters (delays, bandwidth-derived serialization
 * times, --arrive-rate) are in nanoseconds, as in the original model, and
 * virtual time is integer picoseconds: 1 Time unit = 1 ps, so a delay of d ns
 * is scheduled after llround(1000 * d) units (to_time()). Every delay the
 * model schedules is at least MIN_DELAY (0.1 ns, the smallest constant delay
 * term of the original model): the delays that had no constant term (the
 * first MPI send of each process, exp(arrive-rate), and the release of a
 * waiting packet, exp(arrive-rate / 1000)) are raised to MIN_DELAY, and no
 * event is ever scheduled with zero delay. --lookahead must not exceed
 * MIN_DELAY (checked at startup), so the conservative scheduler can run it.
 *
 * GVT buckets: under the bucketed GVT, set --gvt-bucket-size to about 1 ns
 * (1000). The engine's default of 8 units is 8 ps here, and bucket_hold then
 * holds nearly every remote event for thousands of buckets (base at 4 PEs:
 * 75% done after 180 s, against 0.5 s with 1 ns buckets). The test configs
 * set 1000, and a smaller bucket gets a warning at startup.
 *
 * Message sizes (sizeof, see the static_asserts in dragonfly.C): every
 * message that can go to another LP (generate, router arrival, terminal
 * arrival, credit) fits the 24-byte htram payload slot (PDES_PAYLOAD_BYTES).
 * Self-sent messages never leave their chare and carry what reverse
 * computation needs.
 *
 * Differences from the ROSS-API model this was ported from:
 * - Integer time (above). The topology (a, h, p) and the channel buffer sizes
 *   are options; their defaults are the original #defines. The options are
 *   --arrive-rate (was arrive_rate), --traffic and --routing; the memory
 *   options went (the engine has --buffer-size).
 * - Destinations past the last terminal (they landed on MPI process LPs and
 *   the chunks then looped between routers forever): BISECTION drew its group
 *   from 0..groups, now 0..groups-1; NEAREST_NEIGHBOR, NEAREST_ROUTER and
 *   TRANSPOSE wrap such destinations around to a terminal.
 * - Router waiting list: entries are copies kept in the router (the original
 *   kept pointers to event messages), a waiting chunk records the channel it
 *   waits for (the original never copied it into the WAIT message), and a
 *   credit releases the entry it matched (the original removed the last
 *   entry). The terminal waiting list, which was never filled (a full
 *   terminal aborts, as before), is gone, and so is output_vc_state, which
 *   was written but never read.
 * - Reverse computation is exact: the original's R_SEND reverse returned
 *   early whenever an intermediate group had been drawn and undid a send
 *   that a dropped chunk never made; get_next_stop no longer writes the
 *   intermediate group into the received message.
 * - The latency and hop statistics, commented out in the original, are kept
 *   (see report_stats()); the per-chunk drop messages are printed once per
 *   router. packet_ID and the other debugging-only fields are gone; last_hop
 *   and saved_vc are derived from the previous hop.
 * - ADAPTIVE routing routes minimally, as it did in the original.
 */

#include "charades.h"
#include "pup_stl.h"

#include <deque>
#include <vector>

/** \name Fixed parameters of the original model (ns, bytes, chunks) *///@{
#define MESSAGE_SIZE 512.0
#define PACKET_SIZE 512.0
#define CHUNK_SIZE 32.0

#define GLOBAL_BANDWIDTH 4.7
#define LOCAL_BANDWIDTH 5.25
#define NODE_BANDWIDTH 5.25
#define CREDIT_SIZE 8
#define INJECTION_INTERVAL 3000
#define RESCHEDULE_DELAY 1.0
// time to process a packet at destination terminal
#define MEAN_PROCESS 1.0
#define NUM_VC 1

#define ROUTER_WAITING_PACK_COUNT (1 << 8)
//@}

/** 1 Time unit = 1 ps: Time units per ns */
#define TIME_PER_NS 1000.0
/** Smallest delay the model schedules: 0.1 ns */
#define MIN_DELAY ((Time)100)

/** Converts a delay in ns to Time, never below MIN_DELAY */
inline Time to_time(double ns) {
  Time t = (Time)llround(ns * TIME_PER_NS);
  return t < MIN_DELAY ? MIN_DELAY : t;
}

enum last_hop { GLOBAL, LOCAL, TERMINAL };
enum ROUTING_ALGO { MINIMAL, NON_MINIMAL, ADAPTIVE };
enum TRAFFIC_PATTERN {
  UNIFORM_RANDOM = 1,
  WORST_CASE,
  TRANSPOSE,
  NEAREST_NEIGHBOR,
  BISECTION,
  NEAREST_ROUTER
};

/** \name Configuration (command line), see dragonfly.C *///@{
extern uint32_t g_routers_per_group;   // a (NUM_ROUTER in the original)
extern uint32_t g_global_channels;     // h (GLOBAL_CHANNELS)
extern uint32_t g_terminals_per_router;// p (NUM_TERMINALS)
extern uint32_t g_routing;
extern uint32_t g_traffic;
extern double   g_mean_interval;       // ns (MEAN_INTERVAL, --arrive-rate)
extern uint32_t g_local_vc_size;       // chunks (LOCAL_VC_SIZE)
extern uint32_t g_global_vc_size;      // chunks (GLOBAL_VC_SIZE)
extern uint32_t g_terminal_vc_size;    // chunks (TERMINAL_VC_SIZE)
extern uint32_t g_routers_per_chare;
//@}

/** \name Derived configuration *///@{
extern uint32_t g_num_groups;
extern uint32_t g_total_routers;
extern uint32_t g_total_terminals;
extern uint32_t g_total_procs;
extern uint32_t g_radix;
extern int g_num_packets;
extern int g_num_chunks;
extern int g_max_packets;
//@}

/**
 * \name Messages
 * Fields written by the receiver for reverse computation are named saved_*.
 * A message that can be sent to another LP holds only what it must carry.
 * travel_start is the packet's generation time; it is 32 bits (ps, so up to
 * 4.29 ms of virtual time; checked when packets are generated): the MPI
 * processes stop after INJECTION_INTERVAL / arrive-rate messages, so packets
 * are generated within a few microseconds.
 *///@{

/** MPI process -> its terminal: generate a packet (T_GENERATE) */
struct GenerateMsg {
  uint32_t dest_terminal;
  uint32_t travel_start;
};

/** Terminal -> itself: inject one chunk (T_SEND) */
struct TerminalSendMsg {
  Time saved_available_time;
  uint32_t dest_terminal;
  uint32_t travel_start;
  uint8_t chunk_id;
};

/**
 * Terminal or router -> router: a chunk arrives (R_ARRIVE). The previous hop
 * (prev_lp) gives the last hop type and the sender's output channel, which
 * the original carried as last_hop and saved_vc.
 */
struct RouterArriveMsg {
  Time saved_credit_time;
  uint32_t travel_start;
  uint32_t dest_terminal;
  uint32_t prev_lp;
  int16_t intm_group;
  uint8_t hops;
  uint8_t chunk_id;
};

/** Router -> itself: route and send a chunk (R_SEND) */
struct RouterSendMsg {
  Time saved_available_time;
  uint32_t travel_start;
  uint32_t dest_terminal;
  int16_t intm_group;
  uint16_t saved_chan;
  uint8_t hops;
  uint8_t chunk_id;
  uint8_t last_hop;
};

/** Router -> itself: queue a chunk that found its output channel full (WAIT) */
struct RouterWaitMsg {
  uint32_t travel_start;
  uint32_t dest_terminal;
  int16_t intm_group;
  uint16_t chan;
  uint8_t hops;
  uint8_t chunk_id;
  uint8_t last_hop;
};

/** Router -> terminal: a chunk arrives at its destination (T_ARRIVE) */
struct TerminalArriveMsg {
  Time saved_credit_time;
  uint32_t travel_start;
  uint8_t hops;
  uint8_t chunk_id;
};

/** Credit for one buffer slot of channel vc, back to the previous hop (BUFFER) */
struct CreditMsg {
  uint32_t saved_served;  // router: index of the waiting packet it released
  uint16_t vc;
};

/** Terminal -> itself: the last chunk of a packet was processed (FINISH) */
struct FinishMsg {
  Time saved_max_latency;
  uint32_t travel_start;
  uint8_t hops;
};

/** MPI process -> itself: send the next message (MPI_SEND) */
struct ProcSendMsg {
  Time saved_available_time;
};
//@}

/** \name Id helpers *///@{
inline bool is_router(uint64_t gid) { return gid < g_total_routers; }
inline bool is_terminal(uint64_t gid) {
  return gid >= g_total_routers && gid < g_total_routers + g_total_terminals;
}
/** Terminal index (0..T-1) of terminal gid */
inline uint32_t terminal_index(uint64_t gid) { return gid - g_total_routers; }
/** Router of terminal gid */
inline uint32_t terminal_router(uint64_t gid) {
  return terminal_index(gid) / g_terminals_per_router;
}
/** Global channel i (0..h-1) of router r: the router it leads to */
uint32_t global_channel(uint32_t r, uint32_t i);
//@}

/** A chunk waiting in a router for a credit on channel chan */
struct WaitEntry {
  uint32_t travel_start;
  uint32_t dest_terminal;
  int16_t intm_group;
  uint16_t chan;
  uint8_t hops;
  uint8_t chunk_id;
  uint8_t last_hop;
  uint8_t served;   // released by a credit (may still be rolled back)
  uint8_t retired;  // released by a committed credit
};
PUPbytes(WaitEntry);

class RouterLP : public LP<RouterLP, RouterArriveMsg, RouterSendMsg,
                           RouterWaitMsg, CreditMsg> {
  private:
    uint32_t group_id;
    std::vector<uint32_t> global_channels;
    std::vector<Time> next_output_available_time;  // per port
    std::vector<Time> next_credit_available_time;  // per port
    std::vector<int32_t> vc_occupancy;             // per channel

    /**
     * Chunks waiting for a credit, oldest first. A released entry stays
     * (marked served) until the credit that released it commits, so that
     * reverse computation can put it back; entry i of the list has index
     * wait_base + i, which credits record in saved_served.
     */
    std::deque<WaitEntry> waiting;
    uint32_t wait_base;
    uint32_t wait_count;  // waiting entries not served

    // Statistics
    uint64_t dropped_packets;  // chunks dropped: output full on first hop
    uint64_t wait_drops;       // chunks dropped: waiting list full
    uint64_t waits;            // chunks that waited for a credit
    // Set by commit handlers only: a drop message was printed
    uint8_t drop_reported, wait_drop_reported;

    uint32_t next_stop(RouterSendMsg* msg, tw_bf* bf, int16_t& intm);
    uint32_t output_port(uint32_t next_stop, uint32_t dest_terminal) const;
    uint32_t sender_chan(uint32_t prev_lp) const;
    uint8_t last_hop_from(uint32_t prev_lp) const;

  public:
    RouterLP();
    void initialize();
    void finalize();

    void forward(RouterArriveMsg* msg, tw_bf* bf);
    void reverse(RouterArriveMsg* msg, tw_bf* bf);
    void commit(RouterArriveMsg* msg, tw_bf* bf) {}

    void forward(RouterSendMsg* msg, tw_bf* bf);
    void reverse(RouterSendMsg* msg, tw_bf* bf);
    void commit(RouterSendMsg* msg, tw_bf* bf);

    void forward(RouterWaitMsg* msg, tw_bf* bf);
    void reverse(RouterWaitMsg* msg, tw_bf* bf);
    void commit(RouterWaitMsg* msg, tw_bf* bf);

    void forward(CreditMsg* msg, tw_bf* bf);
    void reverse(CreditMsg* msg, tw_bf* bf);
    void commit(CreditMsg* msg, tw_bf* bf);

    virtual void pup(PUP::er& p) {
      LPBase::pup(p);
      p | group_id;
      p | global_channels;
      p | next_output_available_time;
      p | next_credit_available_time;
      p | vc_occupancy;
      p | waiting;
      p | wait_base;
      p | wait_count;
      p | dropped_packets;
      p | wait_drops;
      p | waits;
      p | drop_reported;
      p | wait_drop_reported;
    }
};

class TerminalLP : public LP<TerminalLP, GenerateMsg, TerminalSendMsg,
                             TerminalArriveMsg, CreditMsg, FinishMsg> {
  private:
    uint32_t router_id;
    int32_t vc_occupancy[NUM_VC];
    Time terminal_available_time;
    Time next_credit_available_time;

    // Statistics
    uint64_t packets_injected;   // last chunk sent (packet_counter)
    uint64_t packets_finished;
    uint64_t total_latency;      // Time units
    uint64_t total_hops;
    Time max_latency;

  public:
    TerminalLP();
    void initialize();
    void finalize();

    void forward(GenerateMsg* msg, tw_bf* bf);
    void reverse(GenerateMsg* msg, tw_bf* bf);
    void commit(GenerateMsg* msg, tw_bf* bf) {}

    void forward(TerminalSendMsg* msg, tw_bf* bf);
    void reverse(TerminalSendMsg* msg, tw_bf* bf);
    void commit(TerminalSendMsg* msg, tw_bf* bf) {}

    void forward(TerminalArriveMsg* msg, tw_bf* bf);
    void reverse(TerminalArriveMsg* msg, tw_bf* bf);
    void commit(TerminalArriveMsg* msg, tw_bf* bf) {}

    void forward(CreditMsg* msg, tw_bf* bf);
    void reverse(CreditMsg* msg, tw_bf* bf);
    void commit(CreditMsg* msg, tw_bf* bf) {}

    void forward(FinishMsg* msg, tw_bf* bf);
    void reverse(FinishMsg* msg, tw_bf* bf);
    void commit(FinishMsg* msg, tw_bf* bf) {}

    virtual void pup(PUP::er& p) {
      LPBase::pup(p);
      p | router_id;
      PUParray(p, vc_occupancy, NUM_VC);
      p | terminal_available_time;
      p | next_credit_available_time;
      p | packets_injected;
      p | packets_finished;
      p | total_latency;
      p | total_hops;
      p | max_latency;
    }
};

class ProcLP : public LP<ProcLP, ProcSendMsg> {
  private:
    int32_t message_counter;
    Time available_time;
    uint32_t router_id;
    uint32_t group_id;
    // For matrix transpose traffic
    int32_t row, col;

  public:
    ProcLP();
    void initialize();
    void finalize();

    void forward(ProcSendMsg* msg, tw_bf* bf);
    void reverse(ProcSendMsg* msg, tw_bf* bf);
    void commit(ProcSendMsg* msg, tw_bf* bf) {}

    virtual void pup(PUP::er& p) {
      LPBase::pup(p);
      p | message_counter;
      p | available_time;
      p | router_id;
      p | group_id;
      p | row;
      p | col;
    }
};

/** Model statistics, summed over LPs in finalize() (see dragonfly.C) */
struct DragonflyStats {
  uint64_t messages_sent;      // by MPI processes
  uint64_t packets_injected;   // last chunk left the terminal
  uint64_t packets_finished;   // last chunk processed at the destination
  uint64_t total_latency;      // Time units, over finished packets
  uint64_t total_hops;         // router hops, over finished packets
  uint64_t max_latency;        // Time units
  uint64_t dropped_packets;    // chunks dropped by routers
  uint64_t waits;              // chunks that waited for a credit
};
void add_stats(const DragonflyStats& s);
/** After tw_run(): sums the statistics over processes and prints them */
void report_stats();

/**
 * Places routers-per-chare consecutive routers on each chare, followed by
 * their terminals and then their MPI processes.
 */
class DragonflyMapper : public LPMapper {
  public:
    uint64_t get_chare_id(uint64_t gid) const {
      uint64_t k = g_routers_per_chare;
      uint64_t kp = k * g_terminals_per_router;
      if (gid < g_total_routers) return gid / k;
      gid -= g_total_routers;
      if (gid < g_total_terminals) return gid / kp;
      return (gid - g_total_terminals) / kp;
    }
    uint64_t get_local_id(uint64_t gid) const {
      uint64_t k = g_routers_per_chare;
      uint64_t kp = k * g_terminals_per_router;
      if (gid < g_total_routers) return gid % k;
      gid -= g_total_routers;
      if (gid < g_total_terminals) return k + gid % kp;
      return k + kp + (gid - g_total_terminals) % kp;
    }
    uint64_t get_global_id(uint64_t chare, uint64_t local) const {
      uint64_t k = g_routers_per_chare;
      uint64_t kp = k * g_terminals_per_router;
      if (local < k) return chare * k + local;
      if (local < k + kp) return g_total_routers + chare * kp + (local - k);
      return g_total_routers + g_total_terminals + chare * kp + (local - k - kp);
    }
    uint64_t get_num_lps(uint64_t chare) const {
      return g_routers_per_chare * (1 + 2 * (uint64_t)g_terminals_per_router);
    }
};

class DragonflyFactory : public LPFactory {
  public:
    LPBase* create_lp(uint64_t gid) const {
      if (gid < g_total_routers) return new RouterLP();
      if (gid < g_total_routers + g_total_terminals) return new TerminalLP();
      return new ProcLP();
    }
};

#endif
