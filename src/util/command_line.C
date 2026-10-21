#include "command_line.h"

#include "globals.h"
#include <fstream>

AggregateParser command_line_parser;

void tw_add_arguments(ArgumentSet* args) {
  command_line_parser.add_parser(args);
}

void parse_command_line(int argc, char** argv) {
  ArgumentSet kernel("Kernel Options");
  kernel.register_argument("sync",                 "Synchronization Protocol - SEQUENTIAL=1, CONSERVATIVE=2, OPTIMISTIC=3", g_tw_synchronization_protocol);
  kernel.register_argument("gvt",                  "GVT Algorithm - SYNCHRONOUS=1, CD=2, PHASED=3, BUCKETED=4", g_tw_gvt_scheme);
  kernel.register_argument("expected-events",      "Number of committed events expected", g_tw_expected_events);
  kernel.register_argument("end-time",             "Virtual end time", g_tw_ts_end);
  kernel.register_argument("lookahead",            "Virtual lookahead", g_tw_lookahead);
  kernel.register_argument("batch",                "Batch size of a scheduler interval", g_tw_mblock);
  kernel.register_argument("sched-park",           "Optimistic, continuous GVT: a PE blocked by the window waits instead of spinning - NO=0, YES=1", g_tw_sched_park);
  kernel.register_argument("use-default-rng",      "Use default RNG setup", g_tw_rng_default);
  kernel.register_argument("gvt-interval",         "Size of each GVT interval (based on gvt trigger)", g_tw_gvt_interval);
  kernel.register_argument("gvt-trigger",          "Type of GVT interval - SCHEDULER INTERVAL=1, VIRTUAL TIME LEASH=2", g_tw_gvt_trigger);
  kernel.register_argument("gvt-phases",           "Number of phases for the phased GVT algorithm", g_tw_gvt_phases);
  kernel.register_argument("gvt-bucket-size",      "Bucket size for bucketed GVT algorithm", g_tw_gvt_bucket_size);
  kernel.register_argument("gvt-min-buckets",      "Bucketed GVT: buckets a PE must pass before it starts a GVT round", g_tw_gvt_min_buckets);
  kernel.register_argument("gvt-wave-events",      "Bucketed GVT: a PE contributes to the next count wave after executing this many events, or when it cannot execute (0 = at once; default 128)", g_tw_gvt_wave_events);
  kernel.register_argument("gvt-trace",            "Bucketed GVT: PE 0 writes every count wave to gvt_trace.csv, and execute() is timed - NO=0, YES=1", g_tw_gvt_trace);
  kernel.register_argument("gvt-adaptive-buckets", "Bucketed GVT: hold remote events far ahead of GVT in the sender - NO=0, YES=1", g_tw_adaptive_buckets);
  kernel.register_argument("gvt-reserve-buckets",  "Bucketed GVT: hold events more than this many buckets ahead of GVT (0 = no offset cutoff)", g_tw_reserve_buckets);
  kernel.register_argument("gvt-reserve-threshold","Bucketed GVT: also hold events at offsets whose anti/regular ratio exceeds this", g_tw_reserve_threshold);
  kernel.register_argument("gvt-clear-lag",        "Bucketed GVT: release a held event once GVT has advanced more than this many buckets since it was held", g_tw_clear_lag);
  kernel.register_argument("gvt-clear-buckets",    "Bucketed GVT: buckets from GVT checked for early release on each advance (0 = all; 1 = release only on reaching its bucket)", g_tw_clear_buckets);
  kernel.register_argument("comm-stats",           "Time remote send calls and send-to-receive latency - NO=0, YES=1", g_tw_comm_stats);
  kernel.register_argument("aggregation",          "Send remote events through htram (needs HTRAM_DIR in config.mk) - NO=0, YES=1", g_tw_aggregation);
  kernel.register_argument("agg-mode",             "htram aggregation mode - WPs=0, WsP=1, PP=2, WW=3", g_tw_agg_mode);
  kernel.register_argument("agg-buffer",           "htram buffer size in events (PP: a multiple of 16)", g_tw_agg_buffer);
  kernel.register_argument("agg-urgent",           "Ship an event at once if its ts < GVT + this (0 = never)", g_tw_agg_urgent);
  kernel.register_argument("agg-scope",            "Aggregate events to - ALL REMOTE CHARES=0, OTHER PROCESSES ONLY=1", g_tw_agg_scope);
  kernel.register_argument("agg-gvt-flush",        "On each GVT update flush - NOTHING=0, DESTINATIONS NOT FILLING=1, EVERYTHING=2", g_tw_agg_gvt_flush);
  kernel.register_argument("agg-policy",           "When htram buffers ship - EAGER (idle PEs and GVT updates flush everything)=0, DEADLINE (only events with ts < GVT + agg-horizon)=1", g_tw_agg_policy);
  kernel.register_argument("agg-horizon",          "Deadline policy: events with ts < GVT + this are due (0 = the optimism window)", g_tw_agg_horizon);
  kernel.register_argument("agg-horizon-margin",   "Deadline policy with agg-horizon 0: the horizon is the window plus this", g_tw_agg_horizon_margin);
  kernel.register_argument("optimism-window",      "Optimistic: execute no event later than GVT + this (0 = unbounded); with --ctl, the starting window", g_tw_optimism_window);
  kernel.register_argument("ctl",                  "Set the optimism window online - NO=0, DELAY QUANTILE=1, HILL CLIMB (Devastator)=2", g_tw_ctl);
  kernel.register_argument("ctl-epsilon",          "Delay quantile rule: target share of executed events rolled back (default 0.003); with --ctl-cost=1 the share of PE time lost to rollbacks (default 0.01); uncalibrated, primary stragglers per executed event", g_tw_ctl_epsilon);
  kernel.register_argument("ctl-cost",             "Delay quantile rule: epsilon is a share of - EVENTS ROLLED BACK=0 (default), PE TIME LOST TO ROLLBACKS=1 (experimental: misses the indirect cost of rollbacks)", g_tw_ctl_cost);
  kernel.register_argument("ctl-calibrate",        "Delay quantile rule: scale the straggler bound by the events seen rolled back - NO=0, YES=1", g_tw_ctl_calibrate);
  kernel.register_argument("ctl-interval",         "Controller round: count waves under the bucketed GVT (shared reduction), else GVT updates; at least 1", g_tw_ctl_interval);
  kernel.register_argument("ctl-dry",              "Run the controller but keep the window fixed (measures its cost) - NO=0, YES=1", g_tw_ctl_dry);
  kernel.register_argument("ctl-log",              "Print every controller round - NO=0, YES=1", g_tw_ctl_log);
  kernel.register_argument("ctl-reduction",        "Controller data - OWN REDUCTION=0, ON THE BUCKETED GVT'S COUNT WAVES=1 (default; other GVTs use their own)", g_tw_ctl_reduction);
  kernel.register_argument("ctl-hist-waves",       "With --ctl-reduction=1: the delay histogram rides on every Nth count wave (at least 1)", g_tw_ctl_hist_waves);
  kernel.register_argument("ctl-hist-coarse",      "With --ctl-reduction=1: one histogram bin per power of two instead of eight - NO=0 (default), YES=1", g_tw_ctl_hist_coarse);
  kernel.register_argument("gvt-async-reduction",  "Use asynchronous reductions in GVT - NO=0, YES=1", g_tw_async_reduction);
  kernel.register_argument("ldb-interval",         "Number of GVT computations between each LB call", g_tw_ldb_interval);
  kernel.register_argument("max-ldb",              "Max number of times to call load balancing", g_tw_max_ldb);
  kernel.register_argument("ldb-metric",           "Metric used for determining LP load during LB", g_tw_ldb_metric);
  kernel.register_argument("ldb-metric-ts-abs",    "Use absolute metric value - NO=0, YES=1", g_tw_metric_ts_abs);
  kernel.register_argument("ldb-metric-invert",    "Invert the LB metrics - NO=0, YES=1", g_tw_metric_invert);
  kernel.register_argument("stat-interval",        "Number of GVT computations between each stat logging", g_tw_stat_interval);
  kernel.register_argument("num-lps",              "Total number of LPs", g_total_lps);
  kernel.register_argument("num-chares",           "Total number of LPChares", g_num_chares);
  kernel.register_argument("lps-per-chare",        "Number of LPs per LPChare", g_lps_per_chare);
  kernel.register_argument("buffer-size",          "Size of pre-allocated event buffer", g_event_buffer_size);
  kernel.register_argument("report-interval",      "Number of GVT computations between each GVT printout", gvt_print_interval);

  tw_add_arguments(&kernel);

  // Search for --help and print arguments if it's there
  for (int i = 1; i < argc; i++) {
    if (std::string(argv[i]) == std::string("--help")) {
      if (CkMyPe() == 0) {
        command_line_parser.print();
      }
      CkExit();
      return;
    }
  }

  for (int i = 1; i < argc; i++) {
    std::string argument(argv[i]);
    if (argument.find("--") == 0) {
      argument.erase(0,2);
      if (!command_line_parser.parse(argument)) {
        // Fatal rather than a warning: a misspelled option (--synch for
        // --sync) otherwise runs the default configuration and passes.
        CkPrintf("Error: --%s is an unrecognized command line option\n",
            argument.c_str());
        CkAbort("Argument parse error\n");
      }
    } else {
      std::ifstream file(argument);
      if (!file.good()) {
        CkPrintf("Error: %s is not a valid configuration file\n",
            argument.c_str());
        CkAbort("Argument parse error\n");
      } else {
        std::string line;
        while(std::getline(file, line)) {
          if (line.find("//") == 0 || line.find("#") == 0) {
            continue;
          } else if (line.find_first_not_of("\t\r\n ") == std::string::npos) {
            continue;
          } else if (!command_line_parser.parse(line)) {
            CkPrintf("Error: %s in file %s is an unrecognized option\n",
                line.c_str(), argument.c_str());
            CkAbort("Argument parse error\n");
          }
        }
      }
    }
  }
}
