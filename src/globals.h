/** \file globals.h
 *  Declarations for global variables and associated functions.
 *
 *  Most declarations in this file are for "constant" global variables that are
 *  set during startup based on model/simulator configuration and don't ever
 *  change. Variables that are global per PE, but will change at a PE level are
 *  wrapped in a small class which will be instantiated once on each PE.
 */

#ifndef GLOBALS_H_
#define GLOBALS_H_

#include "typedefs.h"

/** \name LP Configuration *////@{
extern unsigned g_total_lps;     ///< total number of LPs
extern unsigned g_num_chares;    ///< total number of chares
extern unsigned g_lps_per_chare; ///< number of LPs per chare (if constant)

extern LPMapper*  g_lp_mapper;  ///< mapper for placing and locating LPs
extern LPFactory* g_lp_factory; ///< factory for creating LPs based on global id
///@}

/** \name Event Configuration *////@{
extern Time g_tw_lookahead;           ///< event lookahead (conservative)
extern uint32_t g_num_msg_types;      ///< number of message types
extern uint32_t g_event_buffer_size;  ///< event buffer size
///@}

/** \name Scheduler Configuration *////@{
extern unsigned g_tw_synchronization_protocol;    ///< scheduler type
extern unsigned g_tw_mblock;                      ///< batch size for event execution
extern Time g_tw_ts_end;                      ///< end time of simulation
///@}

/** \name GVT Configuration *////@{
extern unsigned g_tw_gvt_scheme;      ///< GVT algorithm
extern unsigned g_tw_gvt_interval;    ///< distance between GVT calls
extern unsigned g_tw_gvt_trigger;     ///< unit of the GVT interval (time or events)
extern unsigned g_tw_gvt_phases;      ///< number of phases in a phased gvt
extern unsigned g_tw_gvt_bucket_size; ///< size of each bucket in a bucketed gvt
extern unsigned g_tw_gvt_min_buckets; ///< bucketed gvt: buckets a PE passes before a round
extern unsigned g_tw_gvt_trace;       ///< bucketed gvt: PE 0 logs every count wave; time execute()
extern Time     g_tw_optimism_window; ///< execute no event past GVT + this (0: off)
extern unsigned g_tw_comm_stats;      ///< time remote sends and send->receive latency
extern unsigned g_tw_async_reduction; ///< use asynchronous reductions in GVTs
extern double   g_tw_reserve_threshold;
extern uint32_t g_tw_reserve_buckets;
extern uint32_t g_tw_adaptive_buckets;
extern uint32_t g_tw_clear_lag;
extern uint32_t g_tw_clear_buckets;
///@}

/** \name Event aggregation through htram (aggregation.h) *////@{
extern unsigned g_tw_aggregation;     ///< send remote events through htram
extern unsigned g_tw_agg_mode;        ///< htram mode: WPs=0, WsP=1, PP=2, WW=3
extern unsigned g_tw_agg_buffer;      ///< htram buffer size, in events
extern Time     g_tw_agg_urgent;      ///< events with ts < GVT + this ship at once
extern unsigned g_tw_agg_scope;       ///< 0: all remote chares, 1: other processes only
extern unsigned g_tw_agg_gvt_flush;   ///< on each GVT update: 0 none, 1 stale, 2 all
extern unsigned g_tw_agg_policy;      ///< 0: eager flushes, 1: flush by timestamp deadline
extern Time     g_tw_agg_horizon;     ///< deadline policy: events with ts < GVT + this are due
extern Time     g_tw_agg_horizon_margin; ///< deadline policy, horizon following the window: W + this
///@}

/** \name Optimism-window controller (controller.h) *////@{
extern unsigned g_tw_ctl;             ///< 0: fixed window, 1: delay quantile, 2: hill climb
extern double   g_tw_ctl_epsilon;     ///< quantile rule: target rolled-back share of executed events
extern unsigned g_tw_ctl_calibrate;   ///< quantile rule: scale the bound by the waste seen
extern unsigned g_tw_ctl_interval;    ///< GVT updates per controller round
extern unsigned g_tw_ctl_dry;         ///< run the controller but never change the window
extern unsigned g_tw_ctl_log;         ///< print every controller round on PE 0
///@}

/** \name LB Configuration *////@{
extern uint32_t g_tw_ldb_continuous;
extern uint32_t g_tw_ldb_first;     ///< first interval to call lb
extern unsigned g_tw_ldb_interval;  ///< number of intervals to wait before lb
extern unsigned g_tw_max_ldb;       ///< max number of times to call lb
extern unsigned g_tw_ldb_metric;    ///< metric used to measure LP load
extern unsigned g_tw_metric_ts_abs; ///< use absolute time or not
extern unsigned g_tw_metric_invert; ///< whether or not to invert metric
///@}

/** \name RNG Configuration *////@{
extern unsigned g_tw_rng_default; ///< \todo documentation needed
///@}

/** \name Misc Configuration *////@{
extern char g_output_dir[256];        ///< output directory for extra logging
extern unsigned gvt_print_interval;   ///< frequency of progress print outs
extern unsigned g_tw_stat_interval;   ///< frequency of logging stats (in GVTs)
extern long int g_tw_expected_events; ///< expected number of committed events
///@}

class EventBuffer;

/**
 * PE-level variables which may change over time
 */
class Globals {
  public:
    /**
     * Last computed GVT, used for rollbacks.
     * \todo This should be moved to GVT base class probably
     */
    Time g_last_gvt;
    /**
     * Sentinel event signifying some kind of error.
     * \todo Is this the best place to store this?
     */
    Event* abort_event;
    /**
     * Buffer of pre-allocated events for entire simulation.
     * \todo Can probably be moved to scheduler, which will handle event
     * allocation and management.
     */
    EventBuffer* event_buffer;
    /**
     * Hash table for events received remotely in optimistic execution.
     * \todo Can this go in the LP class for smaller hash tables?
     * \todo Can this be changed to an unordered_map?
     */
    AvlTree avl_list_head;
    /**
     * Optimism window: execute no event past GVT + this (0: unbounded).
     * Starts at --optimism-window; the controller (--ctl) moves it.
     */
    Time window;

    Globals() : g_last_gvt(0),
                abort_event(NULL),
                event_buffer(NULL),
                avl_list_head(NULL),
                window(g_tw_optimism_window) {}
};

void clear_globals();   ///< sets all global variables to default values
Globals* get_globals(); ///< returns a pointer to the local Globals object

/** Macro to simplify global variable access */
#define PE_VALUE(x) get_globals()->x

#endif
