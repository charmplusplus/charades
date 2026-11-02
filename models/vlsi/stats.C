#include "vlsi.h"

#include "vlsi_stats.decl.h"

#include <mutex>

/*
 * Model statistics, as in the dragonfly model: LPs add theirs to a
 * per-process total in finalize(); once the simulation has ended,
 * report_stats() creates a group whose members reduce the process totals to
 * PE 0, which prints them. They count committed work only, so they must not
 * depend on the scheduler, the layout or the number of PEs and processes.
 */

static std::mutex stats_lock;
static VlsiStats stats_total = {};

void add_stats(const VlsiStats& s) {
  std::lock_guard<std::mutex> guard(stats_lock);
  stats_total.gate_changes += s.gate_changes;
  stats_total.flop_changes += s.flop_changes;
  stats_total.input_changes += s.input_changes;
  stats_total.pin_events += s.pin_events;
  stats_total.evaluations += s.evaluations;
}

enum { S_GATES, S_FLOPS, S_INPUTS, S_PINS, S_EVALS, NUM_SUMS };

class VlsiStatsGroup : public CBase_VlsiStatsGroup {
  public:
    VlsiStatsGroup() {
      // One PE per process contributes the process total
      VlsiStats mine = {};
      if (CkMyRank() == 0) {
        std::lock_guard<std::mutex> guard(stats_lock);
        mine = stats_total;
      }
      unsigned long long sums[NUM_SUMS];
      sums[S_GATES] = mine.gate_changes;
      sums[S_FLOPS] = mine.flop_changes;
      sums[S_INPUTS] = mine.input_changes;
      sums[S_PINS] = mine.pin_events;
      sums[S_EVALS] = mine.evaluations;
      contribute(sizeof(sums), sums, CkReduction::sum_ulong_long,
          CkCallback(CkIndex_VlsiStatsGroup::sums(NULL), thisProxy[0]));
    }

    void sums(CkReductionMsg* m) {
      const unsigned long long* s = (const unsigned long long*)m->getData();
      const vlsi::Netlist& G = g_netlist;
      double cycles = (double)(g_tw_ts_end / G.period);
      double gates = (double)G.gates * G.copies;
      CkPrintf("========================================\n");
      CkPrintf("VLSI Statistics.........................\n");
      CkPrintf("   Gate output changes....%llu\n", s[S_GATES]);
      CkPrintf("   Flip-flop changes......%llu\n", s[S_FLOPS]);
      CkPrintf("   Input changes..........%llu\n", s[S_INPUTS]);
      CkPrintf("   Pin changes (messages).%llu\n", s[S_PINS]);
      CkPrintf("   Evaluations............%llu\n", s[S_EVALS]);
      if (cycles > 0 && gates > 0) {
        CkPrintf("   Gates changing/cycle...%.3f%%\n", 100.0 * s[S_GATES] / cycles / gates);
        CkPrintf("   Messages per cycle.....%.1f\n", s[S_PINS] / cycles);
      }
      CkPrintf("========================================\n");
      delete m;
      CkExit();
    }
};

void report_stats() {
  if (CkMyPe() == 0) {
    CProxy_VlsiStatsGroup::ckNew();
  }
  StartCharmScheduler();
}

#include "vlsi_stats.def.h"
