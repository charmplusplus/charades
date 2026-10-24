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
// -m 3 and 4 time the reduction across processes only, one contribution of
// 2*K+4 64-bit ints per process (a nodegroup): 3 Charm++'s nodegroup
// reduction and broadcast, 4 an allreduce by recursive doubling (each round
// every process swaps partial sums with one partner; the process count must
// be a power of two). Time per wave is measured on process 0.
// Usage: redbench [-k buckets (8)] [-r waves (20000)] [-w warm-up (1000)] [-p peer] [-m mode]
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <map>
#include <utility>
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
    if (MODE >= 3) {
      CProxy_NBench nb = CProxy_NBench::ckNew();
      nb.start();
      return;
    }
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


class NBench : public CBase_NBench {
  int wave = 0, round = 0, L = 0;
  bool active = false;  // this process has started wave `wave`
  double t_warm = 0, t_start = 0;
  std::vector<CmiInt8> buf;
  std::vector<double> lat;
  std::map<std::pair<int, int>, std::vector<CmiInt8>> early;

  void begin_wave() {
    buf.assign(2 * K + 4, 0);
    for (int i = 0; i < (int)buf.size(); i++) buf[i] = wave + i + CkMyNode();
    if (CkMyNode() == 0) t_start = CkWallTimer();
    if (MODE == 3) {
      contribute(buf.size() * sizeof(CmiInt8), buf.data(), CkReduction::sum_long_long,
                 CkCallback(CkIndex_NBench::result(0), thisProxy));
      return;
    }
    round = 0;
    active = true;
    if (L == 0) { wave_finished(); return; }
    send_round();
  }
  void send_round() {
    thisProxy[CkMyNode() ^ (1 << round)].rd(wave, round, buf.size(), buf.data());
    auto it = early.find({wave, round});
    if (it != early.end()) {
      std::vector<CmiInt8> v = std::move(it->second);
      early.erase(it);
      take(v.data());
    }
  }
  void take(const CmiInt8* v) {
    for (int i = 0; i < (int)buf.size(); i++) buf[i] += v[i];
    if (++round < L) send_round();
    else wave_finished();
  }
  void wave_finished() {
    active = false;
    if (CkMyNode() == 0) {
      double now = CkWallTimer();
      if (wave == WARM) t_warm = now;
      if (wave >= WARM) lat.push_back(now - t_start);
    }
    if (++wave < R) { begin_wave(); return; }
    if (CkMyNode() == 0) {
      double per = (CkWallTimer() - t_warm) / (R - WARM);
      std::sort(lat.begin(), lat.end());
      auto q = [&](double f) { return 1e6 * lat[std::min(lat.size() - 1, (size_t)(f * lat.size()))]; };
      CkPrintf("REDBENCH mode=%d pes=%d nodes=%d buckets=%d per_wave_us=%.2f lat_median_us=%.2f lat_p90_us=%.2f lat_p99_us=%.2f\n",
               MODE, CkNumPes(), CkNumNodes(), K, 1e6 * per, q(0.5), q(0.9), q(0.99));
      CkExit();
    }
  }

 public:
  NBench() {
    while ((1 << L) < CkNumNodes()) L++;
    if (MODE == 4 && (1 << L) != CkNumNodes()) CkAbort("redbench -m 4 needs a power-of-two process count");
  }
  void start() { begin_wave(); }
  void result(CkReductionMsg* m) { delete m; wave_finished(); }
  void rd(int w, int r, int n, CmiInt8* v) {
    if (active && w == wave && r == round) { take(v); return; }
    early[{w, r}] = std::vector<CmiInt8>(v, v + n);
  }
};

#include "redbench.def.h"
