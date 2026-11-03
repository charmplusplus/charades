#include "vlsi.h"

#include <algorithm>
#include <stdexcept>
#include <sys/stat.h>

vlsi::Netlist g_netlist;

static std::string g_netlist_path = "";
static uint32_t g_copies = 1;
static uint32_t g_span = 1;
static uint64_t g_period = 0;
static uint64_t g_input_seed = 1;
static uint32_t g_chunk = 512;
static uint32_t g_layout_bins = 0;
uint32_t g_copy_stats = 0;

/** A relative path that does not exist from here is taken from the binary's directory */
static std::string resolve(const std::string& path, const char* argv0) {
  struct stat st;
  if (path.empty() || path[0] == '/' || stat(path.c_str(), &st) == 0) return path;
  std::string exe(argv0);
  size_t slash = exe.find_last_of('/');
  return slash == std::string::npos ? path : exe.substr(0, slash + 1) + path;
}

int main(int argc, char* argv[]) {
  ArgumentSet args("VLSI Model");
  args.register_argument("netlist", "ITC'99 .bench netlist; inputs named IN* are the bus joined in the ring, inputs named LOGIC0/LOGIC1 are constants (a relative path is also looked up next to the binary)", g_netlist_path);
  args.register_argument("copies", "Copies of the netlist, joined in a ring: copy k's bus inputs are XORs of a random input and a flip-flop sampling copy k-1's outputs", g_copies);
  args.register_argument("span", "Spread each copy over this many groups of LPs (with one copy per node, over this many nodes); must divide --copies", g_span);
  args.register_argument("clock-period", "Clock period in ps: even and longer than the longest path (0: the longest path plus 25%, rounded up to 100 ps)", g_period);
  args.register_argument("input-seed", "Seed of the random inputs", g_input_seed);
  args.register_argument("layout-bins", "Bins per group of span copies in the balanced layout (0: PEs x span / copies, one bin per PE); the layout, and so the commit digest, depend on it", g_layout_bins);
  args.register_argument("chunk", "Layout: chunks of this many nets, balanced over the PEs by pre-simulated activity (0: file order, which puts every flip-flop on a copy's first PE)", g_chunk);
  args.register_argument("copy-stats", "After the model statistics, print each copy's committed pin changes plus evaluations (its activity) - NO=0, YES=1", g_copy_stats);
  tw_add_arguments(&args);

  tw_init(argc, argv);
  if (g_netlist_path.empty()) CkAbort("VLSI: give a netlist (--netlist=FILE.bench)\n");
  std::string path = resolve(g_netlist_path, argv[0]);
  try {
    g_netlist.load(path, g_copies, g_span, g_period, g_input_seed);
  } catch (const std::exception& e) {
    CkAbort("%s\n", e.what());
  }
  // One bin per PE when the PEs divide evenly among the groups of span copies
  uint32_t bins = g_layout_bins ? g_layout_bins : (uint32_t)std::max<uint64_t>(1, (uint64_t)CkNumPes() * g_span / g_copies);
  g_netlist.balance(g_chunk, bins);
  if (g_netlist.total() > 0xffffffffULL) CkAbort("VLSI: more than 2^32 LPs\n");

  register_msg_type<PinMsg>();
  register_msg_type<EvalMsg>();
  register_msg_type<ClockMsg>();

  // The block mapper needs a whole number of chares: pad with inert LPs
  uint64_t lpc = g_lps_per_chare ? g_lps_per_chare : 1;
  uint64_t padded = (g_netlist.total() + lpc - 1) / lpc * lpc;
  if (padded > 0xffffffffULL) CkAbort("VLSI: more than 2^32 LPs\n");
  g_total_lps = (unsigned)padded;
  tw_create_simulation(new GateFactory());

  if (CkMyPe() == 0) {
    const vlsi::Netlist& G = g_netlist;
    printf("========================================\n");
    printf("VLSI Model Configuration\n");
    printf("Netlist................%s\n", G.name.c_str());
    printf("Per copy...............%u nets: %u gates, %u flip-flops, %u random inputs, %zu bus bits\n",
           G.nets, G.gates, G.flops, G.random_inputs, G.bus.size());
    printf("Copies.................%u (ring), span %u\n", G.copies, G.span);
    uint64_t real = (uint64_t)G.copies * G.nets;
    printf("LPs....................%llu (%llu nets, %llu inert)\n", (unsigned long long)g_total_lps,
           (unsigned long long)real, (unsigned long long)(g_total_lps - real));
    if (G.chunk) {
      bool fits = (uint64_t)G.bins * (G.copies / G.span) == (uint64_t)CkNumPes() && (G.slots * (uint64_t)G.chunk) % lpc == 0;
      printf("Layout.................chunks of %u nets, %u per bin, %u bins per group of %u copies (busiest bin %.2fx the mean, estimated)%s\n",
             G.chunk, G.slots, G.bins, G.span, G.busiest, fits ? "" : "; bins do NOT match PEs");
    } else {
      printf("Layout.................file order\n");
    }
    printf("Longest path...........%llu ps\n", (unsigned long long)G.longest_path);
    printf("Clock period...........%llu ps\n", (unsigned long long)G.period);
    printf("Cycles.................%llu\n", (unsigned long long)(g_tw_ts_end / G.period));
    printf("Input seed.............%llu\n", (unsigned long long)G.seed);
    printf("========================================\n\n");
  }

  tw_run();
  report_stats();
  tw_end();
  return 0;
}
