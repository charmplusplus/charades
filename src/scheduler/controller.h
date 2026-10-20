/**
 * \file controller.h
 * Online optimism-window control (--ctl).
 *
 * --ctl=1, the quantile rule. A remote event straggles when it arrives
 * behind its receiver (ts < t_r). It was sent at the sender's current time
 * t_s with delay d = ts - t_s, and under a window W both t_s and t_r lie in
 * [GVT, GVT + W], so a straggler needs d < W. Primary stragglers per executed
 * event are therefore at most r * F(W), with r the remote sends per executed
 * event and F the CDF of d over remote sends. The controller keeps that
 * bound at --ctl-epsilon: W = F^-1(min(Q_MAX, epsilon / r)). F is a property
 * of the model rather than of the window, so the rule is feed-forward.
 *
 * --ctl=2, the hill climb of Devastator (Bachan et al., PADS'24), as a
 * baseline in the same loop: from the efficiency (committed / executed)
 * over the last 16 rounds, quarter W below 33%, halve it below 66%, double it
 * above 95%, and otherwise move it 1% in the direction that last raised the
 * committed-event rate.
 *
 * Each PE samples d on its remote sends and counts executed, committed and
 * rolled-back events. After a GVT update it contributes those, once per
 * round, to a sum reduction; the result goes to every PE, and each computes
 * the same window from the same data. The window sets PE_VALUE(window) and,
 * under the deadline flush policy, the aggregation horizon.
 *
 * Under the bucketed GVT the window is at least the bucket size: a PE that
 * cannot execute to the next bucket boundary never lets the bucket complete.
 */

#ifndef CONTROLLER_H_
#define CONTROLLER_H_

#include "controller.decl.h"
#include "typedefs.h"

#include <vector>

/** This PE sent a remote event with this delay (ts - sender's current time) */
void ctl_record_delay(Time delay);
/** This PE applied a GVT update: contribute to the next round if not yet */
void ctl_gvt_done();
/** End of the run: PE 0 prints the controller summary */
void ctl_finalize();

class Controller : public CBase_Controller {
  public:
    /** Log-linear histogram of send delays: 8 bins per power of two */
    static const int SUB_BITS = 3;
    static const int SUB = 1 << SUB_BITS;
    static const int MAX_EXP = 48;
    static const int BINS = 1 + MAX_EXP * SUB;
    /** Reduction layout: the histogram, then these counters */
    enum { EXECUTED = BINS, ROLLED_BACK, COMMITTED, REMOTE, STRAGGLERS,
           ELAPSED_NS, FIELDS };

    Controller();

    void record_delay(Time d) { hist[bin_of(d)]++; }
    void gvt_done();
    /** Broadcast target of each round's reduction */
    void apply(CkReductionMsg* msg);
    void finalize();

    static int bin_of(Time d);
    /** [lo, hi) of a bin */
    static void bin_range(int b, double* lo, double* hi);

  private:
    std::vector<uint64_t> hist;  ///< this PE, since its last contribution
    bool contributed;            ///< in the current round, awaiting apply()
    uint64_t last_executed, last_rolled_back, last_committed, last_remote,
             last_stragglers;
    double last_time;

    /** Identical on every PE: computed only from reduced data */
    std::vector<double> pending; ///< global delays not yet folded into dist
    double pending_total, pending_executed, pending_remote,
           pending_stragglers;
    std::vector<double> dist;    ///< decayed global histogram
    double dist_total, dist_executed, dist_remote, dist_stragglers;
    double alpha;                ///< calibration: seen / bound stragglers
    double q;                    ///< last quantile the rule asked for
    int rounds;
    double run_executed, run_stragglers;  ///< over every round, for the summary
    Time window;
    /** Time-weighted mean W, from the first round on */
    double first_time, window_time_sum, window_time;

    /** Hill climb state */
    std::vector<double> eff_executed, eff_committed;  ///< last 16 rounds
    double last_rate;            ///< committed in the previous round
    double efficiency;

    Time quantile_window(const uint64_t* sum);
    double cdf(Time w) const;
    double inverse_cdf(double q) const;
    Time hill_climb_window(const uint64_t* sum);
    Time clamp_window(Time w) const;
};

#endif
