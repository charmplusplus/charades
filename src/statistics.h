/** \file statistics.h
 *  Declaration of the Statistics class and associated methods/variables.
 *
 *  Currently, each PE maintains a single instance of a Statistics object, and
 *  at the end of the simulation, a reduction is done to compute total
 *  statistics. Some of the PE level statistics may also be logged for
 *  projections intermittently if tracing is turned on, which requires an
 *  additional instance a Statistics object on each PE.
 *
 *  \todo More modular statistics
 *    - A top level composite statistics class
 *    - Smaller stats modules for things like scheduler, GVT, etc.
 *    - Modules register with the top level class
 *
 *  \todo LP level statistics/tracing
 *    - Related to above, could be a module, however there would be one per LP
 *    - Tracing would require some added functionality to Projections
 *
 *  \todo Better stats tracing
 *    - Probably subclass or composite pattern to make logging self-contained
 *    - Calling log() would dump current stats to file, and accumulate
 *    - Final reduction only needs aggregate stats
 *    - Maybe have a separate type for stats that is a pair when tracing is
 *      enabled, which will make all stats traceable more easily
 *
 *  \todo Model specific stats and logging
 *    - May be entirely taken care of by modular and lp level above
 */

#ifndef STATISTICS_H_
#define STATISTICS_H_

#include "typedefs.h"

#include <charm++.h>
#include <chrono>

/** MACRO to more easily access PE local statistics */
#define PE_STATS(x) get_statistics()->x

/**
 * Class for holding all PE level statistics for a given simulation run.
 *
 * Stats are incremented within the simulation code as needed. If stats tracing
 * is turned on, then one instance of the Statistics class holds data for the
 * most recent interval, and another instance holds accumulated stats for the
 * entire run. Stats need to be aggregatable (for tracing) and reducible (for
 * end of run reduction).
 */
class Statistics {
  public:
    /** \name Timing stats *////@{
    double total_time;  ///< execution time these stats were collected during
    ///@}

    /** \name Event stats *////@{
    uint64_t events_executed;    ///< total number of events executed
    uint64_t events_committed;   ///< number of committed events
    uint64_t events_rolled_back; ///< number of rolled back events
    ///@}

    /** \name Rollback stats *////@{
    uint64_t total_rollback_calls; ///< total number of times a rollback is called
    uint64_t ts_rollback_calls;    ///< number of rollbacks to a certain timestamp
    uint64_t event_rollback_calls; ///< number of rollbacks to a specific event
    ///@}

    /** \name Send stats *////@{
    uint64_t self_sends;   ///< events sent to ourselves
    uint64_t local_sends;  ///< events sent to different LPs in the same chare
    uint64_t remote_sends; ///< events sent to different chares
    uint64_t remote_holds;
    uint64_t remote_cancels;
    uint64_t anti_sends;   ///< anti events sent
    uint64_t anti_cancels;
    ///@}

    /** \name Communication stats (--comm-stats)
     *  Time spent inside the send call for remote events and anti-events,
     *  and send-to-receive latency histograms by where the sender is.
     *////@{
    static const int LAT_CLASSES = 3;  ///< same process, same node, other node
    static const int LAT_BUCKETS = 40; ///< bucket b holds [2^b, 2^(b+1)) ns
    double   send_time;                ///< seconds inside send calls
    uint64_t timed_sends;              ///< number of send calls timed
    uint64_t lat_count[LAT_CLASSES];
    double   lat_sum[LAT_CLASSES];     ///< seconds
    uint64_t lat_hist[LAT_CLASSES][LAT_BUCKETS];
    ///@}

    /** \name Aggregation stats (--aggregation) *////@{
    uint64_t agg_items;        ///< remote events sent through htram
    uint64_t agg_urgent;       ///< of those, shipped at once (--agg-urgent)
    uint64_t agg_direct;       ///< remote events htram could not take
    uint64_t agg_msgs;         ///< messages htram sent
    uint64_t agg_bytes;        ///< bytes in those messages
    uint64_t agg_idle_flushes; ///< htram flushes from idle PEs
    uint64_t agg_pp_bypasses;  ///< PP: local buffers sent alone, node buffer busy
    /// htram messages by what sent them: a buffer filling during an insert,
    /// an urgent event, an idle PE, a GVT update, a blocking GVT round
    uint64_t agg_msgs_full, agg_msgs_urgent, agg_msgs_idle, agg_msgs_gvt,
             agg_msgs_round;
    ///@}

    /** \name Remote event slack (--comm-stats): on arrival, the event's ts
     *  minus its chare's current time. Zero or less is a straggler (rollback).
     *////@{
    static const int SLACK_BUCKETS = 40; ///< bucket b holds [2^b, 2^(b+1))
    uint64_t remote_arrivals;
    uint64_t remote_stragglers;
    uint64_t slack_hist[SLACK_BUCKETS];
    ///@}

    /** \name GVT stats
     *  \todo Move these to the GVT controllers and add more
     *////@{
    uint64_t total_gvts; ///< total number of GVT calculations
    ///@}

    /** \name Memory stats *////@{
    uint64_t max_events_used;	///< max number of events allocated from buffer
    uint64_t new_event_calls;  ///< number of events allocated for an empty buffer
    uint64_t del_event_calls;  ///< number of events deleted for a full buffer
    ///@}

  /** Calls clear() to 0 out stats on creation */
  Statistics();

  /** Sets all stats to their "0" values */
  void clear();
  /** Adds the passed in statistics object to this one */
  void add(const Statistics*);
  /** Reduces the passed in statistics object with this one */
  void reduce(const Statistics*);
  /** Adds the communication and hold stats of another object (add/reduce) */
  void add_comm(const Statistics*);

  /** \name Print Utility functions
   *  Utility functions for nicely printing out stats data
   *////@{
  void print_section(const char*) const;
  void print_int(const char*, uint64_t) const;
  void print_double(const char*, double) const;
  void print() const;
  ///@}

#if CMK_TRACE_ENABLED
  /** \name Tracing Tags
   *  Enums for tracing each associated stat value used by projections
   *////@{
  int EVENTS_EXECUTED;
  int EVENTS_COMMITTED;
  int EVENTS_ROLLED_BACK;

  int EFFICIENCY;

  int SELF_SENDS;
  int LOCAL_SENDS;
  int REMOTE_SENDS;
  int ANTI_SENDS;

  int MAX_EVENTS_USED;
  int NEW_EVENT_CALLS;
  int DEL_EVENT_CALLS;

  void init_tracing();
  void log_tracing(int) const;
  ///@}
#endif
};

/** Helper function for accessing the local Statistics object */
Statistics* get_statistics();
/** Reducer function used by the Charm++ runtime when doing a stats reduction */
CkReductionMsg *statsReduction(int nMsg, CkReductionMsg **msgs);
/** Called during node init to register the stats reduction type */
void registerStatsReduction();
/** The type of the stats reduction used by the Charm++ runtime */
extern CkReduction::reducerType statsReductionType;


class RemoteEvent;

/** \name --comm-stats helpers *////@{
/** Wall-clock time in ns (CLOCK_REALTIME: comparable across PEs of a node) */
inline int64_t comm_now_ns() {
  return std::chrono::duration_cast<std::chrono::nanoseconds>(
      std::chrono::system_clock::now().time_since_epoch()).count();
}
/** Record a remote event's slack: its ts against its chare's current time */
void comm_record_slack(Time ts, Time current);

/** Stamp a message about to be sent; returns the start time for comm_send_end */
int64_t comm_send_begin(RemoteEvent* e);
/** Count the time since start as time spent in a send call */
void comm_send_end(int64_t start_ns);
/** Record the send-to-receive latency of a received message */
void comm_record_latency(const RemoteEvent* e);
///@}

#endif
