/** \file globals.C
 *  Definitions for global variables and associated functions.
 *
 *  \todo Many of these variables really belong to specific modules, and can
 *  also be made non-global.
 */

#include "globals.h"
#include "scheduler.h"

/** \name LP Configuration
 */
///@{
unsigned g_total_lps;
unsigned g_num_chares;
unsigned g_lps_per_chare;

LPMapper*   g_lp_mapper;
LPFactory*  g_lp_factory;
///@}

/** \name Event Configuration */
///@{
Time g_tw_lookahead;
uint32_t g_num_msg_types;
uint32_t g_event_buffer_size;
///@}

/** \name Scheduler Configuration */
///@{
unsigned g_tw_synchronization_protocol;
unsigned g_tw_mblock;
Time g_tw_ts_end;
///@}

/** \name GVT Configuration */
///@{
unsigned g_tw_gvt_scheme;
unsigned g_tw_gvt_interval;
unsigned g_tw_gvt_trigger;
unsigned g_tw_gvt_phases;
unsigned g_tw_gvt_bucket_size;
unsigned g_tw_gvt_min_buckets;
int g_tw_gvt_ask_ahead;
unsigned g_tw_gvt_trace;
unsigned g_tw_pe_stats;
unsigned g_tw_gvt_wave_events;
unsigned g_tw_gvt_node_waves;
unsigned g_tw_gvt_wave_allreduce;
unsigned g_tw_blocked_pause_ns;
unsigned g_tw_sched_park;
Time     g_tw_optimism_window;
unsigned g_tw_comm_stats;
unsigned g_tw_aggregation;
unsigned g_tw_agg_mode;
unsigned g_tw_agg_buffer;
Time     g_tw_agg_urgent;
unsigned g_tw_agg_scope;
unsigned g_tw_agg_inbox;
unsigned g_tw_local_fast_path;
unsigned g_tw_event_index;
unsigned g_tw_msg_pool;
unsigned g_tw_agg_gvt_flush;
unsigned g_tw_agg_policy;
Time     g_tw_agg_horizon;
Time     g_tw_agg_horizon_margin;
unsigned g_tw_agg_auto;
unsigned g_tw_agg_auto_advances;
double   g_tw_agg_auto_share;
double   g_tw_agg_auto_msg;
unsigned g_tw_agg_auto_buffer;
unsigned g_tw_agg_auto_wps;
unsigned g_tw_ctl;
double   g_tw_ctl_epsilon;
unsigned g_tw_ctl_cost;
unsigned g_tw_ctl_calibrate;
unsigned g_tw_ctl_floor;
double   g_tw_ctl_alpha_gain;
double   g_tw_ctl_alpha_init;
double   g_tw_ctl_agg_kappa;
unsigned g_tw_ctl_sparse_waves;
unsigned g_tw_ctl_interval;
unsigned g_tw_ctl_dry;
unsigned g_tw_ctl_log;
unsigned g_tw_ctl_reduction;
unsigned g_tw_ctl_hist_waves;
unsigned g_tw_ctl_hist_coarse;
unsigned g_tw_async_reduction;
double   g_tw_reserve_threshold;
uint32_t g_tw_reserve_buckets;
uint32_t g_tw_adaptive_buckets;
uint32_t g_tw_clear_lag;
uint32_t g_tw_clear_buckets;
///@}

/** \name LB Configuration */
///@{
uint32_t g_tw_ldb_continuous;
uint32_t g_tw_ldb_first;
unsigned g_tw_ldb_interval;
unsigned g_tw_max_ldb;
unsigned g_tw_ldb_metric;
unsigned g_tw_metric_ts_abs;
unsigned g_tw_metric_invert;
///@}

/** \name RNG Configuration */
///@{
unsigned g_tw_rng_default;
///@}

/** \name Misc Configuration */
///@{
char g_output_dir[256];
unsigned gvt_print_interval;
unsigned g_tw_stat_interval;
long int g_tw_expected_events;
///@}

/**
 * \todo Can these just be initialized at declaration? Especially if they are
 * all moved to more appropriate modules.
 */
void clear_globals() {
  g_tw_synchronization_protocol = CONSERVATIVE;
  g_tw_gvt_scheme    = 1;
  g_tw_ts_end        = 1024000;
  g_tw_mblock        = 16;
  g_tw_gvt_interval  = 16;
  g_tw_gvt_trigger   = 1;
  g_tw_gvt_phases    = 2;
  g_tw_gvt_bucket_size    = 8;
  g_tw_gvt_min_buckets    = 1;
  g_tw_gvt_ask_ahead      = 0;
  g_tw_gvt_trace          = 0;
  g_tw_pe_stats           = 0;
  // Paced count waves are 1.0-1.38x faster on 4 nodes and remove the
  // run-to-run flip between two GVT paces (RESULTS.md, "Two speeds")
  g_tw_gvt_wave_events    = 128;
  g_tw_gvt_node_waves     = 1;
  g_tw_gvt_wave_allreduce = 0;
  g_tw_sched_park         = 0;
  g_tw_blocked_pause_ns   = 0;
  g_tw_optimism_window    = 0;
  g_tw_comm_stats         = 0;
  g_tw_aggregation        = 0;
  g_tw_agg_mode           = 0;
  g_tw_agg_buffer         = 64;
  g_tw_agg_urgent         = 0;
  g_tw_agg_scope          = 0;
  g_tw_agg_inbox          = 1;
  g_tw_local_fast_path    = 1;
  g_tw_event_index        = 1;
  g_tw_msg_pool           = 1;
  g_tw_agg_gvt_flush      = 2;
  g_tw_agg_policy         = 0;
  g_tw_agg_horizon        = 0;
  g_tw_agg_horizon_margin = 0;
  g_tw_agg_auto           = 0;
  g_tw_agg_auto_advances  = 128;
  g_tw_agg_auto_share     = 0.3;
  g_tw_agg_auto_msg       = 25;
  g_tw_agg_auto_buffer    = 2048;
  g_tw_agg_auto_wps       = 0;
  g_tw_ctl                = 0;
  g_tw_ctl_epsilon        = -1;   // set in tw_init from --ctl-cost
  g_tw_ctl_cost           = 0;
  g_tw_ctl_calibrate      = 1;
  g_tw_ctl_floor          = 2;
  g_tw_ctl_alpha_gain     = 0.25;
  g_tw_ctl_alpha_init     = 1;
  // With htram's deadline policy, a wider window costs aggregation before it
  // costs rollbacks. kappa 0.20 with sparse waves and the histogram every
  // 32nd wave: 0.94-1.11 of the best fixed window over 10 htram workloads,
  // against 0.84-1.08 for the waste bound alone; unchanged with direct sends
  // (4 nodes, full nodes, job 3633379; RESULTS.md)
  g_tw_ctl_agg_kappa      = 0.20;
  g_tw_ctl_sparse_waves   = 1;
  g_tw_ctl_interval       = 8;
  g_tw_ctl_dry            = 0;
  g_tw_ctl_log            = 0;
  g_tw_ctl_reduction      = 1;
  g_tw_ctl_hist_waves     = 32;
  g_tw_ctl_hist_coarse    = 0;
  g_tw_async_reduction = 0;
  g_tw_reserve_threshold = 1.0;
  g_tw_reserve_buckets = 0;
  g_tw_adaptive_buckets = 0;
  g_tw_clear_lag = 0;
  g_tw_clear_buckets = 1;
  g_tw_ldb_continuous = 0;
  g_tw_ldb_first = 0;
  g_tw_ldb_interval  = 0;
  g_tw_stat_interval = 16;
  g_tw_max_ldb       = 0;
  g_tw_ldb_metric    = 0;
  g_tw_metric_ts_abs = 0;
  g_tw_metric_invert = 0;
  g_tw_lookahead     = 5;
  gvt_print_interval = 64;
  g_tw_expected_events = -1;

  g_tw_rng_default = 1;

  g_lps_per_chare  = 1;
  g_num_chares     = 1;
  g_total_lps      = 1;

  g_num_msg_types     = 0;
  g_event_buffer_size = 8192;

  g_lp_mapper   = NULL;
  g_lp_factory  = NULL;
}

Globals* get_globals() {
  /** Store the pointer in a static variable for faster lookup */
  return CpvAccess(g_scheduler)->globals;
}

#if not USE_CHARMC
// TODO: Maybe these should be moved somewhere else?
void _registerExternalModules(char **argv) {}
void _createTraces(char **argv) {}
#endif
