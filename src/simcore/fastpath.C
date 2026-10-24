#include "fastpath.h"

#include "event.h"
#include "globals.h"
#include "lp.h"
#include "mapper.h"
#include "scheduler.h"
#include "statistics.h"
#include "util.h"

#include <atomic>
#include <vector>

extern CProxy_LPChare lps;

/**
 * A PE's inbox for messages from other PEs of its process: a lock-free list
 * that senders push onto and the owner takes whole (newest first). One cache
 * line each, so pushes to different PEs do not contend.
 */
struct alignas(64) FpInbox {
  std::atomic<RemoteEvent*> head;
  FpInbox() : head(NULL) {}
};

/** This process's inboxes, one per PE by rank, made by whichever PE needs them first */
static FpInbox* process_inboxes() {
  static FpInbox* inboxes = new FpInbox[CkMyNodeSize()];
  return inboxes;
}

/** Per-PE tables and the inbox for messages from this PE to itself */
struct FpState {
  std::vector<int> chare_pe;          ///< home PE of every LP chare
  std::vector<LPChare*> local;        ///< this PE's chares, by index
  std::vector<RemoteEvent*> self_q;   ///< messages from this PE to itself
  std::vector<RemoteEvent*> scratch;

  /**
   * Home PE of an LP chare. LPs never migrate with the fast path on (load
   * balancing is refused). Filled on first use: the LP array does not exist
   * when the option is checked.
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

  LPChare* local_chare(uint64_t chare) {
    if (local.empty()) local.assign(g_num_chares, NULL);
    LPChare* c = local[chare];
    if (c == NULL) {
      c = lps(chare).ckLocal();
      TW_ASSERT(c != NULL, "PE %d: fast path delivered an event for LP chare "
          "%llu, which is not on this PE\n", CkMyPe(), (unsigned long long)chare);
      local[chare] = c;
    }
    return c;
  }
};

static thread_local FpState fp_state;

void fp_check() {
  if (!g_tw_local_fast_path) return;
  if (g_tw_synchronization_protocol != OPTIMISTIC || g_tw_gvt_scheme != 4 ||
      g_tw_sched_park) {
    CkAbort("--local-fast-path=1 needs the optimistic scheduler, the bucketed "
            "GVT (--gvt=4) and no --sched-park: an event waiting in an inbox "
            "is in transit, which only the bucketed GVT's counts see, and "
            "every PE must keep draining its inbox\n");
  }
  if (g_tw_adaptive_buckets) {
    CkAbort("--local-fast-path=1 does not support --gvt-adaptive-buckets\n");
  }
  if (g_tw_ldb_interval > 0 || g_tw_ldb_first > 0) {
    CkAbort("--local-fast-path=1 does not support load balancing: events "
            "go to their chare's home PE\n");
  }
  CkPrintf("Local fast path: events for other chares in this process are "
           "handed over by pointer (--local-fast-path)\n");
}

/** Push msg onto the inbox of the PE that owns its chare. False: elsewhere */
static bool fp_push(RemoteEvent* msg, uint64_t dest_chare) {
  FpState& st = fp_state;
  int pe = st.home_pe(dest_chare);
  if (pe == CkMyPe()) {
    st.self_q.push_back(msg);
    return true;
  }
  // --local-fast-path=2: this PE only (other PEs through htram or messages)
  if (g_tw_local_fast_path == 2 || CkNodeOf(pe) != CkMyNode()) return false;
  std::atomic<RemoteEvent*>& head = process_inboxes()[CkRankOf(pe)].head;
  RemoteEvent* h = head.load(std::memory_order_relaxed);
  msg->fp_next = h;
  while (!head.compare_exchange_weak(h, msg, std::memory_order_release,
                                     std::memory_order_relaxed)) {
    msg->fp_next = h;
    PE_STATS(fast_push_retries)++;  // another PE pushed (or a spurious failure)
  }
  return true;
}

bool fp_send(RemoteEvent* msg, uint64_t dest_chare) {
  if (!g_tw_local_fast_path) return false;
  if (!fp_push(msg, dest_chare)) return false;
  PE_STATS(fast_sends)++;
  return true;
}

void fp_send_anti(Event* e) {
  RemoteEvent* anti = remote_event_new(0);
  anti->event_id = e->event_id;
  anti->ts = e->ts;
  anti->dest_lp = e->dest_lp;
  anti->src_lp = e->src_lp;
  anti->anti = true;
  anti->offset = e->offset;
  anti->type_size = 0;
  anti->fp_target = e->peer;
  PE_STATS(anti_sends)++;
  PE_STATS(fast_antis)++;
  // Never false: event holding is refused with the fast path
  CpvAccess(g_scheduler)->produce(anti);
  bool pushed = fp_push(anti, g_lp_mapper->get_chare_id(e->dest_lp));
  TW_ASSERT(pushed, "PE %d: anti-message for a fast-path event whose chare "
      "is not in this process\n", CkMyPe());
}

static void fp_deliver(FpState& st, RemoteEvent* m) {
  LPChare* c = st.local_chare(g_lp_mapper->get_chare_id(m->dest_lp));
  if (m->anti) {
    c->recv_fast_anti(m);
  } else {
    c->recv_fast_event(m);
  }
}

void fp_drain() {
  if (!g_tw_local_fast_path) return;
  FpState& st = fp_state;
  {
    std::atomic<RemoteEvent*>& head = process_inboxes()[CkMyRank()].head;
    if (head.load(std::memory_order_relaxed) != NULL) {
      RemoteEvent* m = head.exchange(NULL, std::memory_order_acquire);
      // Newest first: reverse to send order, so an event precedes its
      // anti-message
      RemoteEvent* prev = NULL;
      while (m) {
        RemoteEvent* next = m->fp_next;
        m->fp_next = prev;
        prev = m;
        m = next;
      }
      for (m = prev; m != NULL;) {
        RemoteEvent* next = m->fp_next;  // an anti-message is freed on delivery
        fp_deliver(st, m);
        m = next;
      }
    }
  }
  // Delivering may cancel events and so queue anti-messages to this PE
  while (!st.self_q.empty()) {
    st.scratch.swap(st.self_q);
    for (RemoteEvent* m : st.scratch) fp_deliver(st, m);
    st.scratch.clear();
  }
}
