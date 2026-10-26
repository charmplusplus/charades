#include "setup.h"

#include "aggregation.h"
#include "fastpath.h"
#include "command_line.h"
#include "factory.h"
#include "mapper.h"
#include "scheduler.h"
#include "statistics.h"
#include "bucketed.h"

/**
 * Diagnostic (RESULTS.md, "Memory layout"): CHARADES_PAD_KB=N allocates and
 * touches N KB on every PE at startup, before any group is created, so every
 * later allocation lands elsewhere while nothing else changes.
 */
void layoutPad() {
  const char* kb = getenv("CHARADES_PAD_KB");
  if (kb == NULL) return;
  size_t n = strtoul(kb, NULL, 10) * 1024;
  if (n == 0) return;
  char* p = (char*)malloc(n);
  memset(p, 1, n);
  if (CkMyPe() == 0) CkPrintf("Layout pad: %zu KB per PE\n", n / 1024);
}

void tw_init(int argc, char** argv) {
  clear_globals();
  charm_init(argc, argv);
  // Parse Charm's copy of the arguments, not main's: under Reconverse, Charm
  // consumes its own flags (+setcpuaffinity, +pemap, +showcpuaffinity, ...)
  // from a per-PE copy, so they survive in main's argv and would be read as
  // configuration files.
  char** ck_argv = CkGetArgv();
  parse_command_line(CmiGetArgc(ck_argv), ck_argv);
  get_msg_id<void *>();

  // Derive the load balancing schedule here, once per process, rather than in
  // each PE's GVTManager constructor, where every PE thread wrote it.
  if (g_tw_ldb_interval > 0 || g_tw_ldb_first > 0) {
    if (g_tw_ldb_interval == 0) {
      g_tw_max_ldb = 1;
    } else if (g_tw_ldb_first == 0) {
      g_tw_ldb_first = g_tw_ldb_interval;
    }
  }

  // The delay-quantile controller with no starting window starts from the
  // smallest one and opens it as delays arrive: starting wide can set off a
  // rollback storm that slows GVT, and with it the controller, for most of a
  // run (4 nodes, lookahead 10 / mean 200, from W 2000: 6% efficiency).
  if (g_tw_ctl_interval == 0) g_tw_ctl_interval = 1;
  // Defaults from the 4-node Gaussian sweeps on psm2 (2026-10-22, RESULTS.md
  // "Floor-aware controller"): 0.001 as a share of events, with
  // --ctl-floor=2, was 0.87-0.96 of the best fixed window through htram and
  // 0.97-1.03 sent directly. 0.003 without the floor fix fell to 0.68
  // through htram. The time share (--ctl-cost=1) is experimental.
  if (g_tw_ctl_epsilon < 0) g_tw_ctl_epsilon = g_tw_ctl_cost ? 0.01 : 0.001;
  if (g_tw_ctl_hist_waves == 0) g_tw_ctl_hist_waves = 1;
  if (g_tw_ctl == 1 && g_tw_optimism_window == 0) {
    g_tw_optimism_window = g_tw_gvt_scheme == 4 ? g_tw_gvt_bucket_size : 1;
  }
  // Same-process events by pointer: on by default, off where it cannot work
  // (jobs 3636369, 3636435: 1.29x at 16 nodes sigma 100, 0.97-1.04 elsewhere)
  fp_resolve();
}

/**
 * Check that the mapper places exactly g_total_lps LPs on g_num_chares chares
 * and that its maps invert (issue #9). A bad mapping otherwise surfaces only
 * as a Charm++ array-index assertion, or as events sent to the wrong LP.
 */
static void validate_mapping() {
  uint64_t placed = 0;
  for (uint64_t c = 0; c < g_num_chares; c++) {
    uint64_t n = g_lp_mapper->get_num_lps(c);
    for (uint64_t l = 0; l < n; l++) {
      uint64_t gid = g_lp_mapper->get_global_id(c, l);
      if (gid >= g_total_lps || g_lp_mapper->get_chare_id(gid) != c ||
          g_lp_mapper->get_local_id(gid) != l) {
        CkPrintf("Error: chare %llu slot %llu maps to LP %llu, which does not "
            "map back (chare %llu, slot %llu) or is past %u LPs\n",
            (unsigned long long)c, (unsigned long long)l,
            (unsigned long long)gid,
            (unsigned long long)g_lp_mapper->get_chare_id(gid),
            (unsigned long long)g_lp_mapper->get_local_id(gid), g_total_lps);
        CkAbort("Invalid LP mapping\n");
      }
    }
    placed += n;
  }
  if (placed != g_total_lps) {
    CkPrintf("Error: %u chares hold %llu LPs, but num-lps is %u\n",
        g_num_chares, (unsigned long long)placed, g_total_lps);
    CkAbort("Invalid LP mapping\n");
  }
}

/** QD callback on PE 0: create the scheduler group (see tw_create_simulation) */
static void create_scheduler_group(void*, void* msg) {
  if (msg) CkFreeMsg(msg);
  switch(g_tw_synchronization_protocol) {
    case 1:
      CProxy_SequentialScheduler::ckNew();
      break;
    case 2:
      CProxy_ConservativeScheduler::ckNew();
      break;
    case 3:
      CProxy_OptimisticScheduler::ckNew();
      break;
    default:
      CkAbort("Unknown synchronization protocol\n");
  }
}

/** QD callback on PE 0: create htram, then the scheduler group */
static void create_aggregation(void*, void* msg) {
  if (msg) CkFreeMsg(msg);
  agg_create(CkCallback(create_scheduler_group, NULL));
}

void tw_create_simulation(LPFactory* factory) {
  tw_create_simulation(factory, new BlockMapper());
}

void tw_create_simulation(LPFactory* factory, LPMapper* mapper) {
  g_lp_factory = factory;
  g_lp_mapper = mapper;
  // In sequential mode there can only be one chare. Enforce that here.
  if (g_tw_synchronization_protocol == SEQUENTIAL) {
    if (g_num_chares > 1) {
      CkPrintf("WARNING: In sequential mode there can only be one chare!\n");
      CkPrintf("Overriding number of chares to be 1.\n");
    }
    if (g_lps_per_chare != g_total_lps) {
      CkPrintf("WARNING: In sequential mode all lps must be on one chare!\n");
      CkPrintf("Overriding lps per chare to be %d.\n", g_total_lps);
    }
    g_num_chares = 1;
    g_lps_per_chare = g_total_lps;
    CkPrintf("WARNING: In sequential mode all LPs must map to chare 0\n");
    CkPrintf("Overriding LP placement maps.\n");
    g_lp_mapper = new BlockMapper();
  } else {
    // num-lps and num-chares without lps-per-chare: the block mapper reads
    // only lps-per-chare, so derive it (it used to stay 1 and send LPs to
    // chare indices past the end of the array).
    if (g_total_lps != 1 && g_num_chares != 1 && g_lps_per_chare == 1 &&
        dynamic_cast<BlockMapper*>(g_lp_mapper) != NULL) {
      if (g_total_lps % g_num_chares != 0) {
        CkPrintf("Error: %u LPs do not divide evenly over %u chares\n",
            g_total_lps, g_num_chares);
        CkAbort("Invalid LP configuration\n");
      }
      g_lps_per_chare = g_total_lps / g_num_chares;
    }
    if (g_total_lps == 1) {
      g_total_lps = 0;
      for (int i = 0; i < g_num_chares; i++) {
        g_total_lps += g_lp_mapper->get_num_lps(i);
      }
    } else if (g_num_chares == 1) {
      g_num_chares = 0;
      uint64_t sum = 0;
      while (sum < g_total_lps) {
        sum += g_lp_mapper->get_num_lps(g_num_chares++);
      }
    }
  }

  if (g_tw_map_rotate && dynamic_cast<BlockMapper*>(g_lp_mapper) != NULL) {
    if (g_num_chares % CkNumPes() || CkNumPes() % CkNumNodes())
      CkAbort("--map-rotate needs the same number of chares on every PE and of PEs in every process\n");
    uint64_t per_pe = g_num_chares / CkNumPes();
    uint64_t per_proc = per_pe * (CkNumPes() / CkNumNodes());
    g_lp_mapper = new RotatedBlockMapper(per_proc, (uint64_t)g_tw_map_rotate * per_pe);
    if (tw_ismaster())
      CkPrintf("Mapping: each process's LP blocks rotated by %u PEs (diagnostic)\n", g_tw_map_rotate);
  }

  if (tw_ismaster()) {
    validate_mapping();
  }

  // TODO Update this
  // Print out configuration info and create the chares
  if (tw_ismaster()) {
    printf("========================================\n");
    printf("Charades Configuration..................\n");
    printf("   Synch Protocol.........%u\n", g_tw_synchronization_protocol);
    printf("   End time...............%llu\n", g_tw_ts_end);
    printf("   Lookahead..............%llu\n", g_tw_lookahead);
    printf("   Batch Size.............%u\n", g_tw_mblock);
    printf("   GVT Interval...........%u\n", g_tw_gvt_interval);
    printf("   Total LPs..............%u\n", g_total_lps);
    printf("   Chares.................%u\n", g_num_chares);
    printf("   Buffer size............%u\n", g_event_buffer_size);
    printf("========================================\n\n");
    // Create the scheduler group only once every PE is in its scheduler. In
    // SMP interop main runs only on rank 0 of each process, while the other
    // ranks are already scheduling: created at once, the group's constructors
    // ran on those ranks while their process's rank 0 could still be parsing
    // the configuration, and read defaults (e.g. an 8192-event buffer, the
    // default GVT settings). Quiescence cannot be reached until every rank 0
    // has entered the scheduler below, i.e. finished parsing and model setup.
    // With aggregation, htram and the aggregators come first: the scheduler
    // group's creation is their completion callback.
    fp_check();
    if (g_tw_aggregation) {
      CkStartQD(CkCallback(create_aggregation, NULL));
    } else {
      CkStartQD(CkCallback(create_scheduler_group, NULL));
    }
  }
  StartCharmScheduler();
}

void tw_run() {
  init_lps();
  charm_run();
}

/* TODO: Check what this is meant to do and implement */
void tw_end() {
 charm_exit();
}

void charm_init(int argc, char** argv) {
  CharmInit(argc, argv);
  traceRegisterUserEvent("Forward Execution", USER_EVENT_FWD);
  traceRegisterUserEvent("Rollback", USER_EVENT_RB);
  traceRegisterUserEvent("Cancellation", USER_EVENT_CANCEL);
  traceRegisterUserEvent("GVT", USER_EVENT_GVT);
  traceRegisterUserEvent("LB", USER_EVENT_LDB);
  traceRegisterUserEvent("Fossil Collection", USER_EVENT_FC);
}
void charm_exit() {
  CharmLibExit();
}
void charm_run() {
  // Broadcast from PE 0 rather than calling the local branch: in SMP interop
  // main runs only on rank 0 of each process, so a local call left the other
  // ranks' schedulers unstarted until a remote event happened to wake them
  // (a deterministic hang with one LP chare per PE).
  if (CkMyPe() == 0) {
    CProxy_Scheduler(scheduler_id).start_simulation();
  }
  StartCharmScheduler();
}

int tw_ismaster() {
  return (CkMyPe() == 0);
}
int tw_nnodes() {
  return CkNumPes();
}
int tw_mype() {
  return CkMyPe();
}

#include "setup.def.h"
