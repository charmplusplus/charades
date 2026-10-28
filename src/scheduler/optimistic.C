#include "optimistic.h"

#include "aggregation.h"
#include "avl_tree.h"
#include "fastpath.h"   // Temporary, should be moved to LP
#include "globals.h"
#include "statistics.h"
#include "trigger.h"
#include "util.h"

OptimisticScheduler::OptimisticScheduler() {
  scheduler_name = "Optimisitic Scheduler";

  // Set up the appropriate GVT trigger
  if (g_tw_gvt_trigger == 1) {
    gvt_trigger.reset(new CountTrigger(g_tw_gvt_interval));
  } else if (g_tw_gvt_trigger == 2) {
    gvt_trigger.reset(new LeashTrigger(this, g_tw_gvt_interval));
  } else {
    CkAbort("Bad trigger value\n");
  }

  // Initialize the cancel queue
  min_cancel_time = TIME_MAX;

  // Allocate AVL tree space // TODO: Move this to LPs
  AvlTree avl_list;
  int err = posix_memalign((void **)&avl_list, 64,
      sizeof(struct avlNode) * g_event_buffer_size);
  memset(avl_list, 0, sizeof(struct avlNode) * g_event_buffer_size);
  for (int i = 0; i < g_event_buffer_size - 1; i++) {
    avl_list[i].next = &avl_list[i + 1];
  }
  avl_list[g_event_buffer_size - 1].next = NULL;
  PE_VALUE(avl_list_head) = &avl_list[0];
  DEBUG_PE("Created AVL tree with %d nodes\n", g_event_buffer_size);
}

/** Min time for optimistic schedulers must also take cancel q into account */
Time OptimisticScheduler::get_min_time() const {
  if(next_lps.top() != NULL) {
    return std::min(next_lps.top()->ts, min_cancel_time);
  } else {
    return min_cancel_time;
  }
}

/** Execute events in batches until the trigger dictates it's GVT time */
void OptimisticScheduler::execute() {
  double t0 = g_tw_gvt_trace ? CmiWallTimer() : 0;
  unsigned num_executed = 0;
  bool blocked = false;
  // A count wave's result this PE's process now has (--gvt-node-waves)
  double tp = g_tw_gvt_trace >= 3 ? CmiWallTimer() : 0;
  gvt_manager->poll();
  if (g_tw_gvt_trace >= 3) g_wave_timers.poll += CmiWallTimer() - tp;
  // Events htram's node receives left for this PE (--agg-input-buffer)
  double td = g_tw_gvt_trace >= 3 ? CmiWallTimer() : 0;
  agg_drain();
  // Events chares in this process handed over by pointer (--local-fast-path)
  fp_drain();
  if (g_tw_gvt_trace >= 3) g_wave_timers.drain += CmiWallTimer() - td;
  // Shorter passes while a count wave is in flight (--wave-batch): this PE
  // comes back to the scheduler sooner to run the wave's messages
  const unsigned batch = gvt_manager->batch_size();
  const bool t5 = g_tw_gvt_trace >= 5;
  Globals* g = get_globals();
  if (g->window_gvt != g->g_last_gvt && CmiWallTimer() >= g->window_open_at) {
    g->window_gvt = g->g_last_gvt;
  }
  double tl = t5 ? CmiWallTimer() : 0;
  for (; num_executed < batch; num_executed++) {
    // With an optimism window, events past GVT + window wait for GVT to
    // advance. The iteration still completes, so the GVT trigger keeps
    // firing and stragglers inside the window are still processed.
    // (window_gvt is the GVT, except under --diag-window-lag-ns.)
    Time window = PE_VALUE(window);
    if (window && next_lps.top() != NULL &&
        next_lps.top()->ts > g->window_gvt + window) {
      blocked = true;
      break;
    }
    if (!schedule_next_lp()) {
      break;
    }
  }
  if (t5) {
    g_wave_timers.loop += CmiWallTimer() - tl;
    g_wave_timers.passes++;
  }
  g->last_blocked = blocked;
  if (num_executed == batch) {
    PE_STATS(iter_full)++;
  } else if (blocked) {
    PE_STATS(iter_window)++;
  } else {
    PE_STATS(iter_empty)++;
  }
  // Nothing (more) this PE may execute: whatever it has buffered for other
  // PEs is now only delaying them
  if (num_executed < batch) {
    double tf = t5 ? CmiWallTimer() : 0;
    agg_flush_idle();
    if (t5) {
      g_wave_timers.flush_idle += CmiWallTimer() - tf;
      g_wave_timers.flush_idle_n++;
    }
  }
  double tc = t5 ? CmiWallTimer() : 0;
  process_cancel_q();
  if (t5) g_wave_timers.cancel_q += CmiWallTimer() - tc;
  if (g_tw_gvt_trace) PE_STATS(exec_time) += CmiWallTimer() - t0;
  double ti = t5 ? CmiWallTimer() : 0;
  gvt_manager->iteration_end(num_executed < batch);
  if (t5) g_wave_timers.iter_end += CmiWallTimer() - ti;
  if (g_tw_gvt_trace >= 4) g_wave_timers.exec_end = CmiWallTimer();
  // --sched-park: blocked by the window, stop re-enqueuing execute() until
  // something can unblock this PE: a GVT update (gvt_done), an event or a
  // rollback inside the window (maybe_wake), a cancellation
  // (update_min_cancel), or a wider window (the controller). Spinning instead
  // ran a no-op iteration and an idle flush hundreds of thousands of times
  // per PE per run, ahead of the GVT and event messages that unblock it.
  // Only under a continuous GVT: a blocking one needs every PE to keep
  // iterating until its trigger fires. Joining a round first (gvt_begin)
  // lets the last PE to reach the window still start one.
  // --blocked-pause-ns (diagnostic): how much the pace of blocked passes
  // matters (RESULTS.md, "Why --agg-auto differs")
  if (blocked && g_tw_blocked_pause_ns) {
    double until = CmiWallTimer() + 1e-9 * g_tw_blocked_pause_ns;
    while (CmiWallTimer() < until) {}
  }
  // Not while --diag-window-lag-ns holds the window back: nothing would wake
  // this PE when the lag runs out
  if (blocked && g_tw_sched_park && gvt_manager->is_continuous() &&
      g->window_gvt == g->g_last_gvt) {
    parked = true;
    gvt_manager->gvt_begin();
  }
  iteration_done();
}

void OptimisticScheduler::maybe_wake(Time ts) {
  Time window = PE_VALUE(window);
  if (!window || ts <= PE_VALUE(window_gvt) + window) wake();
}

void OptimisticScheduler::gvt_resume() {
  next_iteration();
}

void OptimisticScheduler::gvt_done(Time gvt, bool lb) {
  // --diag-gvt-spin-ns: a known extra cost in this step, on every PE
  if (g_tw_diag_gvt_spin_ns) {
    const double end = CmiWallTimer() + g_tw_diag_gvt_spin_ns * 1e-9;
    while (CmiWallTimer() < end) {}
  }
  const bool t5 = g_tw_gvt_trace >= 5;
  const double tf = t5 ? CmiWallTimer() : 0;
  collect_fossils(gvt);
  if (t5) {
    g_wave_timers.fossil += CmiWallTimer() - tf;
    g_wave_timers.gvt_done_n++;
  }
  DistributedScheduler::gvt_done(gvt, lb);
}

void OptimisticScheduler::collect_fossils(Time gvt) {
  for (int i = 0; i < next_lps.get_size(); i++) {
    next_lps.as_array()[i]->lp->fossil_me(gvt);
  }
}

void OptimisticScheduler::balancing_complete() {
  process_cancel_q();
  DistributedScheduler::balancing_complete();
}

/**
 * Call process_cancel_q on every LP chare on our PE.
 *
 * Iterate over a snapshot: next_lps is a heap, and cancelling rolls an LP back,
 * which updates its token and reorders the heap's array mid-loop. Walking that
 * array by index then visited some LPs twice and skipped others, and a skipped
 * LP kept its queued cancellations after min_cancel_time had been reset -- so
 * GVT passed them and fossil collection committed events that were cancelled.
 */
void OptimisticScheduler::process_cancel_q() {
  min_cancel_time = TIME_MAX;
  cancel_lps.clear();
  for (int i = 0; i < next_lps.get_size(); i++) {
    cancel_lps.push_back(next_lps.as_array()[i]->lp);
  }
  for (LPChare* lp : cancel_lps) {
    lp->process_cancel_q();
  }
}

/** Check for a new min cancel time */
void OptimisticScheduler::update_min_cancel(Time t) {
  if (t < min_cancel_time) {
    min_cancel_time = t;
  }
  wake();  // the cancellation is processed in execute()
}
