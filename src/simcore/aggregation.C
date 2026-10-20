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
void agg_flush_gvt() {}
void agg_flush_all() {}
void agg_collect_stats(Statistics*) {}

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
 */
static Time urgent_window() {
  return std::max<Time>(g_tw_agg_urgent,
      g_tw_gvt_scheme == 4 ? g_tw_gvt_bucket_size : 0);
}

class Aggregator : public CBase_Aggregator {
  public:
    HTram* tram;
    Time urgent;  ///< urgent_window(), read on every send

    Aggregator(CkGroupID tram_gid);

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

Aggregator::Aggregator(CkGroupID tram_gid) {
  CpvInitialize(Aggregator*, g_aggregator);
  CpvAccess(g_aggregator) = this;
  tram = CProxy_HTram(tram_gid).ckLocalBranch();
  urgent = urgent_window();
  tram->set_func_ptr_retarr(deliver, dest_pe_of, NULL, this);
  tram->setAggregationMode(g_tw_agg_mode);
  // Node-level receives (WPs, PP) send nothing to PEs that get no items
  tram->setSkipEmptyDeliveries(true);
}

void Aggregator::deliver(void* self, PdesItem* items, int n) {
  Aggregator* a = (Aggregator*)self;
  for (int i = 0; i < n; i++) {
    const PdesItem& it = items[i];
    RemoteEvent* msg = new (it.type_size) RemoteEvent();
    msg->ts = it.ts;
    msg->event_id = it.event_id;
    msg->src_lp = it.src_lp;
    msg->dest_lp = it.dest_lp;
    msg->phase = it.phase;
    msg->offset = it.offset;
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

static void aggregators_created(void*, void* msg) {
  if (msg) CkFreeMsg(msg);
  agg_done.send();
}

static void create_aggregators(void*, void* msg) {
  if (msg) CkFreeMsg(msg);
  CProxy_Aggregator::ckNew(agg_tram_gid);
  CkStartQD(CkCallback(aggregators_created, NULL));
}

static void create_tram(void*, void* msg) {
  if (msg) CkFreeMsg(msg);
  agg_tram_gid = CProxy_HTram::ckNew(agg_recv_gid, agg_src_gid,
      g_tw_agg_buffer, /*enable_timed_flushing=*/false, /*flush_timer=*/0.0,
      /*ret_item=*/false, /*request=*/false,
      CkCallback(CkCallback::ignore));
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
           "urgent within %llu of GVT, scope %s, GVT flush %u\n",
           modes[g_tw_agg_mode], g_tw_agg_buffer, PDES_PAYLOAD_BYTES,
           (unsigned long long)urgent_window(),
           g_tw_agg_scope ? "other processes" : "all remote chares",
           g_tw_agg_gvt_flush);
  if (g_tw_gvt_scheme == 4 && g_tw_agg_gvt_flush != 2) {
    CkAbort("--aggregation=1 with the bucketed GVT needs --agg-gvt-flush=2: "
            "an event waits for its bucket to become current\n");
  }
  agg_done = done;
  agg_recv_gid = CProxy_HTramRecv::ckNew();
  agg_src_gid = CProxy_HTramNodeGrp::ckNew();
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
  it.type_id = msg->type_id;
  it.type_size = msg->type_size;
  memcpy(it.payload, msg->data, msg->type_size);
#ifdef PDES_TIMED
  it.send_ns = t0;
  it.src_pe = g_tw_comm_stats ? CkMyPe() : -1;
#endif
  delete msg;

  // Sends are never earlier than GVT, so the difference cannot wrap
  if (it.ts - PE_VALUE(g_last_gvt) < a->urgent) {
    a->tram->insertUrgent(it, pe);
    s->agg_urgent++;
  } else {
    a->tram->insert(it, pe);
  }
  s->agg_items++;
  if (g_tw_comm_stats) comm_send_end(t0);
  return true;
}

void agg_flush_idle() {
  if (!g_tw_aggregation) return;
  CpvAccess(g_aggregator)->tram->flushIdle();
}

void agg_flush_gvt() {
  if (!g_tw_aggregation) return;
  HTram* tram = CpvAccess(g_aggregator)->tram;
  if (g_tw_agg_gvt_flush == 1) {
    tram->flushStale();
  } else if (g_tw_agg_gvt_flush == 2) {
    tram->flushPending();
  }
}

void agg_flush_all() {
  if (!g_tw_aggregation) return;
  CpvAccess(g_aggregator)->tram->flushPending();
}

void agg_collect_stats(Statistics* s) {
  if (!g_tw_aggregation) return;
  HTram* tram = CpvAccess(g_aggregator)->tram;
  s->agg_msgs = tram->msgs_sent;
  s->agg_bytes = tram->bytes_sent;
  s->agg_idle_flushes = tram->idle_flushes;
  s->agg_pp_bypasses = tram->local_bypasses;
}

#include "aggregation.def.h"

#endif
