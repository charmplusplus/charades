#include "dragonfly.h"

// Topology: routers per group (a), global channels per router (h), terminals
// per router (p). The defaults are the original model's #defines.
uint32_t g_routers_per_group = 24;
uint32_t g_global_channels = 12;
uint32_t g_terminals_per_router = 12;

uint32_t g_routing = MINIMAL;
uint32_t g_traffic = NEAREST_NEIGHBOR;
// arrival rate (ns)
double   g_mean_interval = 200.0;

// virtual channel sizes (chunks)
uint32_t g_local_vc_size = 32768;
uint32_t g_global_vc_size = 65536;
uint32_t g_terminal_vc_size = 16384;

uint32_t g_routers_per_chare = 1;

uint32_t g_num_groups;
uint32_t g_total_routers;
uint32_t g_total_terminals;
uint32_t g_total_procs;
uint32_t g_radix;
int g_num_packets;
int g_num_chunks;
int g_max_packets;

// Messages an LP can send to another LP go through htram when aggregating,
// which carries payloads of up to PDES_PAYLOAD_BYTES (24, src/htram.mk)
#define DRAGONFLY_SLOT_BYTES 24
static_assert(sizeof(GenerateMsg) <= DRAGONFLY_SLOT_BYTES, "GenerateMsg too big");
static_assert(sizeof(RouterArriveMsg) <= DRAGONFLY_SLOT_BYTES, "RouterArriveMsg too big");
static_assert(sizeof(TerminalArriveMsg) <= DRAGONFLY_SLOT_BYTES, "TerminalArriveMsg too big");
static_assert(sizeof(CreditMsg) <= DRAGONFLY_SLOT_BYTES, "CreditMsg too big");
#ifdef PDES_PAYLOAD_BYTES
static_assert(DRAGONFLY_SLOT_BYTES <= PDES_PAYLOAD_BYTES, "htram payload slot smaller than 24 B");
#endif

////////////////////////////////// Main ///////////////////////////////////////

int main(int argc, char** argv) {
  ArgumentSet args("Dragonfly Model");
  args.register_argument("routers-per-group", "Routers per group (a)", g_routers_per_group);
  args.register_argument("global-channels", "Global channels per router (h, even)", g_global_channels);
  args.register_argument("terminals-per-router", "Terminals per router (p)", g_terminals_per_router);
  args.register_argument("traffic", "UNIFORM RANDOM=1, WORST CASE=2, TRANSPOSE=3, NEAREST NEIGHBOR=4, BISECTION=5, NEAREST ROUTER=6", g_traffic);
  args.register_argument("routing", "MINIMAL=0, NON_MINIMAL=1, ADAPTIVE=2 (not implemented: routes as MINIMAL)", g_routing);
  args.register_argument("arrive-rate", "Mean packet inter-arrival time (ns); each process sends 3000 / this messages", g_mean_interval);
  args.register_argument("local-vc-size", "Local channel buffer (chunks)", g_local_vc_size);
  args.register_argument("global-vc-size", "Global channel buffer (chunks)", g_global_vc_size);
  args.register_argument("terminal-vc-size", "Terminal channel buffer (chunks)", g_terminal_vc_size);
  args.register_argument("routers-per-chare", "Routers (with their terminals and processes) per LP chare", g_routers_per_chare);
  tw_add_arguments(&args);

  tw_init(argc, argv);

  if (g_routers_per_group == 0 || g_terminals_per_router == 0 ||
      g_global_channels == 0 || g_global_channels % 2 != 0) {
    CkAbort("Dragonfly: need a, p > 0 and an even h > 0\n");
  }
  if (g_routing > ADAPTIVE) CkAbort("Dragonfly: unknown routing algorithm\n");
  if (g_traffic < UNIFORM_RANDOM || g_traffic > NEAREST_ROUTER) {
    CkAbort("Dragonfly: unknown traffic pattern\n");
  }
  if (g_mean_interval <= 0) CkAbort("Dragonfly: --arrive-rate must be positive\n");
  if (g_tw_lookahead > MIN_DELAY) {
    CkAbort("Dragonfly: lookahead must be at most 100 (0.1 ns, the smallest delay)\n");
  }

  g_num_packets = MESSAGE_SIZE / PACKET_SIZE;
  g_num_chunks = PACKET_SIZE / CHUNK_SIZE;
  g_max_packets = INJECTION_INTERVAL / g_mean_interval;
  g_num_groups = g_routers_per_group * g_global_channels + 1;
  g_total_routers = g_routers_per_group * g_num_groups;
  g_total_terminals = g_total_routers * g_terminals_per_router;
  g_total_procs = g_total_terminals;
  g_radix = g_routers_per_group + g_global_channels + g_terminals_per_router;

  if (g_num_groups > INT16_MAX || g_radix * NUM_VC > UINT16_MAX ||
      (uint64_t)g_total_routers + 2ull * g_total_terminals > UINT32_MAX) {
    CkAbort("Dragonfly: network too large for the message field widths\n");
  }
  if (g_routers_per_chare == 0 || g_total_routers % g_routers_per_chare != 0) {
    CkAbort("Dragonfly: routers-per-chare must divide the number of routers\n");
  }

  register_msg_type<GenerateMsg>();
  register_msg_type<TerminalSendMsg>();
  register_msg_type<RouterArriveMsg>();
  register_msg_type<RouterSendMsg>();
  register_msg_type<RouterWaitMsg>();
  register_msg_type<TerminalArriveMsg>();
  register_msg_type<CreditMsg>();
  register_msg_type<FinishMsg>();
  register_msg_type<ProcSendMsg>();

  g_total_lps = g_total_routers + g_total_terminals + g_total_procs;
  g_num_chares = g_total_routers / g_routers_per_chare;

  tw_create_simulation(new DragonflyFactory(), new DragonflyMapper());

  if (CkMyPe() == 0) {
    printf("========================================\n");
    printf("Dragonfly Model Configuration...........\n");
    printf("   Groups.................%u\n", g_num_groups);
    printf("   Routers................%u (%u per group)\n", g_total_routers, g_routers_per_group);
    printf("   Global channels........%u per router\n", g_global_channels);
    printf("   Terminals..............%u (%u per router)\n", g_total_terminals, g_terminals_per_router);
    printf("   Routing................%u\n", g_routing);
    printf("   Traffic................%u\n", g_traffic);
    printf("   Arrive rate............%lf ns (%d messages per process)\n", g_mean_interval, g_max_packets);
    printf("   VC sizes...............local %u, global %u, terminal %u chunks\n",
           g_local_vc_size, g_global_vc_size, g_terminal_vc_size);
    printf("   Routers per chare......%u\n", g_routers_per_chare);
    printf("   Time unit..............1 ps (%.0f per ns)\n", TIME_PER_NS);
    printf("   Message sizes (B)......generate %zu, router arrive %zu, terminal arrive %zu, credit %zu;"
           " self: terminal send %zu, router send %zu, wait %zu, finish %zu, process send %zu\n",
           sizeof(GenerateMsg), sizeof(RouterArriveMsg), sizeof(TerminalArriveMsg),
           sizeof(CreditMsg), sizeof(TerminalSendMsg), sizeof(RouterSendMsg),
           sizeof(RouterWaitMsg), sizeof(FinishMsg), sizeof(ProcSendMsg));
    printf("========================================\n\n");
  }

  tw_run();
  report_stats();
  tw_end();
  return 0;
}
