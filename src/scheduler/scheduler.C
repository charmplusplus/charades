#include "scheduler.h"

#include "aggregation.h"
#include "controller.h"
#include "event_buffer.h"
#include "globals.h"
#include "gvtmanager.h"
#include "lp.h"
#include "random.h"
#include "setup.h"
#include "statistics.h"
#include "trigger.h"
#include "util.h"

CkGroupID scheduler_id;
CpvDeclare(SchedulerPtr, g_scheduler);

/******************************************************************************/
/* Scheduler Base Class                                                       */
/******************************************************************************/
Scheduler::Scheduler() {
  scheduler_id = thisgroup;
  globals = new Globals();
  stats = new Statistics();
  cumulative_stats = stats;

  CpvInitialize(SchedulerPtr, g_scheduler);
  CpvAccess(g_scheduler) = this;

  running = false;
  parked = false;
  ended = false;
  final_printed = pe_stats_written = false;

  // Initialize rng // TODO: Definitely doesn't belong here
  tw_rand_init(31, 41);

  // Initialize event buffer
  PE_VALUE(event_buffer) = new EventBuffer(g_event_buffer_size);
  PE_VALUE(abort_event) = PE_VALUE(event_buffer)->get_abort_event();
  DEBUG_PE("Created event buffer with %d events\n", g_event_buffer_size);

  if (CkMyPe() == 0) {
    CkStartQD(CkCallback(CkIndex_Scheduler::groups_created(), thisProxy));
  }
}

void Scheduler::groups_created() {
  DEBUG_PE("%s created!\n", scheduler_name.c_str());
  // After groups are created, create LP array, and exit upon quiescence
  if (CkMyPe() == 0) {
    CkStartQD(CkCallback(CkCallback::ckExit));
    CProxy_LPChare::ckNew(g_num_chares);
  }
}

void Scheduler::start_simulation() {
  if (CkMyPe() == 0) {
    CkPrintf("Simulation Starting: %.2f MB\n", CmiMemoryUsage()/(1024.0*1024.0));
  }
  start_time = CmiWallTimer();
  running = true;
  thisProxy[CkMyPe()].execute();
}

/**
 * Every PE calls this once it has applied the final GVT (after its last
 * fossil collection), and the LPs finalize only when all have. Before, PE 0
 * broadcast finalize as soon as it reached the end itself: a PE whose own
 * final GVT update was still queued then reported its statistics with its
 * last events executed but not committed. Under the bucketed GVT across
 * processes, runs whose events all drained before the end time committed too
 * few events in 8 of 20 runs (traffic, end time 10,000,000) and 2-7 of 20-40
 * (dragonfly); runs with events left at the end time never showed it.
 */
void Scheduler::end_simulation() {
  if (ended) return;
  ended = true;
  end_time = CmiWallTimer();
  cumulative_stats->total_time = end_time - start_time;
  contribute(CkCallback(CkReductionTarget(Scheduler, all_ended), thisProxy[0]));
}

void Scheduler::all_ended() {
  lps.finalize();
}

void Scheduler::finalize_complete() {
  agg_collect_stats(cumulative_stats);
  if (g_tw_pe_stats) {
    const Statistics* s = cumulative_stats;
    double rec[12] = {(double)CkMyPe(), (double)CkMyNode(), (double)CkMyRank(),
        (double)s->events_executed, (double)s->events_committed,
        (double)s->events_rolled_back, (double)s->remote_sends,
        (double)s->iter_full, (double)s->iter_window, (double)s->iter_empty,
        s->exec_time, s->total_time};
    contribute(sizeof(rec), rec, CkReduction::concat,
        CkCallback(CkIndex_Scheduler::pe_stats(NULL), thisProxy[0]));
  }
  contribute(sizeof(Statistics), cumulative_stats, statsReductionType,
      CkCallback(CkIndex_Scheduler::finalize(NULL), thisProxy[0]));
}

void Scheduler::pe_stats(CkReductionMsg* msg) {
  std::vector<std::vector<double>> recs;
  const double* d = (const double*)msg->getData();
  for (int i = 0; i + 12 <= (int)(msg->getSize() / sizeof(double)); i += 12) {
    recs.emplace_back(d + i, d + i + 12);
  }
  delete msg;
  std::sort(recs.begin(), recs.end());
  FILE* f = fopen("pe_stats.csv", "w");
  fprintf(f, "pe,process,rank,executed,committed,rolled_back,remote_sends,"
             "batches_full,batches_window,batches_empty,exec_s,total_s\n");
  for (const auto& r : recs) {
    fprintf(f, "%.0f,%.0f,%.0f,%.0f,%.0f,%.0f,%.0f,%.0f,%.0f,%.0f,%.6f,%.6f\n",
        r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11]);
  }
  fclose(f);
  pe_stats_written = true;
  exit_when_done();
}

void Scheduler::exit_when_done() {
  if (final_printed && (pe_stats_written || !g_tw_pe_stats)) CkExit();
}

void Scheduler::finalize(CkReductionMsg* msg) {
  Statistics* final_stats = (Statistics*)msg->getData();
  final_stats->print();
  if (g_tw_expected_events >= 0 && g_tw_expected_events != final_stats->events_committed) {
    CkPrintf("Expected %i events to be committed, but instead got %i\n",
        g_tw_expected_events, final_stats->events_committed);
    CkAbort("Failed Simulation Expectations!\n");
  } else {
    // test.py looks for this line. Redirected to a file, stdout is block
    // buffered, and another process flushing its own buffer at exit could
    // land between the two writes of a line that straddled a buffer boundary
    // (dragonfly congested, 2x2: 5 of 40 runs). Flushed on both sides, the
    // line is one write.
    fflush(stdout);
    CkPrintf("Simulation Executed Successfully!\n");
    fflush(stdout);
    final_printed = true;
    exit_when_done();
  }
}

void Scheduler::print_progress(Time ts) {
  if (CkMyPe() != 0) return;
  Time time = std::min(ts, g_tw_ts_end);
  double percent = std::min(100.00 * ((double)ts / g_tw_ts_end), 100.00);
  double mb = CmiMemoryUsage()/(1024.0*1024.0);
  int gvt_num = cumulative_stats->total_gvts;
  if (cumulative_stats != stats) gvt_num += stats->total_gvts;
  CkPrintf("GVT %6i: %10i (%6.2f%%), %.2f MB\n", gvt_num, time, percent, mb);
}

/** Attempt to execute the next LPs next event, returning false if it fails */
bool Scheduler::schedule_next_lp() {
  LPToken *min = next_lps.top();
  if(min == NULL) return false;
  int count = lps(min->lp->thisIndex).execute_me();
  PE_STATS(events_executed) += count;
  if (count) {
    return true;
  } else {
    return false;
  }
}

// TODO: Could this be stored in a member variable and updated consistenly?
/** Return the time of the minimum unexecuted event on this PE */
Time Scheduler::get_min_time() const {
  return next_lps.top() != NULL ? next_lps.top()->ts : TIME_MAX;
}

/**
 * Every LP's token must hold the time of its earliest pending event whenever
 * no LP code is running: get_min_time() reads the tokens, so a token that is
 * too late makes this PE's GVT contribution too late, and fossil collection
 * then commits events that a pending event will still roll back.
 */
void Scheduler::check_next_lps() const {
  for (int i = 0; i < next_lps.get_size(); i++) {
    const LPToken* t = next_lps.as_array()[i];
    TW_ASSERT(t->ts == t->lp->min_pending(),
        "PE %d: LP chare %d token says %llu but its earliest pending event is "
        "at %llu\n", CkMyPe(), t->lp->thisIndex,
        (unsigned long long)t->ts, (unsigned long long)t->lp->min_pending());
  }
}

/** Needs to be overridden by each base class to define a scheduler iteration */
void Scheduler::execute() {
  CkAbort("Must instantiate a particular scheduler type!\n");
}

/******************************************************************************/
/* Sequential Scheduler                                                       */
/******************************************************************************/
SequentialScheduler::SequentialScheduler() {
  scheduler_name = "Sequential Scheduler";
}

void SequentialScheduler::execute() {
  while (schedule_next_lp());
  end_simulation();
}

/******************************************************************************/
/* Distributed Scheduler                                                      */
/******************************************************************************/
DistributedScheduler::DistributedScheduler() {
  // Create the correct GVT Manager, which will be created before QD triggers
  if (CkMyPe() == 0) {
    switch (g_tw_gvt_scheme) {
      case 1:
        CProxy_SyncGVT::ckNew();
        break;
      case 2:
        CProxy_CdGVT::ckNew();
        break;
      case 3:
        CProxy_PhaseGVT::ckNew();
        break;
      case 4:
        // --gvt-node-waves: PEs pick results up in execute(), so only the
        // optimistic scheduler, and not with --sched-park (parked PEs don't run it)
        if (g_tw_gvt_node_waves && g_tw_synchronization_protocol == OPTIMISTIC &&
            !g_tw_sched_park) {
          CkPrintf("Bucketed GVT: count waves combined per process (--gvt-node-waves)\n");
          CProxy_BucketGVT::ckNew(CProxy_NodeWaves::ckNew());
        } else {
          CProxy_BucketGVT::ckNew();
        }
        break;

      default:
        CkAbort("Unknown gvt scheme\n");
    }
    if (g_tw_ctl) {
      if (g_tw_synchronization_protocol != OPTIMISTIC) {
        CkAbort("--ctl sets the optimism window: it needs the optimistic "
                "scheduler\n");
      }
      CProxy_Controller::ckNew();
    }
  }

  // Set up the print trigger
  print_trigger.reset(new CountTrigger(gvt_print_interval));

  // Set up the statistics logging trigger
#if CMK_TRACE_ENABLED
  if (g_tw_stat_interval > 0) {
    cumulative_stats = new Statistics();
    stats->init_tracing();
    stat_trigger.reset(new CountTrigger(g_tw_stat_interval));
  } else {
    stat_trigger.reset(new ConstTrigger(false));
  }
#endif
}

/** Called by QD, which now also includes GVT Manager creation */
void DistributedScheduler::groups_created() {
  gvt_manager = gvt_manager_proxy.ckLocalBranch();
  gvt_manager->groups_created();
  Scheduler::groups_created();
}

/**
 * Helper method that should be called at the end of every scheduler iteration.
 * It checks the GVT trigger to see if we need to compute a GVT, and continues
 * the scheduler otherwise.
 */
void DistributedScheduler::iteration_done() {
  running = false;
  gvt_trigger->iteration_done();
  if (gvt_trigger->ready()) {
    // A blocking GVT waits for quiescence, which cannot see events still in
    // htram's buffers; this PE sends nothing more until the round ends.
    if (!gvt_manager->is_continuous()) agg_flush_all();
    gvt_manager->gvt_begin();
    gvt_trigger->reset();
  } else {
    next_iteration();
  }
}

/**
 * Helper method for starting the next scheduler iteration. It ensures that an
 * iteration will not start if an iteration is already running or if we are
 * going to do load balancing this iteration after the current iteration.
 */
void DistributedScheduler::next_iteration() {
  if (!running && !parked) {
    running = true;
    thisProxy[CkMyPe()].execute();
  }
}

void DistributedScheduler::wake() {
  if (parked) {
    parked = false;
    next_iteration();
  }
}

/** By default, don't allow LP execution to overlap with GVT computation */
void DistributedScheduler::gvt_resume() {}

/**
 * After a GVT completes there are a number of things to check:
 * The stat_trigger determines if we should log stats
 * The lb_trigger determines if we should load balance before the next iteration
 * The computed GVT determines if we are past the end time and the sim is over
 * If none of the above are true, then just start the next iteration
 */
// TODO: Don't have the lb argument. Instead just have the GVT call something
// like Scheduler::start_load_balancing()
void DistributedScheduler::gvt_done(Time gvt, bool lb) {
  TW_ASSERT(gvt >= PE_VALUE(g_last_gvt), "GVT Causality Violation\n");
  PE_STATS(total_gvts)++;
  PE_VALUE(g_last_gvt) = gvt;
  // The window moved with GVT: a parked PE may run again
  parked = false;
  // Buffered events may now be at GVT, holding up the next advance
  agg_flush_gvt();

  // TODO: Make stats trigger work like print trigger does below.
#if CMK_TRACE_ENABLED
  stat_trigger->iteration_done();
  // TODO: Should the gvt >= check be done here? or should we just update cumulative in end_sched
  if (stat_trigger->ready() || (g_tw_stat_interval && gvt >= g_tw_ts_end)) {
    cumulative_stats->add(stats);
    stats->log_tracing(cumulative_stats->total_gvts);
    stats->clear();
    stat_trigger->reset();
  }
#endif

  print_trigger->iteration_done();
  if(gvt >= g_tw_ts_end) {
    print_progress(gvt);
    end_simulation();
    gvt_manager->finalize();
    ctl_finalize();
  } else {
    ctl_gvt_done();
    if (print_trigger->ready()) {
      print_progress(gvt);
    }
    if (lb) {
      start_balancing();
    } else if (!gvt_manager->holding_execution()) {
      next_iteration();
    }
  }

  // If printing is ready, it would have been handled in one of the if branches
  // so just check to reset the trigger. This can't happen in the else branch
  // for cases where lb happens in the same iteration as the trigger is ready.
  if (print_trigger->ready()) {
    print_trigger->reset();
  }
}

/** Tell every local LP to start load balancing */
void DistributedScheduler::start_balancing() {
  TW_ASSERT(!running, "Can't balance while scheduler is running\n");
  DEBUG_PE("Starting to load balancing\n");
  for (int i = 0; i < next_lps.get_size(); i++) {
    next_lps.as_array()[i]->lp->load_balance();
  }
}

/** After load balancing completes we can do the next scheduler iteration */
void DistributedScheduler::balancing_complete() {
  DEBUG_PE("Load balancing complete\n");
  next_iteration();
}

#include "conservative.h"
#include "optimistic.h"
#include "scheduler.def.h"
