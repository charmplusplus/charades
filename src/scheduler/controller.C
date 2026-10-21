#include "controller.h"

#include "aggregation.h"
#include "globals.h"
#include "scheduler.h"
#include "statistics.h"
#include "util.h"

#include <algorithm>
#include <cmath>
#include <cstdio>

/** Largest quantile the rule asks for: past it W follows outliers */
static const double Q_MAX = 0.99;
/**
 * New delays fold into the global histogram, which is first halved so that
 * it follows phase changes, once at least BATCH of them have arrived; W is
 * recomputed then. Counting samples rather than rounds keeps the memory the
 * same whether a round sees ten delays (a few PEs, small buckets) or many
 * thousands.
 */
static const double DECAY = 0.5;
static const double BATCH = 256;
/** Calibration moves alpha this share of the way (in log) per fold, ... */
static const double ALPHA_GAIN = 0.25;
/** ... and by at most this factor */
static const double ALPHA_STEP = 1.25;
/** Devastator's moving average: the last 16 rounds */
static const size_t HILL_ROUNDS = 16;

CpvStaticDeclare(Controller*, g_controller);

void ctl_record_delay(Time delay) {
  if (g_tw_ctl) CpvAccess(g_controller)->record_delay(delay);
}

void ctl_gvt_done() {
  if (g_tw_ctl && !ctl_shared()) CpvAccess(g_controller)->gvt_done();
}

bool ctl_shared() {
  return g_tw_ctl && g_tw_ctl_reduction == 1;
}

void ctl_wave_contribute(std::vector<uint64_t>* counters,
                         std::vector<uint64_t>* hist) {
  CpvAccess(g_controller)->wave_contribute(counters, hist);
}

void ctl_wave_result(const uint64_t* counters, const uint64_t* hist,
                     int hist_bins) {
  CpvAccess(g_controller)->wave_result(counters, hist, hist_bins);
}

void ctl_finalize() {
  if (g_tw_ctl) CpvAccess(g_controller)->finalize();
}

Controller::Controller()
    : hist(BINS, 0), waves(0), waves_since(0), wave_sum(FIELDS, 0),
      contributed(false), gvts_since(0), last_executed(0),
      last_rolled_back(0), last_committed(0), last_remote(0),
      last_stragglers(0),
      pending(BINS, 0.0), pending_total(0), pending_executed(0),
      pending_remote(0), pending_stragglers(0), pending_rolled_back(0),
      dist(BINS, 0.0), dist_total(0), dist_executed(0), dist_remote(0),
      dist_stragglers(0), dist_rolled_back(0), alpha(1),
      q(0), rounds(0), run_executed(0), run_stragglers(0),
      window(g_tw_optimism_window), first_time(0),
      window_time_sum(0), window_time(0), last_rate(-1), efficiency(0) {
  CpvInitialize(Controller*, g_controller);
  CpvAccess(g_controller) = this;
  last_time = CmiWallTimer();
  if (g_tw_ctl == 2 && window == 0) {
    CkAbort("--ctl=2 (hill climb) starts from --optimism-window, which must "
            "be > 0\n");
  }
}

int Controller::bin_of(Time d) {
  if (d == 0) return 0;
  int e = 63 - __builtin_clzll(d);
  if (e >= MAX_EXP) return BINS - 1;
  int sub = (int)((((d - (1ull << e)) << SUB_BITS) >> e));
  return 1 + e * SUB + sub;
}

void Controller::bin_range(int b, double* lo, double* hi) {
  if (b == 0) {
    *lo = 0;
    *hi = 1;
    return;
  }
  int e = (b - 1) / SUB, sub = (b - 1) % SUB;
  double width = std::ldexp(1.0, e) / SUB;
  *lo = std::ldexp(1.0, e) + sub * width;
  *hi = *lo + width;
}

/**
 * A counter's run total, and its change since this PE's last contribution.
 * With tracing, the scheduler moves its interval stats into cumulative_stats
 * and clears them every --stat-interval GVTs; without, the two are the same
 * object.
 */
#define RUN_TOTAL(sched, x) ((sched)->cumulative_stats == (sched)->stats \
    ? (sched)->stats->x : (sched)->cumulative_stats->x + (sched)->stats->x)

static uint64_t delta(uint64_t now, uint64_t* last) {
  uint64_t d = now - *last;
  *last = now;
  return d;
}

/**
 * Contribute on every --ctl-interval-th GVT update after the last result.
 * One reduction per GVT update cost 12-20% on 4 nodes (a GVT every 0.65 ms).
 * Every PE contributes once per round, so rounds stay matched even where
 * PEs see different numbers of GVT updates (async blocking GVT drops stale
 * results).
 */
void Controller::gvt_done() {
  if (contributed || ++gvts_since < g_tw_ctl_interval) return;
  contributed = true;
  gvts_since = 0;

  std::vector<uint64_t> v(FIELDS, 0);
  std::copy(hist.begin(), hist.end(), v.begin());
  std::fill(hist.begin(), hist.end(), 0);
  read_counters(&v[EXECUTED]);

  contribute(FIELDS * sizeof(uint64_t), v.data(), CkReduction::sum_ulong_long,
      CkCallback(CkIndex_Controller::apply(NULL), thisProxy));
}

void Controller::read_counters(uint64_t* v) {
  Scheduler* s = CpvAccess(g_scheduler);
  v[EXECUTED - BINS] = delta(RUN_TOTAL(s, events_executed), &last_executed);
  v[ROLLED_BACK - BINS] =
      delta(RUN_TOTAL(s, events_rolled_back), &last_rolled_back);
  v[COMMITTED - BINS] = delta(RUN_TOTAL(s, events_committed), &last_committed);
  v[REMOTE - BINS] = delta(RUN_TOTAL(s, remote_sends), &last_remote);
  // Rollbacks to a timestamp: an event arrived behind its chare
  v[STRAGGLERS - BINS] =
      delta(RUN_TOTAL(s, ts_rollback_calls), &last_stragglers);
  double now = CmiWallTimer();
  v[ELAPSED_NS - BINS] = (uint64_t)((now - last_time) * 1e9);
  last_time = now;
}

/**
 * --ctl-reduction=1. Counters ride on every count wave (48 B); the histogram
 * on every --ctl-hist-waves-th one, whole (385 bins, 3 KB) or, with
 * --ctl-hist-coarse, one bin per power of two (49 bins, 392 B). Between its
 * waves the histogram keeps accumulating here.
 */
void Controller::wave_contribute(std::vector<uint64_t>* counters,
                                 std::vector<uint64_t>* h) {
  counters->assign(COUNTERS, 0);
  read_counters(counters->data());
  bool with_hist = waves++ % g_tw_ctl_hist_waves == 0;
  h->clear();
  if (!with_hist) return;
  if (g_tw_ctl_hist_coarse) {
    h->assign(COARSE_BINS, 0);
    (*h)[0] = hist[0];
    for (int b = 1; b < BINS; b++) (*h)[1 + (b - 1) / SUB] += hist[b];
  } else {
    h->assign(hist.begin(), hist.end());
  }
  std::fill(hist.begin(), hist.end(), 0);
}

/**
 * Every PE gets the same sums, wave by wave, and decides once per
 * --ctl-interval waves. A coarse bin is spread evenly over its sub-bins, which
 * is what linear interpolation within the power of two would give.
 */
void Controller::wave_result(const uint64_t* counters, const uint64_t* h,
                             int hist_bins) {
  if (h && hist_bins == COARSE_BINS) {
    wave_sum[0] += h[0];
    for (int c = 1; c < COARSE_BINS; c++) {
      // Exact for whole multiples of SUB; the remainder goes to the low bins
      for (int k = 0; k < SUB; k++) {
        wave_sum[1 + (c - 1) * SUB + k] += h[c] / SUB + (k < (int)(h[c] % SUB));
      }
    }
  } else if (h) {
    for (int b = 0; b < BINS; b++) wave_sum[b] += h[b];
  }
  for (int i = 0; i < COUNTERS; i++) wave_sum[BINS + i] += counters[i];
  if (++waves_since < g_tw_ctl_interval) return;
  waves_since = 0;
  decide(wave_sum.data());
  std::fill(wave_sum.begin(), wave_sum.end(), 0);
}

/**
 * At least 1 (0 would turn the window off) and, under the bucketed GVT, the
 * bucket size; at most the end time, past which a window changes nothing
 * (and the hill climb, which doubles W while efficiency stays above 95%,
 * would otherwise overflow).
 */
Time Controller::clamp_window(Time w) const {
  w = std::max<Time>(w, 1);
  if (g_tw_gvt_scheme == 4) w = std::max<Time>(w, g_tw_gvt_bucket_size);
  return std::min<Time>(w, g_tw_ts_end);
}

/** F(w): the share of the decayed histogram with delay below w */
double Controller::cdf(Time w) const {
  double seen = 0;
  for (int b = 0; b < BINS; b++) {
    double lo, hi;
    bin_range(b, &lo, &hi);
    if (hi <= w) {
      seen += dist[b];
    } else {
      if (lo < w) seen += dist[b] * (w - lo) / (hi - lo);
      break;
    }
  }
  return dist_total > 0 ? seen / dist_total : 0;
}

/** F^-1(q), interpolating within a bin */
double Controller::inverse_cdf(double q) const {
  double target = q * dist_total, seen = 0;
  for (int b = 0; b < BINS; b++) {
    if (seen + dist[b] >= target && dist[b] > 0) {
      double lo, hi;
      bin_range(b, &lo, &hi);
      return lo + (target - seen) / dist[b] * (hi - lo);
    }
    seen += dist[b];
  }
  return 0;
}

/**
 * W = F^-1(min(Q_MAX, epsilon / (r * alpha))) over the decayed histogram.
 *
 * Uncalibrated (--ctl-calibrate=0, alpha = 1) this is the bound itself:
 * primary stragglers per executed event at most epsilon. The bound is loose
 * both ways. Receivers rarely lead senders by the whole window, so it
 * throttles far more than needed (4 PEs, lookahead 10 / mean 200: 0.0001
 * stragglers per event against epsilon 0.05); and a straggler can roll back
 * many events and send anti-messages that roll back more (4 nodes: 0.017
 * stragglers per event, 94% of events rolled back).
 *
 * Calibrated (the default), epsilon is the share of executed events that
 * may be rolled back, and alpha is that share as seen at the current W over
 * r * F(W): the delay distribution gives how waste grows with W, and the
 * waste seen gives the scale, cascades included. alpha moves slowly (see
 * ALPHA_GAIN): the histogram follows phase changes, alpha only the scale.
 */
Time Controller::quantile_window(const uint64_t* sum) {
  for (int b = 0; b < BINS; b++) {
    pending[b] += sum[b];
    pending_total += sum[b];
  }
  pending_executed += sum[EXECUTED];
  pending_remote += sum[REMOTE];
  pending_stragglers += sum[STRAGGLERS];
  pending_rolled_back += sum[ROLLED_BACK];
  if (pending_total < BATCH || pending_executed == 0) return window;

  dist_total = 0;
  for (int b = 0; b < BINS; b++) {
    dist[b] = dist[b] * DECAY + pending[b];
    dist_total += dist[b];
    pending[b] = 0;
  }
  dist_executed = dist_executed * DECAY + pending_executed;
  dist_remote = dist_remote * DECAY + pending_remote;
  dist_stragglers = dist_stragglers * DECAY + pending_stragglers;
  dist_rolled_back = dist_rolled_back * DECAY + pending_rolled_back;
  pending_total = pending_executed = pending_remote = pending_stragglers =
      pending_rolled_back = 0;

  double r = dist_remote / dist_executed;
  if (g_tw_ctl_calibrate) {
    // What the bound allows at the window in force (0: unbounded)
    double bound = r * cdf(window ? window : g_tw_ts_end);
    if (bound > 0) {
      // Geometric smoothing: a quarter of the way per fold, at most 1.25x.
      // Rollbacks come in bursts; moving alpha 2x per fold made W swing
      // 12-60 around a best fixed W of 25 (4 nodes, lookahead 10 / mean 200).
      double seen = std::min(1e4, std::max(dist_rolled_back / dist_executed /
          bound, 1e-4));
      double step = std::pow(seen / alpha, ALPHA_GAIN);
      alpha *= std::min(ALPHA_STEP, std::max(1 / ALPHA_STEP, step));
    }
  }
  q = std::min(Q_MAX, g_tw_ctl_epsilon / (r * alpha));
  return clamp_window((Time)std::ceil(inverse_cdf(q)));
}

/**
 * Devastator's rule (Bachan et al., PADS'24, Sec. 2.1), after every round,
 * on the moving average of committed / executed over the last 16 rounds.
 */
Time Controller::hill_climb_window(const uint64_t* sum) {
  eff_executed.push_back(sum[EXECUTED]);
  eff_committed.push_back(sum[COMMITTED]);
  if (eff_executed.size() > HILL_ROUNDS) {
    eff_executed.erase(eff_executed.begin());
    eff_committed.erase(eff_committed.begin());
  }
  double executed = 0, committed = 0;
  for (size_t i = 0; i < eff_executed.size(); i++) {
    executed += eff_executed[i];
    committed += eff_committed[i];
  }
  double prev_committed = last_rate;
  last_rate = sum[COMMITTED];
  if (executed == 0) return window;
  efficiency = committed / executed;

  Time w = window;
  if (efficiency < 0.33) {
    w = w / 4;
  } else if (efficiency < 0.66) {
    w = w / 2;
  } else if (efficiency > 0.95) {
    w = w > g_tw_ts_end / 2 ? g_tw_ts_end : w * 2;
  } else if (prev_committed >= 0) {
    // 1%, but at least 1 so a small window can still move
    Time step = std::max<Time>(1, w / 100);
    if (sum[COMMITTED] > prev_committed) {
      w += step;
    } else if (sum[COMMITTED] < prev_committed && w > step) {
      w -= step;
    }
  }
  return clamp_window(w);
}

void Controller::apply(CkReductionMsg* msg) {
  decide((const uint64_t*)msg->getData());
  delete msg;
  contributed = false;
}

void Controller::decide(const uint64_t* sum) {
  double now = CmiWallTimer();
  if (rounds > 0) {
    window_time_sum += (double)window * (now - window_time);
  } else {
    first_time = now;
  }
  window_time = now;
  rounds++;
  run_executed += sum[EXECUTED];
  run_stragglers += sum[STRAGGLERS];

  Time w = g_tw_ctl == 2 ? hill_climb_window(sum) : quantile_window(sum);
  // The log shows this round's efficiency; the hill climb uses its average
  double round_eff = sum[EXECUTED] ? (double)sum[COMMITTED] / sum[EXECUTED] : 0;
  // --ctl-dry: every round runs and the log shows the window the policy
  // chose, but the window in force stays put, so a run measures what the
  // controller's machinery costs apart from what moving the window does
  if (!g_tw_ctl_dry) {
    window = w;
    PE_VALUE(window) = w;
    agg_set_window(w);
    // A wider window may unblock a parked PE (--sched-park)
    ((DistributedScheduler*)CpvAccess(g_scheduler))->wake();
  }

  if (g_tw_ctl_log && CkMyPe() == 0) {
    uint64_t samples = 0;
    for (int b = 0; b < BINS; b++) samples += sum[b];
    CkPrintf("CTL round %d gvt %llu window %llu delays %llu executed %llu "
        "rolled_back %llu committed %llu remote %llu stragglers %llu "
        "round_ms %.3f q %.4f alpha %.4f eff %.3f\n", rounds, (unsigned long long)PE_VALUE(g_last_gvt),
        (unsigned long long)w, (unsigned long long)samples,
        (unsigned long long)sum[EXECUTED],
        (unsigned long long)sum[ROLLED_BACK],
        (unsigned long long)sum[COMMITTED], (unsigned long long)sum[REMOTE],
        (unsigned long long)sum[STRAGGLERS],
        sum[ELAPSED_NS] / 1e6 / CkNumPes(), q, alpha,
        g_tw_ctl == 2 ? efficiency : round_eff);
  }
}

void Controller::finalize() {
  if (CkMyPe() != 0) return;
  double now = CmiWallTimer();
  double total = window_time_sum + (double)window * (now - window_time);
  double span = now - first_time;
  CkPrintf("\n==== WINDOW CONTROLLER ==============\n");
  if (g_tw_ctl == 2) {
    CkPrintf("Policy                         hill climb (Devastator)\n");
  } else {
    CkPrintf("Policy                         delay quantile, epsilon %g, %s\n",
        g_tw_ctl_epsilon, g_tw_ctl_calibrate ? "calibrated" : "bound only");
    CkPrintf("Final alpha (calibration)      %.4f\n", alpha);
  }
  CkPrintf("Reduction                      %s\n", ctl_shared()
      ? (g_tw_ctl_hist_coarse ? "shared with GVT waves, coarse histogram"
                              : "shared with GVT waves")
      : "separate");
  CkPrintf("Rounds                         %d\n", rounds);
  CkPrintf("Final window                   %llu\n",
      (unsigned long long)window);
  if (rounds > 0 && span > 0) {
    CkPrintf("Time-weighted mean window      %.1f\n", total / span);
  }
  if (run_executed > 0) {
    CkPrintf("Stragglers per executed event  %.4f\n",
        run_stragglers / run_executed);
  }
}

#include "controller.def.h"
