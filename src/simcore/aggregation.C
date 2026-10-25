#include "aggregation.h"

#include "event.h"
#include "globals.h"
#include "lp.h"
#include "mapper.h"
#include "statistics.h"
#include "util.h"

#ifndef CHARADES_HTRAM

void agg_create(CkCallback) {
  CkAbort("--aggregation=1 needs Charades built with HTRAM_DIR set in "
          "config.mk\n");
}
bool agg_send(RemoteEvent*, uint64_t) { return false; }
void agg_flush_idle() {}
void agg_drain() {}
void agg_flush_gvt() {}
void agg_flush_all() {}
void agg_collect_stats(Statistics*) {}
void agg_set_window(uint64_t) {}

#include "aggregation.decl.h"
#include "aggregation.def.h"

#else

#include "htram_group.h"
#include "aggregation.decl.h"

#include <algorithm>
#include <cstring>
#include <vector>

extern CProxy_LPChare lps;

/**
 * Events with ts < GVT + this ship at once. Under the bucketed GVT it is at
 * least the bucket size, i.e. every event in the sender's current bucket is
 * urgent: that bucket completes only when all its events have arrived, so one
 * left in a buffer would hold GVT until this PE ran out of work (a busy PE in
 * an imbalanced model runs optimistically to the end time first). An event
 * in a later bucket waits at most until its bucket becomes current, when
 * every PE flushes (agg_flush_gvt, --agg-gvt-flush=2).
 *
 * Deadline policy (--agg-policy=1): the window is the horizon instead, and
 * idle PEs and GVT updates ship only destinations holding an event that is
 * now due (HTram::flushDue on the per-destination minimum timestamp). Still
 * live under the bucketed GVT: an event left in a buffer is at least one
 * bucket ahead of GVT, and becomes due -- and every PE ships it -- by the GVT
 * update that makes its bucket current.
 */
static Time urgent_window(Time window) {
  Time w = g_tw_agg_urgent;
  if (g_tw_agg_policy == 1) {
    // Deadline policy: the horizon. No receiver may execute past GVT + window,
    // so an event further out than that can wait at no rollback cost, and the
    // default holds exactly that long. Measured (uniform PHOLD, remote 0.5,
    // window 250, 4 Stampede3 nodes): a horizon below the window delivers
    // events late (WPs: 8% stragglers, 47-62% efficiency); at the window,
    // 1.6% stragglers and 2.7-3.4x direct; above it, more events are due on
    // insert and messages shrink (2 x window: 1.9x).
    // Following the window, plus --agg-horizon-margin: a held event ships
    // when its sender learns of the GVT update that makes it due, and a
    // receiver that learned of it first may already have run up to the new
    // GVT + window. With h = W that left a waste floor that no window
    // removes: 3% / 1.6% / 0.7% of events rolled back at buckets 4 / 8 / 16
    // (4 nodes, lookahead 10 / mean 200), against none sent directly.
    w = g_tw_agg_horizon ? g_tw_agg_horizon : window + g_tw_agg_horizon_margin;
  }
  return std::max<Time>(w, g_tw_gvt_scheme == 4 ? g_tw_gvt_bucket_size : 0);
}

/**
 * --agg-inbox: a node-level receive hands each PE its share through an inbox
 * the PE drains in its own loop (agg_drain), instead of a receivePerPE message
 * carrying ~2.5 events. Only where nothing waits on quiescence: the bucketed
 * GVT counts each event when its chare receives it, so an event still in an
 * inbox is in transit, but a QD-based GVT would not see it; and only with
 * the optimistic scheduler, whose loop never stops (hence not --sched-park,
 * where a parked PE would not drain). On by default; elsewhere node receives
 * fall back to a receivePerPE message per PE.
 */
static bool agg_inbox_on() {
  return g_tw_agg_inbox && g_tw_gvt_scheme == 4 &&
         g_tw_synchronization_protocol == OPTIMISTIC && !g_tw_sched_park;
}

class Aggregator : public CBase_Aggregator {
  public:
    HTram* tram;  ///< where new events go
    /**
     * Every htram instance: the one --agg-mode made, and with --agg-auto a
     * second in WPs mode. Flushes, inbox drains and statistics cover both, so
     * events left in one after sends move to the other still go out.
     */
    std::vector<HTram*> trams;
    Time urgent;  ///< urgent_window(the current window), read on every send
    unsigned advances;  ///< GVT advances seen (--agg-auto)

    Aggregator(CkGroupID tram_gid, CkGroupID wps_gid);
    void auto_choose(int n, double* v);
    /** --agg-auto: after enough GVT advances, add this PE's traffic to the choice */
    void auto_count_advance();

    /**
     * Home PE of an LP chare. LPs never migrate with aggregation on (load
     * balancing is refused), so this is where the chare is. Filled on first
     * use: the LP array does not exist yet when the aggregators are created.
     */
    int home_pe(uint64_t chare) {
      if (chare_pe.empty()) {
        CkLocMgr* mgr = lps.ckLocMgr();
        chare_pe.resize(g_num_chares);
        for (uint64_t c = 0; c < g_num_chares; c++) {
          chare_pe[c] = mgr->homePe(CkArrayIndex1D(c));
        }
      }
      return chare_pe[chare];
    }

    /** Batch delivery from htram: rebuild each event and hand it to its chare */
    static void deliver(void* self, PdesItem* items, int n);
    /** Destination PE of an item, for htram's held-item drains */
    static int dest_pe_of(void* self, PdesItem item);

  private:
    std::vector<int> chare_pe;
    std::vector<LPChare*> local_chares;

    LPChare* local_chare(uint64_t chare) {
      if (local_chares.empty()) local_chares.assign(g_num_chares, NULL);
      LPChare* c = local_chares[chare];
      if (c == NULL) {
        c = lps(chare).ckLocal();
        TW_ASSERT(c != NULL, "PE %d: htram delivered an event for LP chare "
            "%llu, which is not on this PE\n", CkMyPe(),
            (unsigned long long)chare);
        local_chares[chare] = c;
      }
      return c;
    }
};

CpvStaticDeclare(Aggregator*, g_aggregator);

Aggregator::Aggregator(CkGroupID tram_gid, CkGroupID wps_gid) : advances(0) {
  CpvInitialize(Aggregator*, g_aggregator);
  CpvAccess(g_aggregator) = this;
  tram = CProxy_HTram(tram_gid).ckLocalBranch();
  trams.push_back(tram);
  if (g_tw_agg_auto) trams.push_back(CProxy_HTram(wps_gid).ckLocalBranch());
  // Before the scheduler exists, so before PE_VALUE(window): the start value
  urgent = urgent_window(g_tw_optimism_window);
  for (size_t i = 0; i < trams.size(); i++) {
    HTram* t = trams[i];
    t->set_func_ptr_retarr(deliver, dest_pe_of, NULL, this);
    t->setAggregationMode(i == 0 ? g_tw_agg_mode : WPs);
    // Node-level receives (WPs, PP) send nothing to PEs that get no items
    t->setSkipEmptyDeliveries(true);
    if (agg_inbox_on()) t->setInboxDelivery(true);
  }
}

/**
 * --agg-auto (RESULTS.md "Which htram mode and buffer for which workload"):
 * on 4 and 16 Stampede3 nodes, PP with 2,048-event buffers was 1.03-1.09x PP
 * 512 wherever at most 27% of events left their process, and 0.70-0.88 from
 * 50%; WPs won only where PP 512's messages carried about 20 events or fewer
 * (uniform traffic on 16 nodes: 15), and lost badly where they were large
 * (uniform on 4 nodes: 114, WPs 0.72). The run starts on PP and its own
 * buffer; after --agg-auto-advances GVT advances, every PE adds what it sent
 * to one reduction, and all apply the same choice from the sums.
 */
enum { AUTO_OFF_PROCESS, AUTO_SENDS, AUTO_ITEMS, AUTO_MSGS, AUTO_N };

void Aggregator::auto_count_advance() {
  if (++advances != g_tw_agg_auto_advances) return;
  Statistics* s = get_statistics();
  double v[AUTO_N];
  // Events that left the process (through htram or directly) and all sends
  v[AUTO_OFF_PROCESS] = (double)(s->agg_items + s->agg_direct);
  v[AUTO_SENDS] = (double)(s->self_sends + s->local_sends + s->remote_sends);
  v[AUTO_ITEMS] = (double)s->agg_items;
  v[AUTO_MSGS] = (double)trams[0]->msgs_sent;
  contribute(sizeof(v), v, CkReduction::sum_double,
      CkCallback(CkReductionTarget(Aggregator, auto_choose), thisProxy));
}

void Aggregator::auto_choose(int n, double* v) {
  CkAssert(n == AUTO_N);
  double share = v[AUTO_SENDS] > 0 ? v[AUTO_OFF_PROCESS] / v[AUTO_SENDS] : 0;
  double per_msg = v[AUTO_MSGS] > 0 ? v[AUTO_ITEMS] / v[AUTO_MSGS] : 0;
  const char* choice;
  if (share <= g_tw_agg_auto_share) {
    // Live: PP never fills the per-PE buffers setBufferSize rebuilds, and its
    // shared buffers are allocated at htram's largest size. PEs of a process
    // switch at different times; a PE still on the smaller size only sends
    // its own 16-item buffers while another fills the shared one further.
    trams[0]->setBufferSize(g_tw_agg_auto_buffer);
    choice = "PP with the large buffer";
  } else if (per_msg < g_tw_agg_auto_msg) {
    tram = trams[1];  // what PP still holds goes out with its flushes
    choice = "WPs";
  } else {
    choice = "PP as started";
  }
  if (CkMyPe() == 0) {
    CkPrintf("Aggregation auto: after %u GVT advances, %.3f of events leave "
             "their process and PP messages carry %.1f events: %s\n",
             g_tw_agg_auto_advances, share, per_msg, choice);
  }
}

void Aggregator::deliver(void* self, PdesItem* items, int n) {
  Aggregator* a = (Aggregator*)self;
  for (int i = 0; i < n; i++) {
    const PdesItem& it = items[i];
    RemoteEvent* msg = remote_event_new(it.type_size);
    msg->ts = it.ts;
    msg->event_id = it.event_id;
    msg->src_lp = it.src_lp;
    msg->dest_lp = it.dest_lp;
    msg->phase = it.phase;
    msg->offset = it.offset;
    msg->far = it.flags & 1;
    msg->held = (it.flags & 2) != 0;
    msg->type_id = it.type_id;
    msg->type_size = it.type_size;
    memcpy(msg->data, it.payload, it.type_size);
#ifdef PDES_TIMED
    msg->send_ns = it.send_ns;
    msg->src_pe = it.src_pe;
#endif
    a->local_chare(g_lp_mapper->get_chare_id(it.dest_lp))->recv_remote_event(msg);
  }
}

int Aggregator::dest_pe_of(void* self, PdesItem item) {
  return ((Aggregator*)self)->home_pe(g_lp_mapper->get_chare_id(item.dest_lp));
}

/******************************************************************************/
/* Creation (PE 0): htram's node groups, then htram, then the aggregators.    */
/* Each step waits on quiescence for the last to exist on every PE: HTram's   */
/* constructor reads its node groups' local branches, and Aggregator's reads  */
/* HTram's. HTram's own start reduction will not do: on one PE it completes   */
/* inside HTram's constructor, before that branch is registered.              */
/******************************************************************************/
static CkCallback agg_done;
static CkGroupID agg_recv_gid, agg_src_gid, agg_tram_gid;
// --agg-auto: a second htram, in WPs mode, with its own node groups
static CkGroupID agg_recv2_gid, agg_src2_gid, agg_tram2_gid;

static void aggregators_created(void*, void* msg) {
  if (msg) CkFreeMsg(msg);
  agg_done.send();
}

static void create_aggregators(void*, void* msg) {
  if (msg) CkFreeMsg(msg);
  CProxy_Aggregator::ckNew(agg_tram_gid, agg_tram2_gid);
  CkStartQD(CkCallback(aggregators_created, NULL));
}

static void create_tram(void*, void* msg) {
  if (msg) CkFreeMsg(msg);
  agg_tram_gid = CProxy_HTram::ckNew(agg_recv_gid, agg_src_gid,
      g_tw_agg_buffer, /*enable_timed_flushing=*/false, /*flush_timer=*/0.0,
      /*ret_item=*/false, /*request=*/false,
      CkCallback(CkCallback::ignore));
  if (g_tw_agg_auto) {
    agg_tram2_gid = CProxy_HTram::ckNew(agg_recv2_gid, agg_src2_gid,
        g_tw_agg_buffer, /*enable_timed_flushing=*/false, /*flush_timer=*/0.0,
        /*ret_item=*/false, /*request=*/false,
        CkCallback(CkCallback::ignore));
  }
  CkStartQD(CkCallback(create_aggregators, NULL));
}

void agg_create(CkCallback done) {
  if (g_tw_ldb_interval > 0 || g_tw_ldb_first > 0) {
    CkAbort("--aggregation=1 does not support load balancing: htram routes "
            "events by their chare's home PE\n");
  }
  if (g_tw_agg_mode > WW) {
    CkAbort("--agg-mode must be 0-3 (WPs, WsP, PP, WW), not %u\n",
            g_tw_agg_mode);
  }
  if (g_tw_agg_buffer < 1 || g_tw_agg_buffer > BUFSIZE ||
      (g_tw_agg_mode == PP && g_tw_agg_buffer % LOCAL_BUFSIZE)) {
    CkAbort("--agg-buffer must be in 1..%d%s, not %u\n", BUFSIZE,
            g_tw_agg_mode == PP ? " and a multiple of 16 under PP" : "",
            g_tw_agg_buffer);
  }
  const char* modes[] = {"WPs", "WsP", "PP", "WW"};
  CkPrintf("Aggregation: htram %s, %u-event buffers, %d-byte payload slot, "
           "%s policy, events with ts < GVT + %llu ship at once%s, scope %s%s\n",
           modes[g_tw_agg_mode], g_tw_agg_buffer, PDES_PAYLOAD_BYTES,
           g_tw_agg_policy ? "deadline" : "eager",
           (unsigned long long)urgent_window(g_tw_optimism_window),
           g_tw_agg_policy && g_tw_ctl && !g_tw_agg_horizon
               ? " (to start: the horizon follows --ctl)" : "",
           g_tw_agg_scope ? "other processes" : "all remote chares",
           g_tw_agg_policy ? "" : (g_tw_agg_gvt_flush == 2 ? ", GVT updates flush all"
                                   : g_tw_agg_gvt_flush == 1 ? ", GVT updates flush stale"
                                   : ""));
  if (g_tw_agg_policy > 1) {
    CkAbort("--agg-policy must be 0 (eager) or 1 (deadline), not %u\n",
            g_tw_agg_policy);
  }
  if (g_tw_agg_policy == 0 && g_tw_gvt_scheme == 4 && g_tw_agg_gvt_flush != 2) {
    CkAbort("--aggregation=1 with the bucketed GVT needs --agg-gvt-flush=2: "
            "an event waits for its bucket to become current\n");
  }
  if (agg_inbox_on()) CkPrintf("Aggregation: node receives deliver through per-PE inboxes\n");
  if (g_tw_agg_auto) {
    if (g_tw_agg_mode != PP) {
      CkAbort("--agg-auto=1 starts from PP: use --agg-mode=2\n");
    }
    if (g_tw_agg_auto_buffer > BUFSIZE || g_tw_agg_auto_buffer % LOCAL_BUFSIZE) {
      CkAbort("--agg-auto-buffer must be at most %d and a multiple of %d\n",
              BUFSIZE, LOCAL_BUFSIZE);
    }
    CkPrintf("Aggregation auto: after %u GVT advances, PP %u if at most %.2f of "
             "events leave their process, else WPs %u if PP messages carry "
             "fewer than %.0f events, else stay\n", g_tw_agg_auto_advances,
             g_tw_agg_auto_buffer, g_tw_agg_auto_share, g_tw_agg_buffer,
             g_tw_agg_auto_msg);
  }
  agg_done = done;
  agg_recv_gid = CProxy_HTramRecv::ckNew();
  agg_src_gid = CProxy_HTramNodeGrp::ckNew();
  if (g_tw_agg_auto) {
    agg_recv2_gid = CProxy_HTramRecv::ckNew();
    agg_src2_gid = CProxy_HTramNodeGrp::ckNew();
  }
  CkStartQD(CkCallback(create_tram, NULL));
}

/******************************************************************************/
/* Send and flush                                                             */
/******************************************************************************/
bool agg_send(RemoteEvent* msg, uint64_t dest_chare) {
  if (!g_tw_aggregation) return false;
  Aggregator* a = CpvAccess(g_aggregator);
  Statistics* s = get_statistics();
  if (msg->type_size > PDES_PAYLOAD_BYTES) {
    s->agg_direct++;
    return false;
  }
  int pe = a->home_pe(dest_chare);
  if (g_tw_agg_scope == 1 && CkNodeOf(pe) == CkMyNode()) {
    s->agg_direct++;
    return false;
  }

  int64_t t0 = g_tw_comm_stats ? comm_now_ns() : 0;
  PdesItem it{};
  it.ts = msg->ts;
  it.event_id = msg->event_id;
  it.src_lp = msg->src_lp;
  it.dest_lp = msg->dest_lp;
  it.phase = msg->phase;
  it.offset = msg->offset;
  // Due: sent at once (flushTo below). Otherwise held until a buffer fills or
  // a GVT update makes it due (flush_due); the receiver counts a held event
  // that straggles as late (--ctl-floor=2)
  bool due = it.ts - PE_VALUE(g_last_gvt) < a->urgent;
  it.flags = (msg->far ? 1 : 0) | (due ? 0 : 2);
  it.type_id = msg->type_id;
  it.type_size = msg->type_size;
  memcpy(it.payload, msg->data, msg->type_size);
#ifdef PDES_TIMED
  it.send_ns = t0;
  it.src_pe = g_tw_comm_stats ? CkMyPe() : -1;
#endif
  remote_event_delete(msg);

  // Sends are never earlier than GVT, so the difference cannot wrap
  HTram* tram = a->tram;
  unsigned long long m0 = tram->msgs_sent;
  if (g_tw_agg_policy == 1) {
    tram->insert(it, pe, (long long)it.ts);
  } else {
    tram->insert(it, pe);
  }
  unsigned long long m1 = tram->msgs_sent;
  s->agg_msgs_full += m1 - m0;
  if (due) {
    tram->flushTo(pe);
    s->agg_msgs_urgent += tram->msgs_sent - m1;
    s->agg_urgent++;
  }
  s->agg_items++;
  if (g_tw_comm_stats) comm_send_end(t0);
  return true;
}

/** Deadline policy: ship every destination holding an event now due */
static void flush_due(Aggregator* a) {
  if (a->urgent == 0) return;  // nothing is ever due (blocking GVT, no window)
  // Due: ts < GVT + horizon, i.e. ts <= GVT + horizon - 1
  for (HTram* t : a->trams)
    t->flushDue((long long)(PE_VALUE(g_last_gvt) + a->urgent - 1));
}

/** Messages sent by every htram instance on this PE */
static unsigned long long msgs_sent(Aggregator* a) {
  unsigned long long m = 0;
  for (HTram* t : a->trams) m += t->msgs_sent;
  return m;
}

void agg_flush_idle() {
  if (!g_tw_aggregation) return;
  Aggregator* a = CpvAccess(g_aggregator);
  unsigned long long m0 = msgs_sent(a);
  if (g_tw_agg_policy == 1) {
    flush_due(a);
  } else {
    for (HTram* t : a->trams) t->flushIdle();
  }
  get_statistics()->agg_msgs_idle += msgs_sent(a) - m0;
}

void agg_drain() {
  if (!g_tw_aggregation) return;
  for (HTram* t : CpvAccess(g_aggregator)->trams) t->drainInbox();
}

void agg_flush_gvt() {
  if (!g_tw_aggregation) return;
  Aggregator* a = CpvAccess(g_aggregator);
  unsigned long long m0 = msgs_sent(a);
  for (HTram* t : a->trams) {
    if (g_tw_agg_policy == 1) continue;  // flush_due below covers both
    if (g_tw_agg_gvt_flush == 1) {
      t->flushStale();
    } else if (g_tw_agg_gvt_flush == 2) {
      t->flushPending();
    }
  }
  if (g_tw_agg_policy == 1) flush_due(a);
  get_statistics()->agg_msgs_gvt += msgs_sent(a) - m0;
  if (g_tw_agg_auto) a->auto_count_advance();
}

void agg_set_window(uint64_t window) {
  if (!g_tw_aggregation) return;
  CpvAccess(g_aggregator)->urgent = urgent_window(window);
}

void agg_flush_all() {
  if (!g_tw_aggregation) return;
  Aggregator* a = CpvAccess(g_aggregator);
  unsigned long long m0 = msgs_sent(a);
  for (HTram* t : a->trams) t->flushPending();
  get_statistics()->agg_msgs_round += msgs_sent(a) - m0;
}

void agg_collect_stats(Statistics* s) {
  if (!g_tw_aggregation) return;
  s->agg_msgs = s->agg_bytes = s->agg_idle_flushes = s->agg_pp_bypasses = 0;
  for (HTram* t : CpvAccess(g_aggregator)->trams) {
    s->agg_msgs += t->msgs_sent;
    s->agg_bytes += t->bytes_sent;
    s->agg_idle_flushes += t->idle_flushes;
    s->agg_pp_bypasses += t->local_bypasses;
  }
}

#include "aggregation.def.h"

#endif
