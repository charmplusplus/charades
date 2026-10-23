#include "dragonfly.h"

#include <algorithm>

/*
 * Terminal (compute node) and MPI process LPs. An MPI process generates
 * messages (MPI_SEND, ProcSendMsg) and hands each packet to its terminal
 * (T_GENERATE, GenerateMsg). The terminal breaks the packet into chunks
 * (T_SEND, TerminalSendMsg) and injects them into its router. At the
 * destination terminal each chunk arrives (T_ARRIVE, TerminalArriveMsg) and
 * returns a credit to the router; the last chunk completes the packet
 * (FINISH, FinishMsg).
 */

////////////////////////////////// Terminal //////////////////////////////////

TerminalLP::TerminalLP()
    : router_id(0), terminal_available_time(0), next_credit_available_time(0),
      packets_injected(0), packets_finished(0), total_latency(0),
      total_hops(0), max_latency(0) {
  for (int i = 0; i < NUM_VC; i++) vc_occupancy[i] = 0;
}

void TerminalLP::initialize() {
  // Assign the global router ID
  router_id = terminal_router(gid);
}

void TerminalLP::finalize() {
  DragonflyStats s = {};
  s.packets_injected = packets_injected;
  s.packets_finished = packets_finished;
  s.total_latency = total_latency;
  s.total_hops = total_hops;
  s.max_latency = max_latency;
  add_stats(s);
}

/* packet is generated when MPI message is received from the MPI process LP */
void TerminalLP::forward(GenerateMsg* msg, tw_bf* bf) {
  for (int i = 0; i < g_num_chunks; i++) {
    // Before generating a packet, check if the input queue is available
    double ts = 0.1 + tw_rand_exponential(rng, g_mean_interval / 200);
    int chan = -1;
    for (int j = 0; j < NUM_VC; j++) {
      if (vc_occupancy[j] < (int64_t)g_terminal_vc_size * g_num_chunks) {
        chan = j;
        break;
      }
    }
    if (chan == -1) {
      // The original exits here too (its WAIT path for terminals is unused)
      CkAbort("Dragonfly: terminal injection queue size exceeded\n");
    }
    Event* e = tw_event_new<TerminalSendMsg>(gid, to_time(i + ts), this);
    TerminalSendMsg* m = e->get_data<TerminalSendMsg>();
    m->dest_terminal = msg->dest_terminal;
    m->travel_start = msg->travel_start;
    m->chunk_id = i;
    tw_event_send(e);
  }
}

void TerminalLP::reverse(GenerateMsg* msg, tw_bf* bf) {
  for (int i = 0; i < g_num_chunks; i++) {
    rng.prev();
  }
}

/* Packet is sent once the buffer space is available on the channels */
void TerminalLP::forward(TerminalSendMsg* msg, tw_bf* bf) {
  int vc = 0;
  if (msg->chunk_id == g_num_chunks - 1) {
    bf->c3 = 1;
    packets_injected++;
  }

  // Each packet is broken into chunks and then sent over the channel
  Time now = get_current_time();
  msg->saved_available_time = terminal_available_time;
  int head_delay = (1 / NODE_BANDWIDTH) * CHUNK_SIZE;
  double ts = head_delay + tw_rand_exponential(rng, (double)head_delay / 200);
  terminal_available_time = std::max(terminal_available_time, now);
  terminal_available_time += to_time(ts);

  Event* e = tw_event_new<RouterArriveMsg>(router_id,
      terminal_available_time - now, this);
  RouterArriveMsg* m = e->get_data<RouterArriveMsg>();
  m->travel_start = msg->travel_start;
  m->dest_terminal = msg->dest_terminal;
  m->prev_lp = gid;
  m->intm_group = -1;
  m->hops = 0;
  m->chunk_id = msg->chunk_id;
  tw_event_send(e);

  vc_occupancy[vc]++;
}

void TerminalLP::reverse(TerminalSendMsg* msg, tw_bf* bf) {
  if (bf->c3) packets_injected--;
  terminal_available_time = msg->saved_available_time;
  rng.prev();
  vc_occupancy[0]--;
}

/* chunks arrive at the destination terminal; the last chunk of a packet
 * completes it after a processing delay */
void TerminalLP::forward(TerminalArriveMsg* msg, tw_bf* bf) {
  if (msg->chunk_id == g_num_chunks - 1) {
    bf->c1 = 1;
    double ts = 0.1 + tw_rand_exponential(rng, MEAN_PROCESS / 200);
    Event* e = tw_event_new<FinishMsg>(gid, to_time(ts), this);
    FinishMsg* m = e->get_data<FinishMsg>();
    m->travel_start = msg->travel_start;
    m->hops = msg->hops;
    tw_event_send(e);
  }

  // Credit to the router. Integer division as in the original: the
  // exponential's mean is 0 (it still takes a random number).
  int credit_delay = (1 / NODE_BANDWIDTH) * CREDIT_SIZE;
  double ts = credit_delay + tw_rand_exponential(rng, credit_delay / 1000);
  Time now = get_current_time();
  msg->saved_credit_time = next_credit_available_time;
  next_credit_available_time = std::max(next_credit_available_time, now);
  next_credit_available_time += to_time(ts);

  Event* buf_e = tw_event_new<CreditMsg>(router_id,
      next_credit_available_time - now, this);
  // The router's channel to this terminal
  buf_e->get_data<CreditMsg>()->vc = (g_routers_per_group + g_global_channels +
      terminal_index(gid) % g_terminals_per_router) * NUM_VC;
  tw_event_send(buf_e);
}

void TerminalLP::reverse(TerminalArriveMsg* msg, tw_bf* bf) {
  if (bf->c1) rng.prev();
  rng.prev();
  next_credit_available_time = msg->saved_credit_time;
}

/* buffer status is updated when credit arrives */
void TerminalLP::forward(CreditMsg* msg, tw_bf* bf) {
  if (msg->vc != 0) CkAbort("Dragonfly: invalid terminal VC index\n");
  vc_occupancy[msg->vc]--;
}

void TerminalLP::reverse(CreditMsg* msg, tw_bf* bf) {
  vc_occupancy[msg->vc]++;
}

/* Packet has arrived at the final destination. Update statistics */
void TerminalLP::forward(FinishMsg* msg, tw_bf* bf) {
  Time latency = get_current_time() - msg->travel_start;
  packets_finished++;
  total_latency += latency;
  total_hops += msg->hops;
  if (max_latency < latency) {
    bf->c3 = 1;
    msg->saved_max_latency = max_latency;
    max_latency = latency;
  }
}

void TerminalLP::reverse(FinishMsg* msg, tw_bf* bf) {
  Time latency = get_current_time() - msg->travel_start;
  packets_finished--;
  total_latency -= latency;
  total_hops -= msg->hops;
  if (bf->c3) max_latency = msg->saved_max_latency;
}

/////////////////////////////////// MPI process ///////////////////////////////

ProcLP::ProcLP()
    : message_counter(0), available_time(0), router_id(0), group_id(0),
      row(0), col(0) {}

static inline uint32_t proc_index(uint64_t gid) {
  return gid - g_total_routers - g_total_terminals;
}

void ProcLP::initialize() {
  uint32_t a = g_routers_per_group, p = g_terminals_per_router;
  message_counter = 0;
  router_id = proc_index(gid) / p;
  group_id = proc_index(gid) / (p * a);
  row = proc_index(gid) / (a * p);       // NUM_ROWS
  col = proc_index(gid) % (a * p + 1);   // NUM_COLS

  /** Start a GENERATE event on each LP **/
  double ts = tw_rand_exponential(rng, g_mean_interval);
  Event* e = tw_event_new<ProcSendMsg>(gid, to_time(ts), this);
  tw_event_send(e);
}

void ProcLP::finalize() {
  DragonflyStats s = {};
  s.messages_sent = message_counter;
  add_stats(s);
}

/** The original's destinations can fall past the last terminal (onto the MPI
 * process LPs); wrap them around to a terminal instead */
static inline uint64_t wrap_terminal(int64_t dst) {
  int64_t R = g_total_routers, T = g_total_terminals;
  return R + (((dst - R) % T) + T) % T;
}

/* Starts generating MPI messages at the MPI process LP according to the
 * traffic pattern */
void ProcLP::forward(ProcSendMsg* msg, tw_bf* bf) {
  int64_t a = g_routers_per_group, p = g_terminals_per_router;
  int64_t R = g_total_routers, T = g_total_terminals;
  int64_t G = g_num_groups;
  int64_t offset = p * a - 1;
  int64_t dst_lp = -1;

  if (message_counter >= g_max_packets) {
    bf->c1 = 1;
    return;
  }

  switch (g_traffic) {
    /* bisection traffic pattern sends messages to another randomly selected
     * dragonfly group. It makes sure that the traffic always traverses the
     * global channel */
    case BISECTION: {
      bf->c3 = 1;
      bf->c2 = 1;
      // The original drew from 0..num_groups (one past the last group)
      int64_t grp = tw_rand_integer(rng, 0, G - 1);
      if (grp == group_id) grp = (group_id + (G / 2)) % G;
      int64_t next_group_begin = grp * p * a;
      dst_lp = tw_rand_integer(rng, R + next_group_begin,
                               R + next_group_begin + offset);
    } break;

    /* Worst case traffic pattern always sends messages to the same dragonfly
     * group. This occupies the single global channel connecting the two
     * groups which is why this traffic is called worst-case traffic */
    case WORST_CASE: {
      bf->c3 = 1;
      int64_t next_group_begin = ((group_id + 1) % G) * p * a;
      dst_lp = tw_rand_integer(rng, R + next_group_begin,
                               R + next_group_begin + offset);
    } break;

    /* uniform random sends MPI messages to a randomly selected compute
     * node/terminal from the entire network */
    case UNIFORM_RANDOM: {
      bf->c3 = 1;
      dst_lp = tw_rand_integer(rng, R, R + T - 1);
    } break;

    case TRANSPOSE: {
      if (col == row) {
        bf->c1 = 1;
        return;
      }
      dst_lp = wrap_terminal(R + ((int64_t)col * (a * p) + row));
    } break;

    /* Sends messages to compute nodes connected to the same dragonfly
     * router */
    case NEAREST_NEIGHBOR: {
      int64_t local_offset = proc_index(gid) % p;
      int64_t group_begin = R + ((int64_t)router_id * p);
      dst_lp = wrap_terminal(group_begin + (p - local_offset));
    } break;

    /* Sends messages to compute nodes connected to nearest dragonfly
     * router */
    case NEAREST_ROUTER: {
      int64_t local_offset = proc_index(gid) % p;
      int64_t next_router_begin = R + (((router_id + 1) % R) * p);
      dst_lp = wrap_terminal(next_router_begin + (p - local_offset));
    } break;

    default:
      CkAbort("Dragonfly: undefined traffic pattern\n");
  }

  /* Generate packets of PACKET_SIZE. One MPI message can be much larger than
   * the packet size; in that case break the MPI message into packets */
  Time now = get_current_time();
  if (now > UINT32_MAX) {
    CkAbort("Dragonfly: packet generated after 2^32 ps (travel_start is 32 bits)\n");
  }
  msg->saved_available_time = available_time;
  for (int i = 0; i < g_num_packets; i++) {
    available_time = std::max(now, available_time);
    double ts = 0.1 + tw_rand_exponential(rng, g_mean_interval / 100);
    available_time += to_time(ts);
    // invoke a message at the respective terminal
    Event* e = tw_event_new<GenerateMsg>(gid - g_total_procs,
        available_time - now, this);
    GenerateMsg* m = e->get_data<GenerateMsg>();
    m->dest_terminal = dst_lp;
    m->travel_start = (uint32_t)now;
    message_counter++;
    tw_event_send(e);
  }
  double ts = g_mean_interval + tw_rand_exponential(rng, g_mean_interval / 100);
  Event* e = tw_event_new<ProcSendMsg>(gid, to_time(ts), this);
  tw_event_send(e);
}

void ProcLP::reverse(ProcSendMsg* msg, tw_bf* bf) {
  if (bf->c1) return;
  if (bf->c3) rng.prev();
  if (bf->c2) rng.prev();
  for (int i = 0; i < g_num_packets; i++) {
    rng.prev();
    message_counter--;
  }
  available_time = msg->saved_available_time;
  rng.prev();
}
