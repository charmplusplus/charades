#ifndef _BUCKETED_H_
#define _BUCKETED_H_

#include "gvtmanager.h"

#include "event.h"

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

class BucketGVT : public CBase_BucketGVT {
  public:

    BucketGVT();

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
