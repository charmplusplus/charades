#ifndef _BUCKETED_H_
#define _BUCKETED_H_

#include "gvtmanager.h"

#include "event.h"

#include <atomic>
#include <list>
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
 */
class NodeWaves : public CBase_NodeWaves {
  public:
    NodeWaves();
    /** A PE's contribution (called by the PE itself, not an entry method) */
    void contribute_from(int rank, const std::vector<CmiInt8>& v);
    void contribute_combined(int n, CmiInt8* v);
    void wave_result(CkReductionMsg* msg);
    /** Results published so far; read result() only after this moved */
    uint64_t generation() const { return gen.load(std::memory_order_acquire); }
    const std::vector<CmiInt8>& result() const { return res; }

  private:
    std::vector<std::vector<CmiInt8>> slots;
    std::atomic<int> arrived;
    std::vector<CmiInt8> combined;
    std::vector<CmiInt8> res;
    std::atomic<uint64_t> gen;
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
    void contribute_counts(int num_buckets);

    /** --gvt-node-waves state (see NodeWaves) */
    bool node_waves_on;
    CkGroupID node_waves_gid;
    NodeWaves* node_waves;      ///< resolved at the first wave
    uint64_t node_wave_seen;    ///< results of NodeWaves this PE has run
    bool node_wave_pending;     ///< contributed, result not yet run
    std::vector<CmiInt8> node_wave_buf;
    void init();

    /**
     * --gvt-trace, PE 0: one record per count wave -- when PE 0 contributed
     * and when the result came back, the buckets asked about, how many PE 0
     * and all PEs had passed, how many completed, the bucket GVT was at, and
     * PE 0's lead over GVT (its earliest event minus GVT)
     */
    struct WaveRecord {
      double start, end;
      int asked, passed0, valid, completed, bucket;
      long long lead0;
    };
    std::vector<WaveRecord> trace;
    double wave_start;
    int wave_asked, wave_passed;

    OffsetStats* stats;
    int reserve_buckets;
    int clear_buckets;
    double reserve_threshold;
    std::list<RemoteEvent*>* reserves;
};

#endif
