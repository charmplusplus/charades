#include "vlsi.h"

using namespace vlsi;

GateLP::GateLP(uint32_t c, uint32_t l)
    : copy(c), local(l), pins(0), type(0), nin(0), out(0), pending(0), stats() {}

void GateLP::initialize() {
  const Netlist& G = g_netlist;
  if (copy == PAD_COPY) {   // padding: holds a constant and never sends
    type = G_CONST0;
    return;
  }
  type = G.type[local];
  nin = G.nin[local];
  out = G.init[local];
  pins = G.init_pins(local);
  if (type == G_DFF || type == G_INPUT) {
    tw_event_send(tw_event_new<ClockMsg>(gid, G.period, this));
  }
}

void GateLP::finalize() {
  add_stats(stats);
}

/** Send the output's new value to every pin it drives, offset ps from now */
void GateLP::send_output(Time offset) {
  const Netlist& G = g_netlist;
  for (uint32_t k = G.fan_start[local]; k < G.fan_start[local + 1]; k++) {
    Event* e = tw_event_new<PinMsg>(G.gid(copy, G.fan[k].dest), offset, this);
    PinMsg* m = e->get_data<PinMsg>();
    m->pin = G.fan[k].pin;
    m->value = out;
    tw_event_send(e);
  }
  uint32_t next = (copy + 1) % G.copies;
  for (uint32_t k = G.ring_start[local]; k < G.ring_start[local + 1]; k++) {
    Event* e = tw_event_new<PinMsg>(G.gid(next, G.ring[k]), offset, this);
    PinMsg* m = e->get_data<PinMsg>();
    m->pin = 0;
    m->value = out;
    tw_event_send(e);
  }
}

/*
 * A pin changes. A combinational gate evaluates 1 ps later, once for all the
 * pin changes of this time: the first one schedules the evaluation.
 * Flip-flops only record their D input until the next clock edge.
 */
void GateLP::forward(PinMsg* msg, tw_bf* bf) {
  uint32_t bit = 1u << msg->pin;
  bf->c0 = (((pins & bit) != 0) != (msg->value != 0));
  bf->c1 = 0;
  if (!bf->c0) return;   // drivers send only changes, so this does not happen
  pins ^= bit;
  if (type >= G_NOT) {
    Time t = get_current_time() + EVAL_STEP;
    if (pending != t) {
      bf->c1 = 1;
      msg->saved_pending = pending;
      pending = t;
      tw_event_send(tw_event_new<EvalMsg>(gid, EVAL_STEP, this));
    }
  }
}

void GateLP::reverse(PinMsg* msg, tw_bf* bf) {
  if (bf->c1) pending = msg->saved_pending;
  if (bf->c0) pins ^= 1u << msg->pin;
}

void GateLP::commit(PinMsg* msg, tw_bf* bf) {
  stats.pin_events++;
}

/** The output follows the pins; a change reaches the fanout after the gate's delay */
void GateLP::forward(EvalMsg* msg, tw_bf* bf) {
  int v = eval(type, pins, nin);
  bf->c0 = (v != out);
  if (!bf->c0) return;
  out = (uint8_t)v;
  send_output(g_netlist.delay[local] - EVAL_STEP);
}

void GateLP::reverse(EvalMsg* msg, tw_bf* bf) {
  if (bf->c0) out ^= 1;
}

void GateLP::commit(EvalMsg* msg, tw_bf* bf) {
  stats.evaluations++;
  if (bf->c0) stats.gate_changes++;
}

/** A clock edge: a flip-flop takes its D input, a random input a new value */
void GateLP::forward(ClockMsg* msg, tw_bf* bf) {
  const Netlist& G = g_netlist;
  int v = (type == G_DFF) ? (int)(pins & 1)
                          : G.input_value(copy, local, get_current_time() / G.period);
  bf->c0 = (v != out);
  if (bf->c0) {
    out = (uint8_t)v;
    send_output(type == G_DFF ? CLK_TO_Q : INPUT_DELAY);
  }
  tw_event_send(tw_event_new<ClockMsg>(gid, G.period, this));
}

void GateLP::reverse(ClockMsg* msg, tw_bf* bf) {
  if (bf->c0) out ^= 1;
}

void GateLP::commit(ClockMsg* msg, tw_bf* bf) {
  if (!bf->c0) return;
  if (type == G_DFF) stats.flop_changes++;
  else stats.input_changes++;
}
