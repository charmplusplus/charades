#ifndef _BUCKETED_H_
#define _BUCKETED_H_

#include "gvtmanager.h"

#include "event.h"

#include <atomic>
#include <climits>
#include <list>
#include <map>
#include <utility>
#include <vector>

struct OffsetStats {
  int regular, anti;
  int held, cancelled, released;
  int lag;

  OffsetStats()
      : regular(0), anti(0), held(0), cancelled(0), released(0), lag(0) {}

  double anti_ratio() const {
    return regular ? (double)anti / regular : 0.0;
  }

  double held_ratio() const {
    return regular ? (double)held / regular : 0.0;
  }

  double cancelled_ratio() const {
    return held ? (double)cancelled / held : 0.0;
  }

  // TODO: Can we tell when we send an anti event if the orginal would have
  // been held and then released. Would maybe help determine if we are not
  // holding events long enough.
  double released_ratio() const {
    return held ? (double)released / held : 0.0;
  }

  double average_lag() const {
    return anti ? (double)lag / anti : 0.0;
  }
};

/**
 * --gvt-node-waves: count waves combined per process. Each PE's contribution
 * is one flat array of 64-bit integers:
 *   [0] buckets asked (n)   [1] buckets passed (minimum over PEs)
 *   [2] controller counters (c)   [3] controller histogram bins (h)
 *   [4, 4+2n) sent and received counts   then c counters, then h bins
 * Entries 0, 2 and 3 are the same in every contribution to a wave; 1 is
 * combined by minimum and the rest by sum. A PE writes its array into its
 * process's slot and increments the arrival count; the last PE in combines
 * the slots and its process contributes once, through a custom reducer (no
 * tuple). The result comes back once per process (a nodegroup broadcast),
 * and each PE picks it up in BucketGVT::poll() at the top of execute(),
 * then contributes to the next wave -- so, as with messages, no PE
 * contributes to wave k+1 before it has read wave k's result, which also
 * keeps the slots and the result buffer from being overwritten early.
 *
 * --gvt-wave-allreduce: across processes, an allreduce by recursive doubling
 * replaces the nodegroup reduction and broadcast: in round r a process sends
 * its partial sums to process (me XOR 2^r) and adds in what that process
 * sent; after log2 P rounds every process has the total. Integer sums and
 * one minimum are exact, so every process gets the same result. A partner's
 * message that arrives before this process reached that wave and round is
 * kept until it does. The entry methods are [exclusive], so one PE at a time
 * runs this state machine.
 */
class NodeWaves : public CBase_NodeWaves {
  public:
    NodeWaves();
    /** A PE's contribution (called by the PE itself, not an entry method) */
    void contribute_from(int rank, const std::vector<CmiInt8>& v);
    void contribute_combined(int n, CmiInt8* v);
    void wave_result(CkReductionMsg* msg);
    void exchange(int wave, int round, int n, CmiInt8* v);
    /** --gvt-wave-tree: a child's partial sums, and the result from the parent */
    void tree_up(int wave, int child, double sent_t, int n, CmiInt8* v);
    void tree_down(int wave, double sent_t, int n, CmiInt8* v);
    /** Results published so far; read result() only after this moved */
    uint64_t generation() const { return gen.load(std::memory_order_acquire); }
    /** This process's combined sums are sent and its result is not yet here */
    bool in_flight() const { return flight.load(std::memory_order_relaxed); }
    const std::vector<CmiInt8>& result() const { return res; }
    /** --gvt-trace: when the last PE in arrived, and when the result came */
    double t_combined, t_result;
    /**
     * --gvt-trace=2: one record per wave for this process, all on its own
     * clock -- when its first and last PE contributed, the last PE's rank, and
     * when the result was published here. Written by rank 0 at the end.
     */
    struct ProcWave {
      double first, last, result; int last_rank; double handled;
      /**
       * Linux: its PEs' thread usage since their previous contribution --
       * minor page faults and involuntary context switches summed, user and
       * kernel time summed (µs), and the largest kernel time and its rank
       */
      long minflt = 0, nivcsw = 0;
      double utime_us = 0, stime_us = 0, stime_max_us = 0;
      int stime_max_rank = -1;
    };
    std::vector<ProcWave> proc_waves;
    /** --gvt-trace=3: every rank's contribution, µs after the previous result here */
    std::vector<float> rank_delays;
    void write_proc_waves() const;

  private:
    void publish(const CmiInt8* v, int n);
    void send_round();
    void add_partner(const CmiInt8* v, int n);
    void tree_add(int child, int wave, double sent_t, const CmiInt8* v, int n);
    void tree_send_down(int wave, const CmiInt8* v, int n);
    bool allreduce;     ///< --gvt-wave-allreduce, and a power-of-two process count
    int rounds;         ///< log2 of the process count
    int ar_wave, ar_round;
    bool ar_active;     ///< this process is in wave ar_wave
    std::vector<CmiInt8> ar_buf;
    std::map<std::pair<int, int>, std::vector<CmiInt8>> early;
    int tree_parent;              ///< --gvt-wave-tree: -1 at the root
    std::vector<int> tree_kids;
    int tree_wave, tree_in;       ///< the wave being combined, and inputs so far
    std::vector<CmiInt8> tree_buf;
    CmiNodeLock tree_lock;
    /**
     * --gvt-trace=2 with --gvt-wave-tree: one record per input and per send,
     * on this process's clock except `sent`, which is the sender's clock.
     * kind 0 = a child's partial sums received (peer = the child), 1 = the
     * result received from the parent, 2 = this process's own PEs combined
     * (sent = when the last PE combined), 3 = all inputs in and sent on.
     */
    struct Hop { int wave, kind, peer, rank; double sent, recv; };
    std::vector<Hop> hops;
    std::vector<std::vector<CmiInt8>> slots;
    std::atomic<int> arrived;
    std::vector<double> slot_t;  ///< --gvt-trace=2: when each rank contributed
    /** --gvt-trace=2 (Linux): each rank's thread usage when it contributed, and at its previous contribution */
    struct Usage { long minflt = 0, nivcsw = 0; double utime_us = 0, stime_us = 0; };
    std::vector<Usage> slot_use, prev_use;
    std::vector<CmiInt8> combined;
    std::vector<CmiInt8> res;
    std::atomic<uint64_t> gen;
    std::atomic<bool> flight;
};

/** Combines one contribution into another (layout above) */
void combine_wave(std::vector<CmiInt8>& into, const CmiInt8* from, int n);
CkReductionMsg* gvtWaveReduction(int nMsg, CkReductionMsg** msgs);
void registerGvtWaveReduction();
extern CkReduction::reducerType gvtWaveReductionType;

class BucketGVT : public CBase_BucketGVT {
  public:

    BucketGVT();
    /** --gvt-node-waves: count waves go through this NodeWaves nodegroup */
    BucketGVT(CkGroupID node_waves);

    /** --gvt-node-waves: run a wave's result once the process has it */
    void poll();
    unsigned batch_size() const override;

    void finalize();

    void gvt_begin();

    /** Returns number of buckets the local scheduler instance has passed */
    int buckets_passed() const;

    /**
     * Starts the next GVT computation with a reduction to all_ready if active
     * is false and buckets_passed() is at least 1.
     */
    void attempt_gvt();

    /**
     * Target of reduction signalling all PEs are ready with the minumum number
     * of buckets passed by all schedulers.
     */
    void all_ready(int num_buckets);

    /**
     * Contributes sent and recvd counts for the specified number of buckets, as
     * well as the number of buckets we are still passed, to check_counts().
     */
    void send_counts(int num_buckets);

    /**
     * Target of the tuple reduction from send_counts() which contains the sent
     * and recvd counts for relevant buckets as well as the minimum number of
     * buckets passed by all PEs.
     */
    void check_counts(CkReductionMsg* msg);

    /**
     * What check_counts does with a wave's summed result, whichever way it
     * arrived: sums holds sent and received counts for num_buckets buckets
     */
    void wave_done(const int* sums, int num_buckets, int valid_buckets,
        const uint64_t* ctl, const uint64_t* hist, int nhist);

    /** Advances the GVT by the specified number of buckets */
    void advance_gvt(int num_buckets);

    /** Attempt to cancel adaptively held back events */
    bool attempt_cancel(RemoteEvent* anti);

    void consume(RemoteEvent* e); ///< Increment recvd and attempt GVT
    bool produce(RemoteEvent* e); ///< Increment sent and attempt GVT

    /** --gvt-wave-events: contribute a held wave once enough has run */
    void iteration_end(bool starved);

  private:
    Time bucket_size;   ///< Size of each bucket
    Time max_ts;        ///< Max end ts used when bucket size doesn't divide end
    int total_buckets;  ///< Total number of buckets
    int curr_bucket;    ///< Index of current bucket
    int* counts;        ///< Array of sent and received counts

    /**
     * From the previous count wave, aligned to curr_bucket: the summed
     * received counts, and how many of those buckets every PE had passed.
     * check_counts compares them with the current wave's sent counts.
     */
    std::vector<int> prev_recv;
    int prev_valid;

    int start_reductions;
    int count_reductions;

    /**
     * --gvt-wave-events: a count wave this PE has not contributed to yet
     * (-1: none), the executed-event count at its last contribution, and
     * whether its last execute() batch stopped early
     */
    int pending_wave;
    uint64_t executed_at_wave;
    bool last_starved;
    void contribute_counts(int num_buckets, int reason = 0);

    /** --gvt-node-waves state (see NodeWaves) */
    bool node_waves_on;
    CkGroupID node_waves_gid;
    NodeWaves* node_waves;      ///< resolved at the first wave
    uint64_t node_wave_seen;    ///< results of NodeWaves this PE has run
    bool node_wave_pending;     ///< contributed, result not yet run
    std::vector<CmiInt8> node_wave_buf;
    double wave_combined_t, wave_result_t;  ///< --gvt-trace, PE 0
    void init();

    /**
     * --gvt-trace, PE 0: one record per count wave -- when PE 0 contributed
     * and when the result came back, the buckets asked about, how many PE 0
     * and all PEs had passed, how many completed, the bucket GVT was at, and
     * PE 0's lead over GVT (its earliest event minus GVT)
     */
    struct WaveRecord {
      double start, end;
      double combined, result;  ///< --gvt-node-waves: PE 0's process (0 otherwise)
      int asked, passed0, valid, completed, bucket;
      long long lead0;
      /**
       * Buckets every PE had passed at the previous wave (only those can
       * complete in this one), and the events sent into the ones of them that
       * did not complete but not yet received: the first such bucket's, and
       * all of them together. Nonzero: GVT waits on events in transit
       */
      int prev_valid;
      long long transit_first, transit_total;
    };
    std::vector<WaveRecord> trace;
    /**
     * --gvt-trace=3, ranks 0, 1, the middle one and the last two of each
     * process: every 10th contribution, the time and the cumulative
     * WaveTimers, scheduler time, htram node receives and events executed
     */
    struct PeSnap {
      int wave;
      double t, exec, drain, rollback, poll, node_gvt, recv;
      unsigned long long node_gvt_n, recv_n, executed;
    };
    std::vector<PeSnap> pe_snaps;
    int contributions = 0;
    /**
     * --gvt-trace=4, every PE, every 4th contribution: when this PE picked up
     * the previous wave's result and when it contributed (µs after that result
     * was published in this process, on this process's clock), when its last
     * execute() before the pickup ended, why it contributed, and what it did
     * between pickup and contribution
     */
    struct WaveRec {
      int wave;
      float pick_us, prev_end_us, contrib_us;
      float exec_us, drain_us, recv_us, rollback_us, node_gvt_us;
      unsigned events;
      int passed;  ///< buckets past GVT this PE had passed when it contributed
      int reason;
      /**
       * Events this PE received (counted by consume) since its previous
       * contribution, those within one bucket of GVT when they arrived, and
       * their mean and least distance from GVT in buckets
       */
      unsigned arrivals, near;
      float lag_mean;
      int lag_min;  ///< 0 at pickup, idle; 1 later, idle; 2 later, events; 3 at pickup, events
    };
    std::vector<WaveRec> wave_recs;
    struct PickSnap {
      bool valid = false;
      double result, t, prev_end, exec, drain, recv, rollback, node_gvt;
      unsigned long long executed;
    } pick;
    void take_pick_snapshot(double result_t);
    /** --gvt-trace=4: arrivals since this PE's previous contribution */
    unsigned long long arr_n = 0, arr_near = 0;
    double arr_lag_sum = 0;
    int arr_lag_min = INT_MAX;
    double wave_start;
    int wave_asked, wave_passed;

    OffsetStats* stats;
    int reserve_buckets;
    int clear_buckets;
    double reserve_threshold;
    std::list<RemoteEvent*>* reserves;
};

#endif
