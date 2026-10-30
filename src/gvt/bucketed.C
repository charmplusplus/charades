#include "bucketed.h"
#include "aggregation.h"

#include "controller.h"
#include "event.h"
#include "globals.h"
#include "scheduler.h"
#include "statistics.h"
#include "trigger.h"
#include "util.h"

#include <dlfcn.h>
#include <algorithm>
#ifdef __linux__
#include <sys/resource.h>
#include <sys/syscall.h>
#include <unistd.h>
#endif
#include <float.h>
#include <fstream>
#include <iomanip>
#include <iostream>

#define SENT_IDX(n) ((n)*2)
#define RECV_IDX(n) ((n)*2+1)

BucketGVT::BucketGVT() { init(); }

BucketGVT::BucketGVT(CkGroupID node_waves) {
  init();
  node_waves_on = true;
  node_waves_gid = node_waves;
}

void BucketGVT::init() {
#ifdef __linux__
  // --gvt-trace=3: thread ids, to match a perf profile's threads to ranks
  if (g_tw_gvt_trace >= 3 && CkMyNode() == 0) {
    CkPrintf("GVT trace: PE %d rank %d tid %ld\n", CkMyPe(), CkMyRank(),
             (long)syscall(SYS_gettid));
  }
#endif
  gvt_name = "Bucket GVT";
  node_waves_on = false;
  node_waves = nullptr;
  node_wave_seen = 0;
  node_wave_pending = false;
  wave_combined_t = wave_result_t = 0;
  active = false;
  continuous = true;

  curr_bucket = 0;
  prev_valid = 0;
  start_reductions = 0;
  count_reductions = 0;
  pending_wave = -1;
  executed_at_wave = 0;
  last_starved = true;
  wave_start = 0;
  bucket_size = g_tw_gvt_bucket_size;
  total_buckets = ceil(g_tw_ts_end / bucket_size);
  max_ts = total_buckets * bucket_size;
  clear_buckets = g_tw_clear_buckets ? g_tw_clear_buckets : total_buckets;

  reserve_threshold = g_tw_reserve_threshold;
  if (g_tw_reserve_buckets != 0) {
    reserve_buckets = g_tw_reserve_buckets;
  } else {
    reserve_buckets = total_buckets;
  }

  counts = new int[total_buckets * 2];
  for (int i = 0; i < total_buckets; i++) {
    counts[SENT_IDX(i)] = 0;
    counts[RECV_IDX(i)] = 0;
  }

  if (g_tw_adaptive_buckets) {
    stats = new OffsetStats[total_buckets];
    reserves = new std::list<RemoteEvent*>[total_buckets];
  }
}

thread_local WaveTimers g_wave_timers;
#ifdef CHARADES_HTRAM
extern thread_local double htram_recv_s;
extern thread_local unsigned long long htram_recv_n;
extern thread_local double htram_recv_part[6];
extern thread_local double htram_send_part[3];
extern thread_local unsigned long long htram_send_n;
extern thread_local unsigned long long htram_recv_items, htram_recv_pushes;
extern thread_local unsigned long long htram_input_buffer_overflows;
#endif

void BucketGVT::finalize() {
#ifdef CHARADES_HTRAM
  // --gvt-trace=3: this PE's htram node receives over the run, split into
  // parts (htram_group.h, htram_recv_part)
  if (g_tw_gvt_trace >= 3) {
    std::ofstream t(std::string(g_output_dir) + "recv_parts_" +
                    std::to_string(CkMyPe()) + ".csv");
    t << "pe,rank,calls,items,pushes,total_s,alloc_s,sort_s,free_in_s,"
         "handoff_s,unref_s,own_s,drain_s,overflows\n" << std::setprecision(9);
    t << CkMyPe() << "," << CkMyRank() << "," << htram_recv_n << ","
      << htram_recv_items << "," << htram_recv_pushes << "," << htram_recv_s;
    for (int k = 0; k < 6; k++) t << "," << htram_recv_part[k];
    t << "," << g_wave_timers.drain << "," << htram_input_buffer_overflows << "\n";
  }
#endif
  if (g_tw_gvt_trace >= 5) {
    // execute() and remote sends split into parts, over the run (WaveTimers)
    const WaveTimers& w = g_wave_timers;
    std::ofstream t(std::string(g_output_dir) + "exec_parts_" +
                    std::to_string(CkMyPe()) + ".csv");
    t << "pe,rank,passes,loop_s,send_total_s,produce_s,fp_s,fp_n,fp_miss_s,"
         "remote_s,remote_n,local_s,local_n,flush_idle_s,flush_idle_n,cancel_q_s,"
         "iter_end_s,poll_s,drain_s,rollback_s,fossil_s,flush_gvt_s,flush_gvt_msgs,ctl_gvt_s,"
         "gvt_done_n,send_trim_s,send_charm_s,send_renew_s,send_n,cmi_ipc_s,cmi_am_s,"
         "cmi_send_s,cmi_ipc_n,cmi_am_n,cmi_send_n,cmi_post_s,cmi_progress_s,cmi_post_n,"
         "cmi_progress_n,cmi_progress_did_n\n" << std::setprecision(9);
    t << CkMyPe() << "," << CkMyRank() << ","
      << w.passes << "," << w.loop << "," << w.send_total << "," << w.produce << ","
      << w.fp << "," << w.fp_n << "," << w.fp_miss << "," << w.remote << ","
      << w.remote_n << "," << w.local << "," << w.local_n << "," << w.flush_idle << ","
      << w.flush_idle_n << "," << w.cancel_q << "," << w.iter_end << "," << w.poll
      << "," << w.drain << "," << w.rollback << "," << w.fossil << "," << w.flush_gvt
      << "," << w.flush_gvt_msgs << "," << w.ctl_gvt << "," << w.gvt_done_n;
#ifdef CHARADES_HTRAM
    t << "," << htram_send_part[0] << "," << htram_send_part[1] << ","
      << htram_send_part[2] << "," << htram_send_n;
#else
    t << ",0,0,0,0";
#endif
    // Reconverse's node sends (branch pads-send-timers), if the runtime has them
    // 6 entries: see CMI_SEND_TIMERS in Reconverse's converse.h
    double ct[6] = {0, 0, 0, 0, 0, 0};
    unsigned long long cn[6] = {0, 0, 0, 0, 0, 0};
    auto get = (void (*)(double*, unsigned long long*))dlsym(RTLD_DEFAULT,
        "_Z16CmiSendTimersGetPdPy");
    if (get) get(ct, cn);
    t << "," << ct[0] << "," << ct[1] << "," << ct[2] << "," << cn[0] << "," << cn[1]
      << "," << cn[2] << "," << ct[3] << "," << ct[4] << "," << cn[3] << "," << cn[4]
      << "," << cn[5] << "\n";
  }
  if (g_tw_gvt_trace >= 3 && !pe_snaps.empty()) {
    std::ofstream t(std::string(g_output_dir) + "gvt_pe_" +
                    std::to_string(CkMyPe()) + ".csv");
    t << "pe,rank,wave,t_s,exec_s,drain_s,rollback_s,poll_s,node_gvt_s,recv_s,"
         "node_gvt_n,recv_n,executed\n" << std::fixed << std::setprecision(7);
    for (const PeSnap& p : pe_snaps) {
      t << CkMyPe() << "," << CkMyRank() << "," << p.wave << "," << p.t << ","
        << p.exec << "," << p.drain << "," << p.rollback << "," << p.poll << ","
        << p.node_gvt << "," << p.recv << "," << p.node_gvt_n << "," << p.recv_n
        << "," << p.executed << "\n";
    }
  }
  if (g_tw_gvt_trace >= 4 && !wave_recs.empty()) {
    std::ofstream t(std::string(g_output_dir) + "gvt_rec_" +
                    std::to_string(CkMyPe()) + ".csv");
    t << "wave,pick_us,prev_end_us,contrib_us,exec_us,drain_us,recv_us,"
         "rollback_us,node_gvt_us,events,passed,reason,arrivals,near,lag_mean,"
         "lag_min\n" << std::fixed << std::setprecision(1);
    for (const WaveRec& w : wave_recs) {
      t << w.wave << "," << w.pick_us << "," << w.prev_end_us << ","
        << w.contrib_us << "," << w.exec_us << "," << w.drain_us << ","
        << w.recv_us << "," << w.rollback_us << "," << w.node_gvt_us << ","
        << w.events << "," << w.passed << "," << w.reason << "," << w.arrivals
        << "," << w.near << "," << w.lag_mean << "," << w.lag_min << "\n";
    }
  }
  if (g_tw_gvt_trace >= 2 && node_waves_on && CkMyRank() == 0) {
    if (!node_waves) node_waves = CProxy_NodeWaves(node_waves_gid).ckLocalBranch();
    node_waves->write_proc_waves();
  }
  if (g_tw_gvt_trace && CkMyPe() == 0) {
    std::ofstream t(std::string(g_output_dir) + "gvt_trace.csv");
    t << "start_s,end_s,asked,passed0,valid,completed,bucket,lead0,combined_s,"
         "result_s,prev_valid,transit_first,transit_total\n";
    t << std::fixed << std::setprecision(7);
    for (const WaveRecord& w : trace) {
      t << w.start << "," << w.end << "," << w.asked << "," << w.passed0
        << "," << w.valid << "," << w.completed << "," << w.bucket << ","
        << w.lead0 << "," << w.combined << "," << w.result << "," << w.prev_valid
        << "," << w.transit_first << "," << w.transit_total << "\n";
    }
  }
  if (CkMyPe() == 0) {
    std::cout << std::endl;
    std::cout << "==== BUCKET GVT REDUCTION STATISTICS ========" << std::endl;
    std::cout << "Start Reductions : " << start_reductions << std::endl;
    std::cout << "Count Reductions : " << count_reductions << std::endl;
    std::cout << "Total Reductions : " << start_reductions + count_reductions;
  }

  std::ofstream outfile;
  std::string filename = std::string(g_output_dir) + "gvt_" + std::to_string(CkMyPe()) + ".out";
  outfile.open(filename);
  outfile << std::fixed << std::setprecision(2);

  outfile << "==== REDUCTION STATISTICS ========" << std::endl;
  outfile << "Start Reductions: " << start_reductions << std::endl;
  outfile << "Count Reductions: " << count_reductions << std::endl;
  outfile << "Total Reductions: "
          << start_reductions + count_reductions << std::endl;

  if (g_tw_adaptive_buckets) {
    OffsetStats total;
    OffsetStats weighted;

    for (int i = 0; i < total_buckets; i++) {
      total.regular += stats[i].regular;
      total.anti += stats[i].anti;
      total.held += stats[i].held;
      total.cancelled += stats[i].cancelled;
      total.released += stats[i].released;
      total.lag += stats[i].lag;

      weighted.regular += stats[i].regular * i;
      weighted.anti += stats[i].anti * i;

      if (stats[i].regular) {
        outfile << "==== Offset " << i << " ========" << std::endl;

        outfile << " Regular Events: " << stats[i].regular
                << " Anti Events: " << stats[i].anti
                << " (" << stats[i].anti_ratio() * 100 << "%)" << std::endl;

        outfile << " Held: " << stats[i].held
                << " (" << stats[i].held_ratio() * 100 << "%)" << std::endl;

        outfile << " Cancelled: " << stats[i].cancelled
                << " (" << stats[i].cancelled_ratio() * 100 << "%)"
                << std::endl;

        outfile << " Released: " << stats[i].released
                << " (" << stats[i].released_ratio() * 100 << "%)" << std::endl;

        outfile << " Average lag: " << stats[i].average_lag() << std::endl
                << std::endl;
      }
    }

    outfile << "==== TOTALS ========" << std::endl;
    outfile << " Regular Events: " << total.regular
            << " Anti Events: " << total.anti
            << " (" << total.anti_ratio() * 100 << "%)" << std::endl;

    outfile << " Held: " << total.held
            << " (" << total.held_ratio() * 100 << "%)" << std::endl;

    outfile << " Cancelled: " << total.cancelled
            << " (" << total.cancelled_ratio() * 100 << "%)" << std::endl;

    outfile << " Released: " << total.released
            << " (" << total.released_ratio() * 100 << "%)" << std::endl;
    outfile << " Average lag: " << total.average_lag() << std::endl
            << std::endl;
    outfile << "Average event offset: "
            << (double)weighted.regular / total.regular << std::endl;
    outfile << "Average anti offset: "
            << (double)weighted.anti / total.anti << std::endl;
  }
  outfile.close();
}

void BucketGVT::gvt_begin() {
  attempt_gvt();
  scheduler->gvt_resume();
}

int BucketGVT::buckets_passed() const {
  return (std::min(scheduler->get_min_time(), max_ts) - curr_gvt) / bucket_size;
}

/**
 * Join a GVT round once this PE has passed --gvt-min-buckets buckets (1 by
 * default). Runs settled into either many small GVT steps or few large ones
 * (4 nodes, PHOLD lookahead 100 / mean 1000, the same settings: 13,474 GVTs
 * at 8.5 M ev/s or 7,635 at 12.9), so this asks for the large ones. Capped
 * by what the window lets a PE pass and by the buckets left, so a round can
 * always start.
 */
void BucketGVT::attempt_gvt() {
  int num_passed = buckets_passed();
  int need = g_tw_gvt_min_buckets;
  Time window = PE_VALUE(window);
  if (window) need = std::min<int>(need, std::max<Time>(1, window / bucket_size));
  need = std::max(1, std::min(need, total_buckets - curr_bucket));
  if (num_passed >= need && !active) {
    active = true;
    contribute(sizeof(int), &num_passed, CkReduction::min_int,
        CkCallback(CkReductionTarget(BucketGVT, all_ready), thisProxy));
  }
}

void BucketGVT::all_ready(int num_buckets) {
  start_reductions++;
  send_counts(num_buckets);
}

/**
 * Count waves run back to back, so their pace is set by how soon every PE
 * handles the previous result. With 16-event batches PEs answer quickly,
 * waves come every ~230 us and each completes ~2.7 buckets; with 64-event
 * batches a wave takes ~390 us and completes ~6.6, and the run is 1.35x
 * faster (4 nodes, PHOLD lookahead 100 / mean 1000, W 250) -- and at 16,
 * runs flipped between the two paces. --gvt-wave-events=K paces waves by
 * progress instead: a PE holds its contribution until it has executed K
 * events since its last one, or until it cannot execute (iteration_end).
 */
void BucketGVT::send_counts(int num_buckets) {
  if (g_tw_gvt_wave_events && !last_starved &&
      get_statistics()->events_executed - executed_at_wave <
          g_tw_gvt_wave_events) {
    pending_wave = num_buckets;
    return;
  }
  contribute_counts(num_buckets,
      (g_tw_gvt_wave_events && !last_starved) ? 3 : 0);
}

void BucketGVT::iteration_end(bool starved) {
  last_starved = starved;
  if (pending_wave >= 0 && (starved ||
      get_statistics()->events_executed - executed_at_wave >=
          g_tw_gvt_wave_events)) {
    int n = pending_wave;
    pending_wave = -1;
    contribute_counts(n, starved ? 1 : 2);
  }
}

void BucketGVT::take_pick_snapshot(double result_t) {
  Statistics* s = get_statistics();
  const WaveTimers& w = g_wave_timers;
#ifdef CHARADES_HTRAM
  pick.recv = htram_recv_s;
#else
  pick.recv = 0;
#endif
  pick.valid = true;
  pick.result = result_t;
  pick.t = CmiWallTimer();
  pick.prev_end = w.exec_end;
  pick.exec = s->exec_time;
  pick.drain = w.drain;
  pick.rollback = w.rollback;
  pick.node_gvt = w.node_gvt;
  pick.executed = s->events_executed;
}

void BucketGVT::contribute_counts(int num_buckets, int reason) {
  // Before the counts leave: what the GVT this wave may produce will make
  // due goes now, not when this PE learns that GVT (--agg-flush-ahead)
  agg_flush_ahead();
  if (g_tw_gvt_trace >= 4 && pick.valid && contributions % 4 == 0) {
    Statistics* s = get_statistics();
    const WaveTimers& w = g_wave_timers;
#ifdef CHARADES_HTRAM
    const double recv = htram_recv_s;
#else
    const double recv = 0;
#endif
    const double now = CmiWallTimer(), r = pick.result;
    auto us = [](double d) { return (float)(d * 1e6); };
    wave_recs.push_back({contributions, us(pick.t - r),
        pick.prev_end ? us(pick.prev_end - r) : -1e9f, us(now - r),
        us(s->exec_time - pick.exec), us(w.drain - pick.drain),
        us(recv - pick.recv), us(w.rollback - pick.rollback),
        us(w.node_gvt - pick.node_gvt),
        (unsigned)(s->events_executed - pick.executed), buckets_passed(),
        reason, (unsigned)arr_n, (unsigned)arr_near,
        arr_n ? (float)(arr_lag_sum / arr_n) : -1.f,
        arr_n ? arr_lag_min : -1});
  }
  pick.valid = false;
  arr_n = arr_near = 0;
  arr_lag_sum = 0;
  arr_lag_min = INT_MAX;
  executed_at_wave = get_statistics()->events_executed;
  if (g_tw_gvt_trace >= 3) {
    const int r = CkMyRank(), n = CkMyNodeSize();
    if (contributions % 10 == 0 &&
        (r <= 1 || r == n / 2 || r >= n - 2)) {
      Statistics* s = get_statistics();
#ifdef CHARADES_HTRAM
      const double recv = htram_recv_s;
      const unsigned long long recv_n = htram_recv_n;
#else
      const double recv = 0;
      const unsigned long long recv_n = 0;
#endif
      const WaveTimers& w = g_wave_timers;
      pe_snaps.push_back({contributions, CmiWallTimer(), s->exec_time, w.drain,
                          w.rollback, w.poll, w.node_gvt, recv, w.node_gvt_n,
                          recv_n, (unsigned long long)s->events_executed});
    }
    contributions++;
  }
  int num_passed = buckets_passed();
  if (g_tw_gvt_trace && CkMyPe() == 0) {
    wave_start = CmiWallTimer();
    wave_asked = num_buckets;
    wave_passed = num_passed;
  }

  if (node_waves_on) {
    std::vector<uint64_t> ctl_counters, ctl_hist;
    if (ctl_shared()) {
      ctl_wave_contribute(&ctl_counters, &ctl_hist);
      if (ctl_counters.empty()) ctl_hist.clear();
    }
    std::vector<CmiInt8>& v = node_wave_buf;
    v.clear();
    v.push_back(num_buckets);
    v.push_back(num_passed);
    v.push_back(ctl_counters.size());
    v.push_back(ctl_hist.size());
    for (int i = 0; i < 2 * num_buckets; i++) {
      v.push_back(counts[SENT_IDX(curr_bucket) + i]);
    }
    for (uint64_t c : ctl_counters) v.push_back((CmiInt8)c);
    for (uint64_t h : ctl_hist) v.push_back((CmiInt8)h);
    if (!node_waves) {
      node_waves = CProxy_NodeWaves(node_waves_gid).ckLocalBranch();
      CkAssert(node_waves);
    }
    node_wave_pending = true;
    node_waves->contribute_from(CkMyRank(), v);
    return;
  }

  CkReduction::tupleElement tuple[4];
  tuple[0] = CkReduction::tupleElement(sizeof(int)*2*num_buckets,
                                       &counts[SENT_IDX(curr_bucket)],
                                       CkReduction::sum_int);
  tuple[1] = CkReduction::tupleElement(sizeof(int), &num_passed,
                                       CkReduction::min_int);
  int elements = 2;
  // --ctl-reduction=1: the controller's counters, and on some waves its
  // histogram, ride along (see Controller::wave_contribute)
  std::vector<uint64_t> ctl_counters, ctl_hist;
  if (ctl_shared()) {
    ctl_wave_contribute(&ctl_counters, &ctl_hist);
    // Empty on the waves that carry nothing (--ctl-sparse-waves); every PE
    // makes the same choice for the same wave, so the tuples match
    if (!ctl_counters.empty()) {
      tuple[elements++] = CkReduction::tupleElement(
          sizeof(uint64_t) * ctl_counters.size(), ctl_counters.data(),
          CkReduction::sum_ulong_long);
    }
    if (!ctl_counters.empty() && !ctl_hist.empty()) {
      tuple[elements++] = CkReduction::tupleElement(
          sizeof(uint64_t) * ctl_hist.size(), ctl_hist.data(),
          CkReduction::sum_ulong_long);
    }
  }
  CkReductionMsg* msg = CkReductionMsg::buildFromTuple(tuple, elements);
  CkCallback cb(CkIndex_BucketGVT::check_counts(0), thisProxy);
  msg->setCallback(cb);
  contribute(msg);
}

void BucketGVT::check_counts(CkReductionMsg* msg) {
  int size;
  CkReduction::tupleElement* result;
  msg->toTuple(&result, &size);
  // toTuple copied the data out; the message used to leak on every wave
  delete msg;

  wave_done((const int*)result[0].data,
      (result[0].dataSize / sizeof(int)) / 2, *((int*)result[1].data),
      size > 2 ? (const uint64_t*)result[2].data : nullptr,
      size > 3 ? (const uint64_t*)result[3].data : nullptr,
      size > 3 ? (int)(result[3].dataSize / sizeof(uint64_t)) : 0);

  delete[] result;
}

void BucketGVT::wave_done(const int* counts, int num_buckets,
    int valid_buckets, const uint64_t* ctl, const uint64_t* hist, int nhist) {
  count_reductions++;

  /**
   * A bucket is complete when every PE had passed it at the PREVIOUS wave and
   * the total received in it at the previous wave equals the total sent in it
   * at this one (Mattern's four-counter rule). Comparing one wave's sent and
   * received totals is not enough: each PE reads its counters at a different
   * time while still executing, so an event counted as sent but not yet
   * received can be offset by a later event counted as received but not sent
   * -- e.g. one sent by a PE that read its counters, then got the first event
   * and rolled back into the bucket. Every PE contributes to this wave only
   * after the previous wave's result reached it, so any event received after
   * a PE's previous-wave reading was sent before its sender's reading for this
   * wave, and makes the totals differ.
   */
  int completed_buckets = 0;
  while (completed_buckets < prev_valid && completed_buckets < num_buckets &&
      prev_recv[completed_buckets] == counts[SENT_IDX(completed_buckets)]) {
    completed_buckets++;
    lb_trigger->iteration_done();
  }

  // --gvt-trace: buckets passed by every PE at the previous wave that still
  // have events in transit (sent but not yet received)
  const int prev_valid_in = prev_valid;
  long long transit_first = 0, transit_total = 0;
  if (g_tw_gvt_trace && CkMyPe() == 0) {
    for (int i = completed_buckets; i < std::min(prev_valid, num_buckets); i++) {
      long long t = (long long)counts[SENT_IDX(i)] - prev_recv[i];
      if (i == completed_buckets) transit_first = t;
      transit_total += t;
    }
  }

  /** Keep this wave's received totals for the next wave's comparison */
  prev_valid = std::max(0,
      std::min(valid_buckets, num_buckets) - completed_buckets);
  prev_recv.resize(prev_valid);
  for (int i = 0; i < prev_valid; i++) {
    prev_recv[i] = counts[RECV_IDX(completed_buckets + i)];
  }

  if (g_tw_gvt_trace && CkMyPe() == 0) {
    WaveRecord w;
    w.start = wave_start;
    w.end = CmiWallTimer();
    w.combined = wave_combined_t;
    w.result = wave_result_t;
    w.asked = wave_asked;
    w.passed0 = wave_passed;
    w.valid = valid_buckets;
    w.completed = completed_buckets;
    w.bucket = curr_bucket;
    w.lead0 = (long long)std::min(scheduler->get_min_time(), max_ts) -
              (long long)curr_gvt;
    w.prev_valid = prev_valid_in;
    w.transit_first = transit_first;
    w.transit_total = transit_total;
    trace.push_back(w);
  }

  /**
   * The controller first, so a new window is in force with the GVT that
   * follows; every PE gets the same sums and makes the same decision
   */
  if (ctl) ctl_wave_result(ctl, hist, nhist);

  /** Advance the GVT past the completed buckets */
  if (completed_buckets) advance_gvt(completed_buckets);

  /**
   * If there are still valid buckets then continue to send counts. The next
   * wave asks about the buckets this one left open; with --gvt-ask-ahead, at
   * least that many past GVT. A bucket can complete only if the wave before
   * reported its counts, so asking only about those left open lets a bucket
   * complete about three waves after every PE passed it (in steady state a
   * wave completes a third of the buckets every PE has passed); asking about
   * every bucket up to the window lets it complete one wave after. Every PE
   * computes the same number from the same result and the same window.
   */
  if (valid_buckets - completed_buckets) {
    int next = valid_buckets - completed_buckets;
    int ahead = g_tw_gvt_ask_ahead;
    if (ahead < 0) {
      Time window = PE_VALUE(window);
      ahead = window ? (int)((window + bucket_size - 1) / bucket_size) + 2 : 0;
    }
    next = std::max(next, ahead);
    next = std::min(next, total_buckets - curr_bucket);
    send_counts(next);
  } else {
    active = false;
    attempt_gvt();
  }

}

void BucketGVT::advance_gvt(int num_buckets) {
  prev_gvt = curr_gvt;
  curr_bucket += num_buckets;
  curr_gvt = curr_bucket * bucket_size;

  if (g_tw_adaptive_buckets && curr_bucket < total_buckets) {
    int bucket = curr_bucket;
    int last_bucket = std::min(total_buckets, curr_bucket + clear_buckets);
    do {
      auto iter = reserves[bucket].begin();
      while (iter != reserves[bucket].end()) {
        if ((*iter)->offset - ((*iter)->phase - curr_bucket) > g_tw_clear_lag ||
            bucket == curr_bucket) {
          stats[(*iter)->offset].released++;
          charm_event_release(*iter);
          iter = reserves[bucket].erase(iter);
        } else {
          iter++;
        }
      }
      bucket++;
    } while (bucket < last_bucket);
  }
  if (lb_trigger->ready() && g_tw_ldb_continuous) {
    lb_trigger->reset();
    scheduler->gvt_done(curr_gvt, true);
  } else {
    scheduler->gvt_done(curr_gvt, false);
  }
}

bool key_matches(RemoteEvent* e1, RemoteEvent* e2) {
  return e1->src_lp == e2->src_lp && e1->event_id == e2->event_id;
}

bool BucketGVT::attempt_cancel(RemoteEvent* anti) {
  std::list<RemoteEvent*>& bucket = reserves[anti->phase];
  auto iter = bucket.begin();
  while (iter != bucket.end()) {
    if (key_matches(anti, *iter)) break;
    iter++;
  }

  if (iter != bucket.end()) {
    stats[anti->offset].cancelled++;
    RemoteEvent* original = *iter;
    bucket.erase(iter);
    delete original;
    delete anti;
    return true;
  } else {
    return false;
  }
}

void BucketGVT::consume(RemoteEvent* e) {
  // A bucket completes only when nothing sent in it is still in transit
  TW_ASSERT(e->phase >= curr_bucket, "Event (ts %llu) received in bucket %u, "
      "but GVT completed buckets up to %d\n", (unsigned long long)e->ts, e->phase,
      curr_bucket);
  counts[RECV_IDX(e->phase)]++;
  if (g_tw_gvt_trace >= 4) {
    const int lag = (int)e->phase - curr_bucket;
    arr_n++;
    if (lag <= 1) arr_near++;
    arr_lag_sum += lag;
    if (lag < arr_lag_min) arr_lag_min = lag;
  }
  attempt_gvt();
}

bool BucketGVT::produce(RemoteEvent* e) {
  e->phase = e->ts / bucket_size;
  TW_ASSERT(e->phase >= curr_bucket && e->phase < total_buckets,
      "Event (ts %llu) sent in bucket %u, outside [%d, %d)\n",
      (unsigned long long)e->ts,
      e->phase, curr_bucket, total_buckets);
  counts[SENT_IDX(e->phase)]++;
  attempt_gvt();

  if (g_tw_adaptive_buckets) {
    if (e->anti) {
      int phase = e->phase;
      stats[e->offset].anti++;
      stats[e->offset].lag += e->offset - (e->phase - curr_bucket);
      if (attempt_cancel(e)) {
        PE_STATS(remote_cancels)++;
        PE_STATS(anti_cancels)++;
        counts[SENT_IDX(phase)] -= 2;
        return false;
      } else {
        return true;
      }
    } else {
      e->offset = e->phase - curr_bucket;
      stats[e->offset].regular++;
      if (e->offset > 0 &&
          (e->offset > reserve_buckets ||
          stats[e->offset].anti_ratio() > reserve_threshold)) {
        reserves[e->phase].push_front(e);
        stats[e->offset].held++;
        PE_STATS(remote_holds)++;
        return false;
      } else {
        return true;
      }
    }
  } else {
    return true;
  }
}

unsigned BucketGVT::batch_size() const {
  if (!g_tw_wave_batch || !node_waves) return g_tw_mblock;
  const bool flying = g_tw_wave_batch_when ? node_wave_pending : node_waves->in_flight();
  return flying ? g_tw_wave_batch : g_tw_mblock;
}

void BucketGVT::poll() {
  if (!node_wave_pending || node_waves->generation() <= node_wave_seen) return;
  node_wave_seen++;
  node_wave_pending = false;
  const std::vector<CmiInt8>& r = node_waves->result();
  wave_combined_t = node_waves->t_combined;
  wave_result_t = node_waves->t_result;
  if (g_tw_gvt_trace >= 4) take_pick_snapshot(wave_result_t);
  int n = r[0], nctl = r[2], nhist = r[3];
  std::vector<int> sums(r.begin() + 4, r.begin() + 4 + 2 * n);
  std::vector<uint64_t> ctl(r.begin() + 4 + 2 * n, r.begin() + 4 + 2 * n + nctl);
  std::vector<uint64_t> hist(r.begin() + 4 + 2 * n + nctl, r.end());
  wave_done(sums.data(), n, (int)r[1], nctl ? ctl.data() : nullptr,
      nhist ? hist.data() : nullptr, nhist);
}

NodeWaves::NodeWaves()
    : t_combined(0), t_result(0), slots(CkMyNodeSize()), arrived(0), slot_t(CkMyNodeSize()),
      slot_use(CkMyNodeSize()), prev_use(CkMyNodeSize()), gen(0), flight(false),
      rounds(0), ar_wave(0), ar_round(0), ar_active(false), tree_parent(-1),
      tree_wave(0), tree_in(0), tree_lock(CmiCreateLock()) {
  while ((1 << rounds) < CkNumNodes()) rounds++;
  allreduce = g_tw_gvt_wave_allreduce && (1 << rounds) == CkNumNodes();
  if (g_tw_gvt_wave_allreduce && !allreduce && CkMyNode() == 0) {
    CkPrintf("Bucketed GVT: %d processes is not a power of two; count waves "
             "use the nodegroup reduction\n", CkNumNodes());
  }
  if (g_tw_gvt_wave_tree) {
    if (g_tw_gvt_wave_allreduce) {
      CkAbort("--gvt-wave-tree and --gvt-wave-allreduce exclude each other\n");
    }
    // A k-ary heap over the processes, rooted at process 0
    const long k = g_tw_gvt_wave_tree, me = CkMyNode();
    if (me) tree_parent = (me - 1) / k;
    for (long c = me * k + 1; c <= me * k + k && c < CkNumNodes(); c++) {
      tree_kids.push_back((int)c);
    }
  }
}

void NodeWaves::contribute_from(int rank, const std::vector<CmiInt8>& v) {
  slots[rank].assign(v.begin(), v.end());
  // Each PE stamps its own slot; its increment releases the stamp, and the
  // last PE's increment acquires them all
  if (g_tw_gvt_trace >= 2) {
    slot_t[rank] = CmiWallTimer();
#ifdef RUSAGE_THREAD
    struct rusage u;
    if (getrusage(RUSAGE_THREAD, &u) == 0) {
      slot_use[rank] = {u.ru_minflt, u.ru_nivcsw,
          u.ru_utime.tv_sec * 1e6 + u.ru_utime.tv_usec,
          u.ru_stime.tv_sec * 1e6 + u.ru_stime.tv_usec};
    }
#endif
  }
  if (arrived.fetch_add(1, std::memory_order_acq_rel) + 1 < CkMyNodeSize()) {
    return;
  }
  if (g_tw_gvt_trace >= 3) {
    const double prev = proc_waves.empty() ? 0 : proc_waves.back().result;
    for (int r = 0; r < CkMyNodeSize(); r++)
      rank_delays.push_back(prev ? (float)((slot_t[r] - prev) * 1e6) : 0.f);
  }
  if (g_tw_gvt_trace >= 2) {
    double first = slot_t[0];
    for (int r = 1; r < CkMyNodeSize(); r++) first = std::min(first, slot_t[r]);
    ProcWave w;
    w.first = first; w.last = slot_t[rank]; w.result = 0.0; w.last_rank = rank; w.handled = 0.0;
    for (int r = 0; r < CkMyNodeSize(); r++) {
      const Usage &now = slot_use[r], &was = prev_use[r];
      const double st = now.stime_us - was.stime_us;
      w.minflt += now.minflt - was.minflt;
      w.nivcsw += now.nivcsw - was.nivcsw;
      w.utime_us += now.utime_us - was.utime_us;
      w.stime_us += st;
      if (st > w.stime_max_us || w.stime_max_rank < 0) { w.stime_max_us = st; w.stime_max_rank = r; }
    }
    prev_use = slot_use;
    proc_waves.push_back(w);
  }
  // The last PE in: every slot is written, and none is written again before
  // this wave's result is out
  arrived.store(0, std::memory_order_relaxed);
  flight.store(true, std::memory_order_relaxed);
  if (g_tw_gvt_trace) t_combined = CmiWallTimer();
  combined.assign(slots[0].begin(), slots[0].end());
  for (int r = 1; r < CkMyNodeSize(); r++) {
    combine_wave(combined, slots[r].data(), slots[r].size());
  }
  if (g_tw_gvt_wave_tree) {
    // No hop to this process's own handler: the last PE in adds the sums itself
    tree_add(-1, -1, t_combined, combined.data(), combined.size());
    return;
  }
  thisProxy[CkMyNode()].contribute_combined(combined.size(), combined.data());
}

namespace {
/** --gvt-trace=3: a node-group GVT handler's time, on the PE that ran it */
struct NodeGvtTimer {
  double t0;
  NodeGvtTimer() : t0(g_tw_gvt_trace >= 3 ? CmiWallTimer() : 0) {}
  ~NodeGvtTimer() {
    if (g_tw_gvt_trace >= 3) {
      g_wave_timers.node_gvt += CmiWallTimer() - t0;
      g_wave_timers.node_gvt_n++;
    }
  }
};
}

void NodeWaves::write_proc_waves() const {
  std::ofstream t(std::string(g_output_dir) + "gvt_waves_" +
                  std::to_string(CkMyNode()) + ".csv");
  t << "first_s,last_s,result_s,last_rank,handled_s,minflt,nivcsw,utime_us,stime_us,stime_max_us,stime_max_rank\n"
    << std::fixed;
  for (const ProcWave& w : proc_waves) {
    t << std::setprecision(7) << w.first << "," << w.last << "," << w.result
      << "," << w.last_rank << "," << w.handled << "," << w.minflt << ","
      << w.nivcsw << std::setprecision(0) << "," << w.utime_us << ","
      << w.stime_us << "," << w.stime_max_us << "," << w.stime_max_rank << "\n";
  }
  if (g_tw_gvt_wave_tree) {
    std::ofstream h(std::string(g_output_dir) + "gvt_hops_" +
                    std::to_string(CkMyNode()) + ".csv");
    h << "wave,kind,peer,rank,sent_s,recv_s\n" << std::fixed << std::setprecision(7);
    for (const Hop& x : hops) {
      h << x.wave << "," << x.kind << "," << x.peer << "," << x.rank << ","
        << x.sent << "," << x.recv << "\n";
    }
  }
  if (g_tw_gvt_trace >= 3) {
    std::ofstream r(std::string(g_output_dir) + "gvt_ranks_" +
                    std::to_string(CkMyNode()) + ".csv");
    const int n = CkMyNodeSize();
    for (int i = 0; i < n; i++) r << (i ? "," : "") << "r" << i;
    r << "\n" << std::fixed << std::setprecision(1);
    for (size_t k = 0; k + n <= rank_delays.size(); k += n) {
      for (int i = 0; i < n; i++) r << (i ? "," : "") << rank_delays[k + i];
      r << "\n";
    }
  }
}

void NodeWaves::contribute_combined(int n, CmiInt8* v) {
  NodeGvtTimer timer;
  if (g_tw_gvt_trace >= 2 && !proc_waves.empty()) {
    proc_waves.back().handled = CmiWallTimer();
  }
  if (!allreduce) {
    contribute(n * sizeof(CmiInt8), v, gvtWaveReductionType,
        CkCallback(CkIndex_NodeWaves::wave_result(NULL), thisProxy));
    return;
  }
  ar_buf.assign(v, v + n);
  ar_round = 0;
  ar_active = true;
  if (rounds == 0) {
    publish(ar_buf.data(), n);
    return;
  }
  send_round();
}

/** Sends this round's partial sums, then takes the partner's if it is here */
void NodeWaves::send_round() {
  thisProxy[CkMyNode() ^ (1 << ar_round)].exchange(ar_wave, ar_round,
      ar_buf.size(), ar_buf.data());
  auto it = early.find({ar_wave, ar_round});
  if (it != early.end()) {
    std::vector<CmiInt8> v = std::move(it->second);
    early.erase(it);
    add_partner(v.data(), v.size());
  }
}

void NodeWaves::exchange(int wave, int round, int n, CmiInt8* v) {
  NodeGvtTimer timer;
  if (ar_active && wave == ar_wave && round == ar_round) {
    add_partner(v, n);
  } else {
    early[{wave, round}] = std::vector<CmiInt8>(v, v + n);
  }
}

void NodeWaves::add_partner(const CmiInt8* v, int n) {
  combine_wave(ar_buf, v, n);
  if (++ar_round < rounds) {
    send_round();
  } else {
    publish(ar_buf.data(), ar_buf.size());
  }
}

void NodeWaves::tree_up(int wave, int child, double sent_t, int n, CmiInt8* v) {
  NodeGvtTimer timer;
  tree_add(child, wave, sent_t, v, n);
}

/**
 * One input to this process's partial sums: its own PEs' (child -1) or a
 * child process's. The last input sends the sums to the parent, or at the
 * root starts the result down the tree. A child cannot be a wave ahead: it
 * starts the next wave only after the result reaches it, which is after this
 * process moved on to that wave.
 */
void NodeWaves::tree_add(int child, int wave, double sent_t, const CmiInt8* v, int n) {
  const double now = g_tw_gvt_trace >= 2 ? CmiWallTimer() : 0;
  CmiLock(tree_lock);
  if (child < 0) wave = tree_wave;
  if (wave != tree_wave) {
    CkAbort("Bucketed GVT: process %d got wave %d from process %d during wave %d\n",
        CkMyNode(), wave, child, tree_wave);
  }
  if (g_tw_gvt_trace >= 2) {
    hops.push_back({wave, child < 0 ? 2 : 0, child < 0 ? CkMyRank() : child,
                    CkMyRank(), sent_t, now});
    if (child < 0 && !proc_waves.empty()) proc_waves.back().handled = now;
  }
  if (tree_in++ == 0) {
    tree_buf.assign(v, v + n);
  } else {
    combine_wave(tree_buf, v, n);
  }
  if (tree_in < 1 + (int)tree_kids.size()) {
    CmiUnlock(tree_lock);
    return;
  }
  if (g_tw_gvt_trace >= 2) {
    const double t = CmiWallTimer();
    hops.push_back({wave, 3, tree_parent, CkMyRank(), t, t});
  }
  if (tree_parent >= 0) {
    // The result comes back down before anything touches tree_buf again
    thisProxy[tree_parent].tree_up(wave, CkMyNode(), CmiWallTimer(),
        tree_buf.size(), tree_buf.data());
    CmiUnlock(tree_lock);
    return;
  }
  std::vector<CmiInt8> r = std::move(tree_buf);
  tree_wave++;
  tree_in = 0;
  CmiUnlock(tree_lock);
  tree_send_down(wave, r.data(), r.size());
  publish(r.data(), r.size());
}

void NodeWaves::tree_down(int wave, double sent_t, int n, CmiInt8* v) {
  NodeGvtTimer timer;
  const double now = g_tw_gvt_trace >= 2 ? CmiWallTimer() : 0;
  CmiLock(tree_lock);
  if (wave != tree_wave || tree_in != 1 + (int)tree_kids.size()) {
    CkAbort("Bucketed GVT: process %d got the result of wave %d during wave %d "
        "with %d inputs\n", CkMyNode(), wave, tree_wave, tree_in);
  }
  if (g_tw_gvt_trace >= 2) {
    hops.push_back({wave, 1, tree_parent, CkMyRank(), sent_t, now});
  }
  tree_wave++;
  tree_in = 0;
  CmiUnlock(tree_lock);
  tree_send_down(wave, v, n);
  publish(v, n);
}

/** The children first, so the result is on its way before this process uses it */
void NodeWaves::tree_send_down(int wave, const CmiInt8* v, int n) {
  for (int c : tree_kids) {
    thisProxy[c].tree_down(wave, CmiWallTimer(), n, const_cast<CmiInt8*>(v));
  }
}

void NodeWaves::publish(const CmiInt8* v, int n) {
  res.assign(v, v + n);
  if (g_tw_gvt_trace) t_result = CmiWallTimer();
  if (g_tw_gvt_trace >= 2 && !proc_waves.empty()) proc_waves.back().result = t_result;
  if (allreduce) {
    ar_active = false;
    ar_wave++;
  }
  flight.store(false, std::memory_order_relaxed);
  gen.fetch_add(1, std::memory_order_release);
}

void NodeWaves::wave_result(CkReductionMsg* msg) {
  NodeGvtTimer timer;
  publish((const CmiInt8*)msg->getData(), msg->getSize() / sizeof(CmiInt8));
  delete msg;
}

void combine_wave(std::vector<CmiInt8>& into, const CmiInt8* from, int n) {
  CkAssert(n == (int)into.size() && n >= 4 && into[0] == from[0] &&
      into[2] == from[2] && into[3] == from[3]);
  into[1] = std::min(into[1], from[1]);
  for (int i = 4; i < n; i++) into[i] += from[i];
}

CkReduction::reducerType gvtWaveReductionType;
void registerGvtWaveReduction() {
  gvtWaveReductionType = CkReduction::addReducer(gvtWaveReduction);
}

CkReductionMsg* gvtWaveReduction(int nMsg, CkReductionMsg** msgs) {
  int n = msgs[0]->getSize() / sizeof(CmiInt8);
  const CmiInt8* d0 = (const CmiInt8*)msgs[0]->getData();
  std::vector<CmiInt8> r(d0, d0 + n);
  for (int i = 1; i < nMsg; i++) {
    combine_wave(r, (const CmiInt8*)msgs[i]->getData(),
        msgs[i]->getSize() / sizeof(CmiInt8));
  }
  return CkReductionMsg::buildNew(n * sizeof(CmiInt8), r.data());
}
