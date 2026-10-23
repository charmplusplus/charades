#include "dragonfly.h"

#include <algorithm>

/*
 * Router LP. Ports 0..a-1 are local channels (port i leads to router i of
 * this group), a..a+h-1 global channels, a+h..a+h+p-1 terminal channels; with
 * NUM_VC virtual channels per port, channel c belongs to port c / NUM_VC.
 *
 * Event flow of a chunk: R_ARRIVE (RouterArriveMsg) sends a credit back to
 * the previous hop and schedules R_SEND (RouterSendMsg) to itself, which
 * picks the next stop and sends the chunk on (R_ARRIVE at the next router or
 * T_ARRIVE at the destination terminal). A chunk that finds its output
 * channel full waits (WAIT, RouterWaitMsg) until a credit (CreditMsg) for
 * that channel releases it as a new R_SEND.
 */

uint32_t global_channel(uint32_t r, uint32_t i) {
  int64_t a = g_routers_per_group;
  int64_t offset = (int64_t)(r % a) * (g_global_channels / 2) + 1 + i / 2;
  int64_t c;
  if (i % 2 != 0) {
    c = ((int64_t)r + offset * a) % g_total_routers;
  } else {
    c = (int64_t)r - offset * a;
  }
  if (c < 0) c += g_total_routers;
  return (uint32_t)c;
}

/** The router of group_id's group with a global channel to group gid */
static uint32_t router_from_group_id(int64_t gid, int64_t group_id) {
  int64_t a = g_routers_per_group;
  int64_t group_begin = group_id * a;
  int64_t group_end = group_id * a + a - 1;
  int64_t offset = (gid * a - group_begin) / a;
  if ((gid * a) < group_begin) {
    offset = (group_begin - gid * a) / a;  // take absolute value
  }
  int64_t half_channel = g_global_channels / 2;
  int64_t index = (offset - 1) / (half_channel * a);
  offset = (offset - 1) % (half_channel * a);
  if (index % 2 != 0) {
    return group_end - (offset / half_channel);  // start from the end
  } else {
    return group_begin + (offset / half_channel);
  }
}

RouterLP::RouterLP()
    : group_id(0), wait_base(0), wait_count(0), dropped_packets(0),
      wait_drops(0), waits(0), drop_reported(0), wait_drop_reported(0) {}

void RouterLP::initialize() {
  group_id = gid / g_routers_per_group;
  global_channels.resize(g_global_channels);
  for (uint32_t i = 0; i < g_global_channels; i++) {
    global_channels[i] = global_channel(gid, i);
  }
  next_output_available_time.assign(g_radix, 0);
  next_credit_available_time.assign(g_radix, 0);
  vc_occupancy.assign(g_radix * NUM_VC, 0);
}

void RouterLP::finalize() {
  DragonflyStats s = {};
  s.dropped_packets = dropped_packets + wait_drops;
  s.waits = waits;
  add_stats(s);
}

uint8_t RouterLP::last_hop_from(uint32_t prev_lp) const {
  if (!is_router(prev_lp)) return TERMINAL;
  return prev_lp / g_routers_per_group == group_id ? LOCAL : GLOBAL;
}

/** The output channel prev_lp used to send to this router (saved_vc) */
uint32_t RouterLP::sender_chan(uint32_t prev_lp) const {
  if (!is_router(prev_lp)) return 0;  // the terminal's channel
  if (prev_lp / g_routers_per_group == group_id) {
    return (gid % g_routers_per_group) * NUM_VC;
  }
  for (uint32_t i = 0; i < g_global_channels; i++) {
    if (global_channel(prev_lp, i) == gid) {
      return (g_routers_per_group + i) * NUM_VC;
    }
  }
  CkAbort("Dragonfly: chunk from a router with no channel to this one\n");
  return 0;
}

/* get next stop (terminal or router) according to the routing algorithm */
uint32_t RouterLP::next_stop(RouterSendMsg* msg, tw_bf* bf, int16_t& intm) {
  uint32_t a = g_routers_per_group;
  uint32_t dest_router_id = terminal_router(msg->dest_terminal);
  intm = msg->intm_group;
  if (dest_router_id == gid) {
    return msg->dest_terminal;
  }
  // Generate inter-mediate destination
  if (msg->last_hop == TERMINAL && g_routing == NON_MINIMAL) {
    if (dest_router_id / a != group_id) {
      bf->c2 = 1;
      intm = tw_rand_integer(rng, 0, g_num_groups - 1);
    }
  }
  if (intm == (int16_t)group_id) {
    intm = -1;  // no inter-mediate group
  }
  uint32_t dest_group_id = intm >= 0 ? intm : dest_router_id / a;

  if (group_id == dest_group_id) {
    return dest_router_id;
  }
  uint32_t dest_lp = router_from_group_id(dest_group_id, group_id);
  if (dest_lp == gid) {
    for (uint32_t i = 0; i < g_global_channels; i++) {
      if (global_channels[i] / a == dest_group_id) {
        dest_lp = global_channels[i];
      }
    }
  }
  return dest_lp;
}

/* get output port of the router according to the next packet stop */
uint32_t RouterLP::output_port(uint32_t next_stop, uint32_t dest_terminal) const {
  uint32_t a = g_routers_per_group;
  if (next_stop == dest_terminal) {
    return a + g_global_channels +
           (terminal_index(dest_terminal) % g_terminals_per_router);
  }
  if (next_stop / a != group_id) {
    int port = -1;
    for (uint32_t i = 0; i < g_global_channels; i++) {
      if (global_channels[i] == next_stop) port = a + i;
    }
    if (port < 0) CkAbort("Dragonfly: no global channel to the next stop\n");
    return port;
  }
  return next_stop % a;
}

// Packet arrives at the router (can be an intermediate or final router)
void RouterLP::forward(RouterArriveMsg* msg, tw_bf* bf) {
  uint8_t last_hop = last_hop_from(msg->prev_lp);

  double ts = 0.1 + tw_rand_exponential(rng, g_mean_interval / 200);
  Event* e = tw_event_new<RouterSendMsg>(gid, to_time(ts), this);
  RouterSendMsg* m = e->get_data<RouterSendMsg>();
  m->travel_start = msg->travel_start;
  m->dest_terminal = msg->dest_terminal;
  m->intm_group = msg->intm_group;
  m->hops = msg->hops + 1;
  m->chunk_id = msg->chunk_id;
  m->last_hop = last_hop;

  // Credit to the previous hop (router_credit_send): determine the time in
  // ns to transfer the credit
  int credit_delay;
  if (last_hop == TERMINAL) {
    credit_delay = (1 / NODE_BANDWIDTH) * CREDIT_SIZE;
  } else if (last_hop == GLOBAL) {
    credit_delay = (1 / GLOBAL_BANDWIDTH) * CREDIT_SIZE;
  } else {
    credit_delay = (1 / LOCAL_BANDWIDTH) * CREDIT_SIZE;
  }
  uint32_t chan = sender_chan(msg->prev_lp);
  uint32_t port = chan / NUM_VC;
  Time now = get_current_time();
  msg->saved_credit_time = next_credit_available_time[port];
  next_credit_available_time[port] =
      std::max(now, next_credit_available_time[port]);
  double cts = credit_delay + tw_rand_exponential(rng, (double)credit_delay / 1000);
  next_credit_available_time[port] += to_time(cts);
  Event* buf_e = tw_event_new<CreditMsg>(msg->prev_lp,
      next_credit_available_time[port] - now, this);
  buf_e->get_data<CreditMsg>()->vc = chan;
  tw_event_send(buf_e);

  tw_event_send(e);
}

void RouterLP::reverse(RouterArriveMsg* msg, tw_bf* bf) {
  rng.prev();
  rng.prev();
  uint32_t port = sender_chan(msg->prev_lp) / NUM_VC;
  next_credit_available_time[port] = msg->saved_credit_time;
}

/* send the packet from the router to the next stop (router or terminal) */
void RouterLP::forward(RouterSendMsg* msg, tw_bf* bf) {
  uint32_t a = g_routers_per_group;
  int16_t intm;
  uint32_t next = next_stop(msg, bf, intm);
  uint32_t port = output_port(next, msg->dest_terminal);
  uint32_t output_chan = port * NUM_VC;

  float bandwidth = LOCAL_BANDWIDTH;
  uint32_t buf_size = g_local_vc_size;
  if (port >= a && port < a + g_global_channels) {
    bandwidth = GLOBAL_BANDWIDTH;
    buf_size = g_global_vc_size;
  }
  if (port >= a + g_global_channels) {
    buf_size = g_terminal_vc_size;
  }

  if (vc_occupancy[output_chan] >= (int32_t)buf_size) {
    if (msg->last_hop == TERMINAL) {
      // Buffers overflowed from incoming terminals: the chunk is dropped
      bf->c4 = 1;
      dropped_packets++;
    } else {
      // Wait for a credit on output_chan (router_reschedule_event)
      bf->c3 = 1;
      double ts = 0.1 + tw_rand_exponential(rng, RESCHEDULE_DELAY / 10);
      Event* e = tw_event_new<RouterWaitMsg>(gid, to_time(ts), this);
      RouterWaitMsg* m = e->get_data<RouterWaitMsg>();
      m->travel_start = msg->travel_start;
      m->dest_terminal = msg->dest_terminal;
      m->intm_group = intm;
      m->chan = output_chan;
      m->hops = msg->hops;
      m->chunk_id = msg->chunk_id;
      m->last_hop = msg->last_hop;
      tw_event_send(e);
    }
    return;
  }

  Time now = get_current_time();
  msg->saved_available_time = next_output_available_time[port];
  msg->saved_chan = output_chan;
  double ts = ((1 / bandwidth) * CHUNK_SIZE) +
              tw_rand_exponential(rng, (double)CHUNK_SIZE / 200);
  next_output_available_time[port] =
      std::max(next_output_available_time[port], now) + to_time(ts);
  Time offset = next_output_available_time[port] - now;

  if (next == msg->dest_terminal) {
    Event* e = tw_event_new<TerminalArriveMsg>(next, offset, this);
    TerminalArriveMsg* m = e->get_data<TerminalArriveMsg>();
    m->travel_start = msg->travel_start;
    m->hops = msg->hops;
    m->chunk_id = msg->chunk_id;
    tw_event_send(e);
  } else {
    Event* e = tw_event_new<RouterArriveMsg>(next, offset, this);
    RouterArriveMsg* m = e->get_data<RouterArriveMsg>();
    m->travel_start = msg->travel_start;
    m->dest_terminal = msg->dest_terminal;
    m->prev_lp = gid;
    m->intm_group = intm;
    m->hops = msg->hops;
    m->chunk_id = msg->chunk_id;
    tw_event_send(e);
  }
  vc_occupancy[output_chan]++;
}

void RouterLP::reverse(RouterSendMsg* msg, tw_bf* bf) {
  if (bf->c2) rng.prev();  // the intermediate group
  if (bf->c4) {
    dropped_packets--;
    return;
  }
  rng.prev();  // the reschedule or the send delay
  if (bf->c3) return;
  next_output_available_time[msg->saved_chan / NUM_VC] = msg->saved_available_time;
  vc_occupancy[msg->saved_chan]--;
}

// The original printed every drop; print only each router's first (the
// statistics count them all). Commit handlers run once per committed event,
// in timestamp order, but not at the event's time (get_current_time() is not
// the event's timestamp there), so no time is printed.
void RouterLP::commit(RouterSendMsg* msg, tw_bf* bf) {
  if (bf->c4 && !drop_reported) {
    drop_reported = 1;
    CkPrintf("Router %u buffers overflowed from incoming terminals: chunk "
             "dropped (further drops not reported)\n", gid);
  }
}

/* If a packet arrives at a router and the channel is not available, the
 * router keeps a list of waiting packets and the channels they wait for */
void RouterLP::forward(RouterWaitMsg* msg, tw_bf* bf) {
  if (wait_count >= ROUTER_WAITING_PACK_COUNT) {
    // In the unusual case where all waiting slots are full, drop the packet
    bf->c3 = 1;
    wait_drops++;
    return;
  }
  WaitEntry w = {};
  w.travel_start = msg->travel_start;
  w.dest_terminal = msg->dest_terminal;
  w.intm_group = msg->intm_group;
  w.chan = msg->chan;
  w.hops = msg->hops;
  w.chunk_id = msg->chunk_id;
  w.last_hop = msg->last_hop;
  waiting.push_back(w);
  wait_count++;
  waits++;
}

void RouterLP::reverse(RouterWaitMsg* msg, tw_bf* bf) {
  if (bf->c3) {
    wait_drops--;
    return;
  }
  waiting.pop_back();
  wait_count--;
  waits--;
}

void RouterLP::commit(RouterWaitMsg* msg, tw_bf* bf) {
  if (bf->c3 && !wait_drop_reported) {
    wait_drop_reported = 1;
    CkPrintf("Router %u reached maximum count of waiting packets %d: chunk "
             "dropped (further drops not reported)\n", gid,
             ROUTER_WAITING_PACK_COUNT);
  }
}

/* When a credit arrives, the router channel is updated, and the oldest
 * packet waiting for that channel is sent */
void RouterLP::forward(CreditMsg* msg, tw_bf* bf) {
  uint32_t chan = msg->vc;
  vc_occupancy[chan]--;
  if (wait_count == 0) return;
  for (size_t j = 0; j < waiting.size(); j++) {
    WaitEntry& w = waiting[j];
    if (w.served || w.chan != chan) continue;
    bf->c3 = 1;
    double ts = tw_rand_exponential(rng, g_mean_interval / 1000);
    Event* e = tw_event_new<RouterSendMsg>(gid, to_time(ts), this);
    RouterSendMsg* m = e->get_data<RouterSendMsg>();
    m->travel_start = w.travel_start;
    m->dest_terminal = w.dest_terminal;
    m->intm_group = w.intm_group;
    m->hops = w.hops;
    m->chunk_id = w.chunk_id;
    m->last_hop = w.last_hop;
    tw_event_send(e);
    w.served = 1;
    wait_count--;
    msg->saved_served = wait_base + j;
    break;
  }
}

void RouterLP::reverse(CreditMsg* msg, tw_bf* bf) {
  vc_occupancy[msg->vc]++;
  if (bf->c3) {
    rng.prev();
    waiting[msg->saved_served - wait_base].served = 0;
    wait_count++;
  }
}

void RouterLP::commit(CreditMsg* msg, tw_bf* bf) {
  if (bf->c3) {
    waiting[msg->saved_served - wait_base].retired = 1;
    while (!waiting.empty() && waiting.front().retired) {
      waiting.pop_front();
      wait_base++;
    }
  }
}
