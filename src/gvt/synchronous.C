#include "synchronous.h"

#include "globals.h"
#include "scheduler.h"
#include "trigger.h"
#include "util.h"

SyncGVT::SyncGVT() {
  gvt_name = "Synchronous GVT";
  active = false;
  continuous = false;
  waiting_to_contribute = false;
}

void SyncGVT::gvt_begin() {
  active = true;
  waiting_to_contribute = true;
#ifdef CMK_TRACE_ENABLED
    gvt_start = CmiWallTimer();
#endif
  if(CkMyPe() == 0) {
    CkStartQD(CkCallback(CkIndex_SyncGVT::gvt_contribute(), thisProxy));
  }

  lb_trigger->iteration_done();
}

void SyncGVT::gvt_contribute() {
  scheduler->check_next_lps();
  Time min_time = scheduler->get_min_time();
  CkAssert(min_time >= curr_gvt);

  contribute(sizeof(Time), &min_time, CkReduction::min_ulong_long,
      CkCallback(CkReductionTarget(SyncGVT,gvt_end),thisProxy));

  waiting_to_contribute = false;
  if(g_tw_async_reduction && !lb_trigger->ready()) {
    scheduler->gvt_resume();
  }
}

void SyncGVT::gvt_end(Time new_gvt) {
  // With async reductions a PE keeps executing after it contributes, so the
  // next round can begin before this round's result reaches every PE. Two
  // hazards follow, both seen with PEs in separate processes:
  //
  // - Results can arrive out of order. Each is an exact GVT at its quiescence
  //   point, so a smaller value is an older round arriving late; applying it
  //   would move GVT backwards ("GVT Causality Violation").
  // - A result can reach a PE that has already stopped for the next round.
  //   Applying it (fossil collection, end of simulation) is safe, but
  //   resuming is not: whatever the PE sent before contributing would be
  //   missing from that round's minimum. holding_execution() makes gvt_done
  //   leave the PE stopped; gvt_contribute resumes it.
  if (new_gvt < curr_gvt) {
    return;
  }
  active = false;
  prev_gvt = curr_gvt;
  curr_gvt = new_gvt;

  if (lb_trigger->ready()) {
    lb_trigger->reset();
    scheduler->gvt_done(curr_gvt, true);
  } else {
    scheduler->gvt_done(curr_gvt, false);
  }
#ifdef CMK_TRACE_ENABLED
  traceUserBracketEvent(USER_EVENT_GVT, gvt_start, CmiWallTimer());
#endif
}
