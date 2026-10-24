// redbench: back-to-back group reductions shaped like Charades' bucketed-GVT
// count waves (charades src/gvt/bucketed.C contribute_counts/check_counts):
// every PE contributes a tuple of 2*K ints (sum) and one int (min); the
// result is broadcast to the group, and each PE contributes the next wave as
// soon as it gets the result. PE 0 reports the time per wave and its
// contribute-to-result latency (median, p90, p99) after WARM warm-up waves.
// With -p PEER it instead times round trips of a one-int group message between
// PE 0 and PE PEER (-r round trips after -w warm-up): one hop each way.
// -m selects the reduction: 0 the GVT's tuple (default), 1 a single int
// (sum_int), 2 the 2*K ints as one sum_int array (no tuple).
// Usage: redbench [-k buckets (8)] [-r waves (20000)] [-w warm-up (1000)] [-p peer] [-m mode]
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <vector>
#include "redbench.decl.h"

CProxy_Main mainProxy;
int K, R, WARM, PEER, MODE;

class Main : public CBase_Main {
 public:
  Main(CkArgMsg* m) {
    K = 8; R = 20000; WARM = 1000; PEER = -1; MODE = 0;
    for (int i = 1; i + 1 < m->argc; i++) {
      if (!strcmp(m->argv[i], "-k")) K = atoi(m->argv[++i]);
      else if (!strcmp(m->argv[i], "-r")) R = atoi(m->argv[++i]);
      else if (!strcmp(m->argv[i], "-w")) WARM = atoi(m->argv[++i]);
      else if (!strcmp(m->argv[i], "-p")) PEER = atoi(m->argv[++i]);
      else if (!strcmp(m->argv[i], "-m")) MODE = atoi(m->argv[++i]);
    }
    delete m;
    mainProxy = thisProxy;
    CkPrintf("redbench: %d PEs, %d nodes, %d buckets, %d %s (%d warm-up)\n",
             CkNumPes(), CkNumNodes(), K, R, PEER < 0 ? "waves" : "round trips", WARM);
    CProxy_Bench b = CProxy_Bench::ckNew();
    b.start();
  }
  void done() { CkExit(); }
};

class Bench : public CBase_Bench {
  int wave = 0;
  double t_warm = 0, t_contrib = 0;
  std::vector<int> counts;
  std::vector<double> lat;

  void contribute_wave() {
    for (int i = 0; i < 2 * K; i++) counts[i] = wave + i;
    CkCallback cb(CkIndex_Bench::result(0), thisProxy);
    if (CkMyPe() == 0) t_contrib = CkWallTimer();
    if (MODE == 1) { int one = 1; contribute(sizeof(int), &one, CkReduction::sum_int, cb); return; }
    if (MODE == 2) { contribute(sizeof(int) * 2 * K, counts.data(), CkReduction::sum_int, cb); return; }
    int passed = CkMyPe() + wave;
    CkReduction::tupleElement tuple[2] = {
        CkReduction::tupleElement(sizeof(int) * 2 * K, counts.data(), CkReduction::sum_int),
        CkReduction::tupleElement(sizeof(int), &passed, CkReduction::min_int)};
    CkReductionMsg* msg = CkReductionMsg::buildFromTuple(tuple, 2);
    msg->setCallback(cb);
    contribute(msg);
  }

 public:
  Bench() : counts(2 * K) {}
  void start() {
    if (PEER < 0) contribute_wave();
    else if (CkMyPe() == 0) { t_contrib = CkWallTimer(); thisProxy[PEER].ping(0); }
  }
  void ping(int i) {
    if (CkMyPe() != 0) { thisProxy[0].ping(i); return; }
    double now = CkWallTimer();
    if (i == WARM) t_warm = now;
    if (i >= WARM) lat.push_back(now - t_contrib);
    if (i + 1 < R) { t_contrib = CkWallTimer(); thisProxy[PEER].ping(i + 1); return; }
    std::sort(lat.begin(), lat.end());
    auto q = [&](double f) { return 1e6 * lat[std::min(lat.size() - 1, (size_t)(f * lat.size()))]; };
    CkPrintf("PINGPONG pes=%d nodes=%d peer=%d same_process=%d rtt_mean_us=%.2f rtt_median_us=%.2f rtt_p90_us=%.2f rtt_p99_us=%.2f\n",
             CkNumPes(), CkNumNodes(), PEER, CkNodeOf(PEER) == CkMyNode(), 1e6 * (now - t_warm) / (R - 1 - WARM), q(0.5), q(0.9), q(0.99));
    CkExit();
  }
  void result(CkReductionMsg* m) {
    if (MODE == 0) {
      int size;
      CkReduction::tupleElement* res;
      m->toTuple(&res, &size);
      delete[] res;
    }
    delete m;
    if (CkMyPe() == 0) {
      double now = CkWallTimer();
      if (wave == WARM) t_warm = now;
      if (wave >= WARM) lat.push_back(now - t_contrib);
    }
    if (++wave < R) { contribute_wave(); return; }
    if (CkMyPe() == 0) {
      double per = (CkWallTimer() - t_warm) / (R - WARM);
      std::sort(lat.begin(), lat.end());
      auto q = [&](double f) { return 1e6 * lat[std::min(lat.size() - 1, (size_t)(f * lat.size()))]; };
      CkPrintf("REDBENCH mode=%d pes=%d nodes=%d buckets=%d per_wave_us=%.2f lat_median_us=%.2f lat_p90_us=%.2f lat_p99_us=%.2f\n",
               MODE, CkNumPes(), CkNumNodes(), K, 1e6 * per, q(0.5), q(0.9), q(0.99));
    }
    contribute(CkCallback(CkReductionTarget(Main, done), mainProxy));
  }
};

#include "redbench.def.h"
