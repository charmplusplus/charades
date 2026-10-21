#include "bucketed.h"

#include "event.h"
#include "globals.h"
#include "scheduler.h"
#include "statistics.h"
#include "trigger.h"
#include "util.h"

#include <float.h>
#include <fstream>
#include <iomanip>
#include <iostream>

#define SENT_IDX(n) ((n)*2)
#define RECV_IDX(n) ((n)*2+1)

BucketGVT::BucketGVT() {
  gvt_name = "Bucket GVT";
  active = false;
  continuous = true;

  curr_bucket = 0;
  prev_valid = 0;
  start_reductions = 0;
  count_reductions = 0;
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

void BucketGVT::finalize() {
  if (g_tw_gvt_trace && CkMyPe() == 0) {
    std::ofstream t(std::string(g_output_dir) + "gvt_trace.csv");
    t << "start_s,end_s,asked,passed0,valid,completed,bucket,lead0\n";
    t << std::fixed << std::setprecision(7);
    for (const WaveRecord& w : trace) {
      t << w.start << "," << w.end << "," << w.asked << "," << w.passed0
        << "," << w.valid << "," << w.completed << "," << w.bucket << ","
        << w.lead0 << "\n";
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

void BucketGVT::send_counts(int num_buckets) {
  int num_passed = buckets_passed();
  if (g_tw_gvt_trace && CkMyPe() == 0) {
    wave_start = CmiWallTimer();
    wave_asked = num_buckets;
    wave_passed = num_passed;
  }

  CkReduction::tupleElement tuple[] = {
      CkReduction::tupleElement(sizeof(int)*2*num_buckets,
                                &counts[SENT_IDX(curr_bucket)],
                                CkReduction::sum_int),
      CkReduction::tupleElement(sizeof(int), &num_passed, CkReduction::min_int)
  };
  CkReductionMsg* msg = CkReductionMsg::buildFromTuple(tuple, 2);
  CkCallback cb(CkIndex_BucketGVT::check_counts(0), thisProxy);
  msg->setCallback(cb);
  contribute(msg);
}

void BucketGVT::check_counts(CkReductionMsg* msg) {
  count_reductions++;

  int size;
  CkReduction::tupleElement* result;
  msg->toTuple(&result, &size);

  int num_buckets = (result[0].dataSize / sizeof(int)) / 2;
  int valid_buckets = *((int*)result[1].data);

  int* counts = (int*)result[0].data;

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
    w.asked = wave_asked;
    w.passed0 = wave_passed;
    w.valid = valid_buckets;
    w.completed = completed_buckets;
    w.bucket = curr_bucket;
    w.lead0 = (long long)std::min(scheduler->get_min_time(), max_ts) -
              (long long)curr_gvt;
    trace.push_back(w);
  }

  /** Advance the GVT past the completed buckets */
  if (completed_buckets) advance_gvt(completed_buckets);

  /** If there are still valid buckets then continue to send counts */
  if (valid_buckets - completed_buckets) {
    send_counts(valid_buckets - completed_buckets);
  } else {
    active = false;
    attempt_gvt();
  }

  delete[] result;
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
