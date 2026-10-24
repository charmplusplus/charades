#include "bucketed.h"

#include "controller.h"
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

BucketGVT::BucketGVT() { init(); }

BucketGVT::BucketGVT(CkGroupID node_waves) {
  init();
  node_waves_on = true;
  node_waves_gid = node_waves;
}

void BucketGVT::init() {
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

void BucketGVT::finalize() {
  if (g_tw_gvt_trace && CkMyPe() == 0) {
    std::ofstream t(std::string(g_output_dir) + "gvt_trace.csv");
    t << "start_s,end_s,asked,passed0,valid,completed,bucket,lead0,combined_s,result_s\n";
    t << std::fixed << std::setprecision(7);
    for (const WaveRecord& w : trace) {
      t << w.start << "," << w.end << "," << w.asked << "," << w.passed0
        << "," << w.valid << "," << w.completed << "," << w.bucket << ","
        << w.lead0 << "," << w.combined << "," << w.result << "\n";
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
  contribute_counts(num_buckets);
}

void BucketGVT::iteration_end(bool starved) {
  last_starved = starved;
  if (pending_wave >= 0 && (starved ||
      get_statistics()->events_executed - executed_at_wave >=
          g_tw_gvt_wave_events)) {
    int n = pending_wave;
    pending_wave = -1;
    contribute_counts(n);
  }
}

void BucketGVT::contribute_counts(int num_buckets) {
  executed_at_wave = get_statistics()->events_executed;
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

void BucketGVT::poll() {
  if (!node_wave_pending || node_waves->generation() <= node_wave_seen) return;
  node_wave_seen++;
  node_wave_pending = false;
  const std::vector<CmiInt8>& r = node_waves->result();
  wave_combined_t = node_waves->t_combined;
  wave_result_t = node_waves->t_result;
  int n = r[0], nctl = r[2], nhist = r[3];
  std::vector<int> sums(r.begin() + 4, r.begin() + 4 + 2 * n);
  std::vector<uint64_t> ctl(r.begin() + 4 + 2 * n, r.begin() + 4 + 2 * n + nctl);
  std::vector<uint64_t> hist(r.begin() + 4 + 2 * n + nctl, r.end());
  wave_done(sums.data(), n, (int)r[1], nctl ? ctl.data() : nullptr,
      nhist ? hist.data() : nullptr, nhist);
}

NodeWaves::NodeWaves()
    : t_combined(0), t_result(0), slots(CkMyNodeSize()), arrived(0), gen(0),
      rounds(0), ar_wave(0), ar_round(0), ar_active(false) {
  while ((1 << rounds) < CkNumNodes()) rounds++;
  allreduce = g_tw_gvt_wave_allreduce && (1 << rounds) == CkNumNodes();
  if (g_tw_gvt_wave_allreduce && !allreduce && CkMyNode() == 0) {
    CkPrintf("Bucketed GVT: %d processes is not a power of two; count waves "
             "use the nodegroup reduction\n", CkNumNodes());
  }
}

void NodeWaves::contribute_from(int rank, const std::vector<CmiInt8>& v) {
  slots[rank].assign(v.begin(), v.end());
  if (arrived.fetch_add(1, std::memory_order_acq_rel) + 1 < CkMyNodeSize()) {
    return;
  }
  // The last PE in: every slot is written, and none is written again before
  // this wave's result is out
  arrived.store(0, std::memory_order_relaxed);
  if (g_tw_gvt_trace) t_combined = CmiWallTimer();
  combined.assign(slots[0].begin(), slots[0].end());
  for (int r = 1; r < CkMyNodeSize(); r++) {
    combine_wave(combined, slots[r].data(), slots[r].size());
  }
  thisProxy[CkMyNode()].contribute_combined(combined.size(), combined.data());
}

void NodeWaves::contribute_combined(int n, CmiInt8* v) {
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

void NodeWaves::publish(const CmiInt8* v, int n) {
  res.assign(v, v + n);
  if (g_tw_gvt_trace) t_result = CmiWallTimer();
  if (allreduce) {
    ar_active = false;
    ar_wave++;
  }
  gen.fetch_add(1, std::memory_order_release);
}

void NodeWaves::wave_result(CkReductionMsg* msg) {
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
