#include "netlist.h"

#include <algorithm>
#include <fstream>
#include <stdexcept>
#include <unordered_map>

namespace vlsi {

static std::string trim(const std::string& s) {
  size_t a = s.find_first_not_of(" \t\r\n"), b = s.find_last_not_of(" \t\r\n");
  return a == std::string::npos ? "" : s.substr(a, b - a + 1);
}

static uint8_t type_of(const std::string& t, const std::string& line) {
  if (t == "AND") return G_AND;
  if (t == "NAND") return G_NAND;
  if (t == "OR") return G_OR;
  if (t == "NOR") return G_NOR;
  if (t == "NOT") return G_NOT;
  if (t == "BUFF" || t == "BUF") return G_BUFF;
  if (t == "XOR") return G_XOR;
  if (t == "XNOR") return G_XNOR;
  if (t == "DFF") return G_DFF;
  throw std::runtime_error("VLSI: unknown gate type in: " + line);
}

/** Intrinsic delay by type (ps), before the fan-in and fanout terms */
static uint64_t base_delay(uint8_t t) {
  switch (t) {
    case G_NOT: case G_BUFF: return 6;
    case G_NAND: return 8;
    case G_NOR: return 10;
    case G_AND: return 12;
    case G_OR: return 14;
    default: return 16;   // XOR, XNOR
  }
}

static uint64_t mix(uint64_t z) {   // splitmix64's finalizer
  z += 0x9e3779b97f4a7c15ULL;
  z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ULL;
  z = (z ^ (z >> 27)) * 0x94d049bb133111ebULL;
  return z ^ (z >> 31);
}

void Netlist::load(const std::string& path, uint32_t n_copies, uint32_t n_span, uint64_t want_period, uint64_t s) {
  copies = n_copies; span = n_span; seed = s;
  if (copies == 0 || span == 0 || copies % span)
    throw std::runtime_error("VLSI: --span must divide --copies");
  name = path.substr(path.find_last_of('/') + 1);
  std::ifstream in(path);
  if (!in) throw std::runtime_error("VLSI: cannot read netlist " + path);

  // ---- pass 1: names in order (inputs first, then gates), and the gate lines
  std::vector<std::string> inputs, outs, gnames, gtypes, glines;
  std::vector<std::vector<std::string>> gargs;
  std::string line;
  while (std::getline(in, line)) {
    line = trim(line);
    if (line.empty() || line[0] == '#') continue;
    if (line.compare(0, 6, "INPUT(") == 0) {
      inputs.push_back(trim(line.substr(6, line.find(')') - 6)));
    } else if (line.compare(0, 7, "OUTPUT(") == 0) {
      std::string o = trim(line.substr(7, line.find(')') - 7));
      if (std::find(outs.begin(), outs.end(), o) == outs.end()) outs.push_back(o);
    } else {
      size_t eq = line.find('='), lp = line.find('('), rp = line.rfind(')');
      if (eq == std::string::npos || lp == std::string::npos || rp == std::string::npos || lp < eq)
        throw std::runtime_error("VLSI: cannot parse: " + line);
      gnames.push_back(trim(line.substr(0, eq)));
      gtypes.push_back(trim(line.substr(eq + 1, lp - eq - 1)));
      std::vector<std::string> a;
      std::string list = line.substr(lp + 1, rp - lp - 1);
      size_t p = 0;
      while (p <= list.size()) {
        size_t c = list.find(',', p);
        if (c == std::string::npos) c = list.size();
        std::string x = trim(list.substr(p, c - p));
        if (!x.empty()) a.push_back(x);
        p = c + 1;
      }
      gargs.push_back(a);
      glines.push_back(line);
    }
  }
  std::unordered_map<std::string, uint32_t> id;
  for (auto& x : inputs) id.emplace(x, (uint32_t)id.size());
  for (auto& x : gnames) {
    if (!id.emplace(x, (uint32_t)id.size()).second) throw std::runtime_error("VLSI: net defined twice: " + x);
  }
  orig = (uint32_t)id.size();
  for (auto& x : inputs) if (x.compare(0, 2, "IN") == 0) bus.push_back(id[x]);
  const uint32_t B = (uint32_t)bus.size();
  nets = orig + 2 * B;
  for (auto& o : outs) {
    auto it = id.find(o);
    if (it == id.end()) throw std::runtime_error("VLSI: unknown output " + o);
    outputs.push_back(it->second);
  }
  if (B && outputs.empty()) throw std::runtime_error("VLSI: bus inputs but no outputs to join them to");

  // ---- types and fan-in
  type.assign(nets, G_INPUT); nin.assign(nets, 0);
  std::vector<std::vector<uint32_t>> fi(nets);
  for (size_t i = 0; i < inputs.size(); i++) {
    const std::string& x = inputs[i];
    if (x.find("LOGIC0") != std::string::npos) type[i] = G_CONST0;
    else if (x.find("LOGIC1") != std::string::npos) type[i] = G_CONST1;
  }
  for (size_t g = 0; g < gnames.size(); g++) {
    uint32_t me = (uint32_t)(inputs.size() + g);
    type[me] = type_of(gtypes[g], glines[g]);
    for (auto& a : gargs[g]) {
      auto it = id.find(a);
      if (it == id.end()) throw std::runtime_error("VLSI: unknown net " + a + " in: " + glines[g]);
      fi[me].push_back(it->second);
    }
    if (fi[me].empty() || fi[me].size() > 31 || ((type[me] == G_DFF || type[me] == G_NOT || type[me] == G_BUFF) && fi[me].size() != 1))
      throw std::runtime_error("VLSI: bad fan-in in: " + glines[g]);
  }
  // the ring: bus input b becomes XOR(external input b, ring flip-flop b)
  for (uint32_t b = 0; b < B; b++) {
    uint32_t x = bus[b], ext = orig + b, ff = orig + B + b;
    type[x] = G_XOR; fi[x] = {ext, ff};
    type[ext] = G_INPUT;
    type[ff] = G_DFF; fi[ff] = {};   // its D input is in the previous copy
  }
  fanin_start.assign(nets + 1, 0);
  for (uint32_t i = 0; i < nets; i++) {
    nin[i] = (uint8_t)fi[i].size();
    fanin_start[i + 1] = fanin_start[i] + nin[i];
  }
  fanin.clear();
  for (uint32_t i = 0; i < nets; i++) fanin.insert(fanin.end(), fi[i].begin(), fi[i].end());
  if (type.size() != nets) throw std::runtime_error("VLSI: internal size error");
  // ring flip-flops of a ring DFF have no fan-in in the copy; mark their pin count 1
  for (uint32_t b = 0; b < B; b++) nin[orig + B + b] = 1;

  // ---- fanout (CSR) within the copy, and the ring's edges into the next copy
  std::vector<std::vector<Fanout>> fo(nets);
  for (uint32_t g = 0; g < nets; g++)
    for (uint32_t k = fanin_start[g]; k < fanin_start[g + 1]; k++)
      fo[fanin[k]].push_back({g, (uint8_t)(k - fanin_start[g])});
  std::vector<std::vector<uint32_t>> rg(nets);
  for (uint32_t b = 0; b < B; b++) rg[outputs[b % outputs.size()]].push_back(orig + B + b);
  fan_start.assign(nets + 1, 0); ring_start.assign(nets + 1, 0);
  fan.clear(); ring.clear();
  for (uint32_t i = 0; i < nets; i++) {
    fan.insert(fan.end(), fo[i].begin(), fo[i].end());
    ring.insert(ring.end(), rg[i].begin(), rg[i].end());
    fan_start[i + 1] = (uint32_t)fan.size();
    ring_start[i + 1] = (uint32_t)ring.size();
  }

  // ---- delays, counts
  delay.assign(nets, 0);
  gates = flops = random_inputs = 0;
  for (uint32_t i = 0; i < nets; i++) {
    uint8_t t = type[i];
    if (t == G_INPUT) random_inputs++;
    else if (t == G_DFF) flops++;
    else if (t >= G_NOT) {
      gates++;
      uint64_t d = base_delay(t) + 2 * (nin[i] > 2 ? nin[i] - 2 : 0) + 2 * std::min<uint32_t>(fanout(i), 8);
      delay[i] = (uint16_t)d;
    }
  }

  // ---- topological order of the combinational gates; initial values (all
  // flip-flops and inputs 0, constants as given); the longest path
  std::vector<uint32_t> indeg(nets, 0), order;
  for (uint32_t g = 0; g < nets; g++) if (type[g] >= G_NOT) indeg[g] = nin[g];
  std::vector<uint64_t> arrive(nets, 0);
  init.assign(nets, 0);
  for (uint32_t i = 0; i < nets; i++) {
    if (type[i] == G_CONST1) init[i] = 1;
    if (type[i] == G_DFF) arrive[i] = CLK_TO_Q;
    if (type[i] == G_INPUT) arrive[i] = INPUT_DELAY;
  }
  std::vector<uint32_t> ready;
  for (uint32_t i = 0; i < nets; i++) if (type[i] < G_NOT) ready.push_back(i);
  while (!ready.empty()) {
    uint32_t u = ready.back(); ready.pop_back();
    if (type[u] >= G_NOT) {
      uint32_t pins = 0; uint64_t a = 0;
      for (uint32_t k = fanin_start[u]; k < fanin_start[u + 1]; k++) {
        if (init[fanin[k]]) pins |= 1u << (k - fanin_start[u]);
        a = std::max(a, arrive[fanin[k]]);
      }
      init[u] = (uint8_t)eval(type[u], pins, nin[u]);
      arrive[u] = a + delay[u];
      order.push_back(u);
    }
    for (uint32_t k = fan_start[u]; k < fan_start[u + 1]; k++) {
      uint32_t v = fan[k].dest;
      if (type[v] >= G_NOT && --indeg[v] == 0) ready.push_back(v);
    }
  }
  if (order.size() != gates) throw std::runtime_error("VLSI: the netlist has a combinational loop");
  longest_path = 0;
  for (uint32_t i = 0; i < nets; i++) {
    if (type[i] == G_DFF && i < orig) longest_path = std::max(longest_path, arrive[fanin[fanin_start[i]]]);
  }
  for (uint32_t o : outputs) longest_path = std::max(longest_path, arrive[o]);
  if (want_period) {
    if (want_period % 2 || want_period <= longest_path)
      throw std::runtime_error("VLSI: --clock-period must be even and longer than the longest path");
    period = want_period;
  } else {
    period = ((longest_path * 5 / 4) / 100 + 1) * 100;   // 25% margin, a multiple of 100 ps
  }
}

uint64_t Netlist::gid(uint32_t copy, uint32_t local) const {
  uint32_t group = copy / span, c = copy % span;
  uint32_t part = (uint32_t)((uint64_t)local * span / nets);
  uint64_t l = lo(part), len = lo(part + 1) - l;
  return (uint64_t)group * span * nets + span * l + c * len + (local - l);
}

void Netlist::locate(uint64_t g, uint32_t* copy, uint32_t* local) const {
  uint64_t gs = (uint64_t)span * nets;
  uint32_t group = (uint32_t)(g / gs);
  uint64_t r = g % gs;
  uint32_t part = (uint32_t)std::min<uint64_t>(r / nets, span - 1);
  while (part > 0 && span * lo(part) > r) part--;
  while (part + 1 < span && span * lo(part + 1) <= r) part++;
  uint64_t l = lo(part), len = lo(part + 1) - l, off = r - span * l;
  *copy = group * span + (uint32_t)(off / len);
  *local = (uint32_t)(l + off % len);
}

int Netlist::input_value(uint32_t copy, uint32_t local, uint64_t cycle) const {
  uint64_t h = mix(seed ^ mix(((uint64_t)copy << 32) | local));
  return (int)(mix(h ^ cycle) & 1);
}

uint32_t Netlist::init_pins(uint32_t local) const {
  uint32_t pins = 0;
  const uint32_t B = (uint32_t)bus.size();
  if (local >= orig + B) {   // a ring flip-flop: its D input is copy k-1's output
    return init[outputs[(local - orig - B) % outputs.size()]];
  }
  for (uint32_t k = fanin_start[local]; k < fanin_start[local + 1]; k++)
    if (init[fanin[k]]) pins |= 1u << (k - fanin_start[local]);
  return pins;
}

}  // namespace vlsi
