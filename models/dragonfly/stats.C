#include "dragonfly.h"

#include "dragonfly_stats.decl.h"

#include <mutex>

/*
 * Model statistics. LPs add theirs to a per-process total in finalize(); once
 * the simulation has ended, report_stats() creates a group whose members
 * reduce the process totals to PE 0, which prints them. The statistics count
 * committed work only, so they must not depend on the scheduler or on the
 * number of PEs and processes.
 */

static std::mutex stats_lock;
static DragonflyStats stats_total = {};

void add_stats(const DragonflyStats& s) {
  std::lock_guard<std::mutex> guard(stats_lock);
  stats_total.messages_sent += s.messages_sent;
  stats_total.packets_injected += s.packets_injected;
  stats_total.packets_finished += s.packets_finished;
  stats_total.total_latency += s.total_latency;
  stats_total.total_hops += s.total_hops;
  stats_total.max_latency = std::max(stats_total.max_latency, s.max_latency);
  stats_total.dropped_packets += s.dropped_packets;
  stats_total.waits += s.waits;
}

static void print_stats(const DragonflyStats& s) {
  double n = s.packets_finished ? (double)s.packets_finished : 1.0;
  CkPrintf("========================================\n");
  CkPrintf("Dragonfly Statistics....................\n");
  CkPrintf("   MPI messages sent......%llu\n", (unsigned long long)s.messages_sent);
  CkPrintf("   Packets injected.......%llu\n", (unsigned long long)s.packets_injected);
  CkPrintf("   Packets finished.......%llu\n", (unsigned long long)s.packets_finished);
  CkPrintf("   Total latency..........%llu ps\n", (unsigned long long)s.total_latency);
  CkPrintf("   Total hops.............%llu\n", (unsigned long long)s.total_hops);
  CkPrintf("   Average latency........%.6f ns\n", s.total_latency / n / TIME_PER_NS);
  CkPrintf("   Maximum latency........%.6f ns\n", s.max_latency / TIME_PER_NS);
  CkPrintf("   Average hops...........%.6f\n", s.total_hops / n);
  CkPrintf("   Chunks dropped.........%llu\n", (unsigned long long)s.dropped_packets);
  CkPrintf("   Chunks that waited.....%llu\n", (unsigned long long)s.waits);
  CkPrintf("========================================\n");
}

enum { S_MESSAGES, S_INJECTED, S_FINISHED, S_LATENCY, S_HOPS, S_DROPPED,
       S_WAITS, NUM_SUMS };

class DragonflyStatsGroup : public CBase_DragonflyStatsGroup {
  private:
    DragonflyStats result;
    int parts;

  public:
    DragonflyStatsGroup() : result(), parts(0) {
      // One PE per process contributes the process total
      DragonflyStats mine = {};
      if (CkMyRank() == 0) {
        std::lock_guard<std::mutex> guard(stats_lock);
        mine = stats_total;
      }
      unsigned long long sums[NUM_SUMS];
      sums[S_MESSAGES] = mine.messages_sent;
      sums[S_INJECTED] = mine.packets_injected;
      sums[S_FINISHED] = mine.packets_finished;
      sums[S_LATENCY] = mine.total_latency;
      sums[S_HOPS] = mine.total_hops;
      sums[S_DROPPED] = mine.dropped_packets;
      sums[S_WAITS] = mine.waits;
      contribute(sizeof(sums), sums, CkReduction::sum_ulong_long,
          CkCallback(CkIndex_DragonflyStatsGroup::sums(NULL), thisProxy[0]));
      unsigned long long max_latency = mine.max_latency;
      contribute(sizeof(max_latency), &max_latency, CkReduction::max_ulong_long,
          CkCallback(CkIndex_DragonflyStatsGroup::maxima(NULL), thisProxy[0]));
    }

    void sums(CkReductionMsg* m) {
      const unsigned long long* s = (const unsigned long long*)m->getData();
      result.messages_sent = s[S_MESSAGES];
      result.packets_injected = s[S_INJECTED];
      result.packets_finished = s[S_FINISHED];
      result.total_latency = s[S_LATENCY];
      result.total_hops = s[S_HOPS];
      result.dropped_packets = s[S_DROPPED];
      result.waits = s[S_WAITS];
      delete m;
      if (++parts == 2) finish();
    }

    void maxima(CkReductionMsg* m) {
      result.max_latency = *(const unsigned long long*)m->getData();
      delete m;
      if (++parts == 2) finish();
    }

    void finish() {
      print_stats(result);
      CkExit();
    }
};

void report_stats() {
  if (CkMyPe() == 0) {
    CProxy_DragonflyStatsGroup::ckNew();
  }
  StartCharmScheduler();
}

#include "dragonfly_stats.def.h"
