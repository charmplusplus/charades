/** \file statistics.C
 *  Definition of the Statistics class and associated methods/variables.
 */

#include "statistics.h"

#include "event.h"
#include "scheduler.h"

#include <stdio.h>  // Included for printf

Statistics* get_statistics() {
  return CpvAccess(g_scheduler)->stats;
}

CkReduction::reducerType statsReductionType;
void registerStatsReduction() {
  statsReductionType = CkReduction::addReducer(statsReduction);
}

/**
 * \param nMsg the number of messages to reduce
 * \param msgs an array of message pointers to the actual messages
 * \returns a single message that is the reduction of the passed in messages
 */
CkReductionMsg *statsReduction(int nMsg, CkReductionMsg **msgs) {
  Statistics* s = new Statistics();

  for (int i = 0; i < nMsg; i++) {
    CkAssert(msgs[i]->getSize() == sizeof(Statistics));

    Statistics* c = (Statistics*)msgs[i]->getData();
    s->reduce(c);
  }

  return CkReductionMsg::buildNew(sizeof(Statistics), s);
}

Statistics::Statistics() {
  clear();
}

void Statistics::clear() {
  // Timing stats
  total_time = 0.0;

  // Event stats
  events_executed = 0;
  events_committed = 0;
  events_rolled_back = 0;

  // Rollback stats
  total_rollback_calls = 0;
  ts_rollback_calls = 0;
  late_stragglers = 0;
  held_stragglers = 0;
  event_rollback_calls = 0;

  // Send stats
  self_sends = 0;
  local_sends = 0;
  remote_sends = 0;
  remote_holds = 0;
  remote_cancels = 0;
  anti_sends = 0;
  anti_cancels = 0;

  // Communication stats
  send_time = 0.0;
  timed_sends = 0;
  agg_items = agg_urgent = agg_direct = 0;
  agg_msgs = agg_bytes = agg_idle_flushes = agg_pp_bypasses = 0;
  agg_msgs_full = agg_msgs_urgent = agg_msgs_idle = agg_msgs_gvt = 0;
  agg_msgs_round = 0;
  remote_arrivals = remote_stragglers = 0;
  iter_full = iter_window = iter_empty = 0;
  exec_time = 0.0;
  rollback_ns = fwd_ns = fwd_timed = 0;
  for (int b = 0; b < SLACK_BUCKETS; b++) slack_hist[b] = 0;
  for (int c = 0; c < LAT_CLASSES; c++) {
    lat_count[c] = 0;
    lat_sum[c] = 0.0;
    for (int b = 0; b < LAT_BUCKETS; b++) lat_hist[c][b] = 0;
  }

  // GVT stats
  total_gvts = 0;

  // Memory stats
  max_events_used = 0;
  new_event_calls = 0;
  del_event_calls = 0;
}

/**
 * The accumulation done here is used when current stats are logged to the
 * tracing file, and then added to the cumulative stats for the PE. This is
 * slightly different that a reduction. One example of a difference, is that the
 * total number of GVTs is summed, where for a reduction they should be the same
 * and are left unmodified.
 */
void Statistics::add(const Statistics* other) {
  // Timing stats
  total_time += other->total_time;

  events_executed += other->events_executed;
  events_committed += other->events_committed;
  events_rolled_back += other->events_rolled_back;

  // Rollback stats
  total_rollback_calls += other->total_rollback_calls;
  ts_rollback_calls += other->ts_rollback_calls;
  late_stragglers += other->late_stragglers;
  held_stragglers += other->held_stragglers;
  event_rollback_calls += other->event_rollback_calls;

  // Send stats
  self_sends += other->self_sends;
  local_sends += other->local_sends;
  remote_sends += other->remote_sends;
  anti_sends += other->anti_sends;
  add_comm(other);

  // GVT stats
  total_gvts += other->total_gvts;

  // Memory stats
  max_events_used = fmax(max_events_used, other->max_events_used);
  new_event_calls += other->new_event_calls;
  del_event_calls += other->del_event_calls;
}

/**
 * The accumulation done here is used when combining cumulative stats from
 * multiple PEs. So for example, the total number of GVTs is left unchanged
 * since every PE does the same number of GVTs.
 */
void Statistics::reduce(const Statistics* other) {
  // Timing stats
  total_time = fmax(total_time, other->total_time);

  events_executed += other->events_executed;
  events_committed += other->events_committed;
  events_rolled_back += other->events_rolled_back;

  // Rollback stats
  total_rollback_calls += other->total_rollback_calls;
  ts_rollback_calls += other->ts_rollback_calls;
  late_stragglers += other->late_stragglers;
  held_stragglers += other->held_stragglers;
  event_rollback_calls += other->event_rollback_calls;

  // Send stats
  self_sends += other->self_sends;
  local_sends += other->local_sends;
  remote_sends += other->remote_sends;
  anti_sends += other->anti_sends;
  add_comm(other);

  // GVT stats
  total_gvts = other->total_gvts;

  // Memory stats
  max_events_used = fmax(max_events_used, other->max_events_used);
  new_event_calls += other->new_event_calls;
  del_event_calls += other->del_event_calls;
}

void Statistics::add_comm(const Statistics* other) {
  iter_full += other->iter_full;
  iter_window += other->iter_window;
  iter_empty += other->iter_empty;
  exec_time += other->exec_time;
  rollback_ns += other->rollback_ns;
  fwd_ns += other->fwd_ns;
  fwd_timed += other->fwd_timed;
  remote_holds += other->remote_holds;
  remote_cancels += other->remote_cancels;
  anti_cancels += other->anti_cancels;
  send_time += other->send_time;
  timed_sends += other->timed_sends;
  agg_items += other->agg_items;
  agg_urgent += other->agg_urgent;
  agg_direct += other->agg_direct;
  agg_msgs += other->agg_msgs;
  agg_bytes += other->agg_bytes;
  agg_idle_flushes += other->agg_idle_flushes;
  agg_pp_bypasses += other->agg_pp_bypasses;
  agg_msgs_full += other->agg_msgs_full;
  agg_msgs_urgent += other->agg_msgs_urgent;
  agg_msgs_idle += other->agg_msgs_idle;
  agg_msgs_gvt += other->agg_msgs_gvt;
  agg_msgs_round += other->agg_msgs_round;
  remote_arrivals += other->remote_arrivals;
  remote_stragglers += other->remote_stragglers;
  for (int b = 0; b < SLACK_BUCKETS; b++) slack_hist[b] += other->slack_hist[b];
  for (int c = 0; c < LAT_CLASSES; c++) {
    lat_count[c] += other->lat_count[c];
    lat_sum[c] += other->lat_sum[c];
    for (int b = 0; b < LAT_BUCKETS; b++) lat_hist[c][b] += other->lat_hist[c][b];
  }
}

int64_t comm_send_begin(RemoteEvent* e) {
  int64_t now = comm_now_ns();
  e->send_ns = now;
  e->src_pe = CkMyPe();
  return now;
}

void comm_record_slack(Time ts, Time current) {
  Statistics* s = get_statistics();
  s->remote_arrivals++;
  if (ts <= current) {
    s->remote_stragglers++;
    return;
  }
  Time slack = ts - current;
  int b = 0;
  while (b < Statistics::SLACK_BUCKETS - 1 && slack >= (2ull << b)) b++;
  s->slack_hist[b]++;
}

/** Upper edge of the slack bucket holding quantile q (0 for stragglers) */
static double slack_quantile(const Statistics* s, double q) {
  uint64_t target = (uint64_t)(q * s->remote_arrivals);
  uint64_t seen = s->remote_stragglers;
  if (seen > target) return 0.0;
  for (int b = 0; b < Statistics::SLACK_BUCKETS; b++) {
    seen += s->slack_hist[b];
    if (seen > target) return (double)(2ull << b);
  }
  return (double)(2ull << (Statistics::SLACK_BUCKETS - 1));
}

void comm_send_end(int64_t start_ns) {
  Statistics* s = get_statistics();
  s->send_time += (comm_now_ns() - start_ns) * 1e-9;
  s->timed_sends++;
}

void comm_record_latency(const RemoteEvent* e) {
  if (e->src_pe < 0) return;  // sent without --comm-stats (not expected)
  int c;
  if (CkNodeOf(e->src_pe) == CkMyNode()) {
    c = 0;
  } else if (CmiPhysicalNodeID(e->src_pe) == CmiPhysicalNodeID(CkMyPe())) {
    c = 1;
  } else {
    c = 2;  // clocks of different nodes are not synchronized: approximate
  }
  int64_t ns = comm_now_ns() - e->send_ns;
  Statistics* s = get_statistics();
  s->lat_count[c]++;
  s->lat_sum[c] += ns * 1e-9;
  int b = 0;
  while (b < Statistics::LAT_BUCKETS - 1 && ns >= (int64_t)(2ll << b)) b++;
  s->lat_hist[c][b]++;
}

/** Upper edge (in microseconds) of the bucket holding quantile q */
static double lat_quantile_us(const uint64_t* hist, uint64_t count, double q) {
  uint64_t target = (uint64_t)(q * count), seen = 0;
  for (int b = 0; b < Statistics::LAT_BUCKETS; b++) {
    seen += hist[b];
    if (seen > target) return (double)(1ull << (b + 1)) / 1000.0;
  }
  return -1.0;
}

/** Print a section title and border */
void Statistics::print_section(const char* name) const {
  CkPrintf("\n\n==== %-32s ==================================\n", name);
}

/** Print a formatted and labeled integer value */
void Statistics::print_int(const char* name, uint64_t v) const {
  CkPrintf("\t%-50s %11lld\n", name, v);
}

/** Print a formatted and labeled double value */
void Statistics::print_double(const char* name, double v) const {
  CkPrintf("\t%-50s %11.2f\n", name, v);
}

/** Print out the entire stats class at the end of a simulation */
void Statistics::print() const {
  /** \todo Add stats about PEs, num nodes, etc? */
  print_section("SUMMARY");
  print_int("Events Committed", events_committed);
  print_double("Execution Time", total_time);
  print_double("Event Rate", events_committed / total_time);

  print_section("EVENT STATISTICS");
  print_int("Total Events Processed", events_executed);
  print_int("Events Committed", events_committed);
  print_int("Events Rolled Back", events_rolled_back);
  print_double("Efficiency", 100.0 * ((double) events_committed / (double) events_executed));

  print_section("GVT STATISTICS");
  print_int("Total GVT Computations", total_gvts);
  if (iter_full + iter_window + iter_empty) {
    print_section("SCHEDULER ITERATIONS");
    print_int("Batches: Full", iter_full);
    print_int("Batches: Window Blocked", iter_window);
    print_int("Batches: Out of Events", iter_empty);
    // exec_time is summed over PEs, total_time is the slowest PE's
    print_double("Time in execute() %", total_time > 0
        ? 100.0 * exec_time / (total_time * CkNumPes()) : 0.0);
  }

  /** \todo Improve these stats to include remote % and also track the sent
   * events that were committed vs those sent and cancelled, or rolled back */
  print_section("SEND STATISTICS");
  print_int("Self Sends", self_sends);
  print_int("Local Sends", local_sends);
  print_int("Remote Sends", remote_sends);
  print_int("Anti Event Sends", anti_sends);

  /** \todo Add stats about cancellations */
  print_section("ROLLBACK STATISTICS");
  print_int("Total Rollback Calls ", total_rollback_calls);
  print_int("Timestamp Rollback Calls ", ts_rollback_calls);
  print_int("Late Stragglers (delay >= window)", late_stragglers);
  print_int("Held Stragglers (late or held by htram)", held_stragglers);
  print_int("Event Rollback Calls ", event_rollback_calls);

  if (remote_holds) {
    print_section("EVENT HOLDING STATISTICS");
    print_int("Remote Events Held", remote_holds);
    print_int("Held Events Cancelled In Sender", anti_cancels);
  }

  if (timed_sends) {
    print_section("COMMUNICATION STATISTICS");
    print_int("Timed Send Calls", timed_sends);
    print_double("Mean Send Call (us)", 1e6 * send_time / timed_sends);
    // Share of all PE time (execution time x PEs) spent inside send calls
    print_double("Send Calls % of PE Time", 100.0 * send_time / (total_time * CkNumPes()));
    const char* names[LAT_CLASSES] = {"Same Process", "Same Node", "Other Node"};
    for (int c = 0; c < LAT_CLASSES; c++) {
      if (!lat_count[c]) continue;
      char label[64];
      snprintf(label, sizeof(label), "Latency %s: Count", names[c]);
      print_int(label, lat_count[c]);
      snprintf(label, sizeof(label), "Latency %s: Mean (us)", names[c]);
      print_double(label, 1e6 * lat_sum[c] / lat_count[c]);
      const double qs[3] = {0.5, 0.9, 0.99};
      const char* qn[3] = {"p50", "p90", "p99"};
      for (int i = 0; i < 3; i++) {
        snprintf(label, sizeof(label), "Latency %s: %s <= (us)", names[c], qn[i]);
        print_double(label, lat_quantile_us(lat_hist[c], lat_count[c], qs[i]));
      }
    }
  }

  if (agg_items || agg_direct) {
    print_section("AGGREGATION STATISTICS");
    print_int("Events Through htram", agg_items);
    print_int("Events Shipped Urgently", agg_urgent);
    print_int("Events Sent Directly", agg_direct);
    print_int("htram Messages", agg_msgs);
    print_double("Events per htram Message", agg_msgs ? (double)agg_items / agg_msgs : 0.0);
    print_double("Bytes per htram Message", agg_msgs ? (double)agg_bytes / agg_msgs : 0.0);
    print_int("htram Idle Flushes", agg_idle_flushes);
    if (agg_pp_bypasses) print_int("htram PP Local Bypasses", agg_pp_bypasses);
    print_int("htram Messages: Buffer Full", agg_msgs_full);
    print_int("htram Messages: Urgent Event", agg_msgs_urgent);
    print_int("htram Messages: Idle Flush", agg_msgs_idle);
    print_int("htram Messages: GVT Update", agg_msgs_gvt);
    print_int("htram Messages: GVT Round", agg_msgs_round);
  }

  if (remote_arrivals) {
    print_section("REMOTE EVENT SLACK");
    print_int("Remote Event Arrivals", remote_arrivals);
    print_double("Remote Stragglers %", 100.0 * remote_stragglers / remote_arrivals);
    print_double("Slack p10 <=", slack_quantile(this, 0.1));
    print_double("Slack p50 <=", slack_quantile(this, 0.5));
    print_double("Slack p90 <=", slack_quantile(this, 0.9));
  }

  print_section("MEMORY STATISTICS");
  print_int("Max Events Allocated on a PE", max_events_used);
  print_int("Remote Event Allocations", new_event_calls);
  print_int("Remote Event Dealloactions", del_event_calls);
}

#if CMK_TRACE_ENABLED
/** Register stats with the Charm++ tracing framework */
void Statistics::init_tracing() {
    EVENTS_EXECUTED = traceRegisterUserStat("Events executed", -1);
    EVENTS_COMMITTED = traceRegisterUserStat("Events committed", -1);
    EVENTS_ROLLED_BACK = traceRegisterUserStat("Events rolled back", -1);

    EFFICIENCY = traceRegisterUserStat("Efficiency", -1);

    SELF_SENDS = traceRegisterUserStat("Self sends", -1);
    LOCAL_SENDS = traceRegisterUserStat("Local sends", -1);
    REMOTE_SENDS = traceRegisterUserStat("Remote sends", -1);
    ANTI_SENDS = traceRegisterUserStat("Anti sends", -1);

    MAX_EVENTS_USED = traceRegisterUserStat("Max event used", -1);
    NEW_EVENT_CALLS = traceRegisterUserStat("New event calls", -1);
    DEL_EVENT_CALLS = traceRegisterUserStat("Delete event calls", -1);
}

/** Update all the stat values for a particular GVT number */
void Statistics::log_tracing(int gvt_num) const {
  updateStatPair(EVENTS_EXECUTED, events_executed, gvt_num);
  updateStatPair(EVENTS_COMMITTED, events_committed, gvt_num);
  updateStatPair(EVENTS_ROLLED_BACK, events_rolled_back, gvt_num);

  updateStatPair(EFFICIENCY, 100.0 * ((double) events_committed / (double) events_executed), gvt_num);

  updateStatPair(SELF_SENDS, self_sends, gvt_num);
  updateStatPair(LOCAL_SENDS, local_sends, gvt_num);
  updateStatPair(REMOTE_SENDS, remote_sends, gvt_num);
  updateStatPair(ANTI_SENDS, anti_sends, gvt_num);

  updateStatPair(MAX_EVENTS_USED, max_events_used, gvt_num);
  updateStatPair(NEW_EVENT_CALLS, new_event_calls, gvt_num);
  updateStatPair(DEL_EVENT_CALLS, del_event_calls, gvt_num);
}
#endif
