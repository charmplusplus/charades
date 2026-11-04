#include "event.h"

#include "aggregation.h"
#include "controller.h"
#include "avl_tree.h"
#include "event_buffer.h"
#include "factory.h"
#include "fastpath.h"
#include "globals.h"
#include "lp.h"
#include "mapper.h"
#include "scheduler.h"
#include "statistics.h"
#include "typedefs.h"
#include "util.h"
#include <algorithm>
#include <cstring>
#include <mutex>
#include <string>

extern CProxy_LPChare lps;

bool StandardEventComparator::operator()(const Event* e1, const Event* e2) {
  if (e1->ts != e2->ts) {
    return e1->ts < e2->ts;
  } else if (e1->src_lp != e2->src_lp) {
    return e1->src_lp < e2->src_lp;
  } else {
    return e1->event_id < e2->event_id;
  }
}

// Orders a chare's pending heap. It must be a strict weak ordering: the heap
// relies on "neither precedes the other" being transitive. Equal-timestamp
// events for different LPs used to compare equivalent both ways while those
// for the same LP were ordered, so with A and C for one LP and B for another
// (A ~ B, B ~ C, A < C) a sift could pop C before A, depending on what else
// the chare held and on arrival order. Models whose events carry their own
// data (traffic's cars) then gave each event different random draws, and the
// committed count changed with the run (traffic: 14718 sequential, 14789 on
// one process, 14766-14794 across processes). Ordering by destination LP too
// makes the order total; it changes nothing between independent LPs.
bool CustomEventComparator::operator()(const Event* e1, const Event* e2) {
  if (e1->ts != e2->ts) {
    return e1->ts < e2->ts;
  } else if (e1->dest_lp == e2->dest_lp) {
    return e1->owner->compare(e1, e2);
  } else {
    return e1->dest_lp < e2->dest_lp;
  }
}

/**
 * --msg-pool: event messages come from and go back to a per-PE pool, skipping
 * a Charm allocation and free per event (with htram, every remote event's
 * message is built on its receiver and freed when committed). Pooled messages
 * hold at least MSG_POOL_DATA bytes of event data; a message from anywhere
 * else is pooled if it is at least that big, so its capacity is read from its
 * envelope rather than assumed.
 */
static const size_t MSG_POOL_DATA = 32;
static const size_t MSG_POOL_MAX = 1 << 16;

/**
 * A message goes back into the pool of the PE that commits its event, not the
 * one that sent it. A PE that sends more than it receives runs dry and
 * allocates; one that receives more fills up and frees; and in a one-process
 * run both go to the C library, freeing memory another thread allocated
 * (RESULTS.md section 213: 4-11% of messages at 4-46 PEs). So a pool above
 * MSG_POOL_HIGH gives MSG_POOL_BATCH of its oldest messages to a spare list
 * shared by the process's PEs, and an empty pool takes a batch from it before
 * allocating: one lock per batch.
 */
static const size_t MSG_POOL_HIGH = 4096;
static const size_t MSG_POOL_BATCH = 2048;

struct MsgSpare {
  std::mutex lock;
  std::vector<RemoteEvent*> msgs;
  size_t cap;  ///< messages above this are freed
};

/**
 * The spare list's cap: what the per-PE pools could hold before (MSG_POOL_MAX
 * each), and at least 2^20 messages. Kept messages are never more than were
 * in flight at once, so a cap below that peak only frees messages each GVT
 * round to allocate them again in the next (on the Mac at 1 PE, b19 holds
 * more than 65,536 in flight).
 */
static const size_t MSG_SPARE_MIN = 1 << 20;

static MsgSpare& msg_spare() {
  static MsgSpare* spare = [] {
    MsgSpare* s = new MsgSpare();
    s->cap = std::max<size_t>((size_t)CkMyNodeSize() * MSG_POOL_MAX, MSG_SPARE_MIN);
    return s;
  }();
  return *spare;
}

/** Refill an empty pool from the spare list; false if it had none */
static bool msg_pool_refill(std::vector<RemoteEvent*>& pool) {
  MsgSpare& sp = msg_spare();
  std::lock_guard<std::mutex> guard(sp.lock);
  size_t n = std::min(sp.msgs.size(), MSG_POOL_BATCH);
  if (n == 0) return false;
  pool.insert(pool.end(), sp.msgs.end() - n, sp.msgs.end());
  sp.msgs.resize(sp.msgs.size() - n);
  return true;
}

/** Give a full pool's oldest batch to the spare list (or free it if that is full) */
static void msg_pool_spill(std::vector<RemoteEvent*>& pool) {
  MsgSpare& sp = msg_spare();
  bool kept = false;
  {
    std::lock_guard<std::mutex> guard(sp.lock);
    if (sp.msgs.size() + MSG_POOL_BATCH <= sp.cap) {
      sp.msgs.insert(sp.msgs.end(), pool.begin(), pool.begin() + MSG_POOL_BATCH);
      kept = true;
    }
  }
  if (!kept) {
    for (size_t i = 0; i < MSG_POOL_BATCH; i++) delete pool[i];
    PE_STATS(msg_pool_frees) += MSG_POOL_BATCH;
  }
  pool.erase(pool.begin(), pool.begin() + MSG_POOL_BATCH);
}

static size_t remote_event_capacity(RemoteEvent* m) {
  envelope* env = UsrToEnv(m);
  size_t head = (size_t)(m->data - (char*)env);
  size_t total = env->getTotalsize();
  return total > head ? total - head : 0;
}

/**
 * A message delivered through the runtime's shared-memory pool (Charm++ built
 * with --enable-shmem, or Reconverse's +ipc) sits in a block of this process's
 * segment, and freeing it returns the block. Kept in the message pool, it
 * would hold its block: the segment runs dry, and every send between the
 * node's processes then falls back to the network after timed-out allocations
 * (RESULTS.md section 201).
 */
static inline bool in_shared_block(RemoteEvent* m) {
  CmiIpcManager* manager = CsvAccess(coreIpcManager_);
  return manager && CmiMsgToIpcBlock(manager, (void*)UsrToEnv(m)) != nullptr;
}

RemoteEvent* remote_event_new(size_t size) {
  if (g_tw_msg_pool && size <= MSG_POOL_DATA) {
    std::vector<RemoteEvent*>& pool = PE_VALUE(msg_pool);
    if (!pool.empty() || (g_tw_msg_pool == 2 && msg_pool_refill(pool))) {
      RemoteEvent* m = pool.back();
      pool.pop_back();
      m->clear();
      // It may have been received: sending it again needs it marked unused
      _SET_USED(UsrToEnv(m), 0);
      return m;
    }
    PE_STATS(msg_pool_misses)++;
    return new (MSG_POOL_DATA) RemoteEvent();
  }
  return new (size) RemoteEvent();
}

void remote_event_delete(RemoteEvent* m) {
  if (m == NULL) return;
  if (g_tw_msg_pool) {
    std::vector<RemoteEvent*>& pool = PE_VALUE(msg_pool);
    if ((g_tw_msg_pool == 2 || pool.size() < MSG_POOL_MAX) &&
        remote_event_capacity(m) >= MSG_POOL_DATA && !in_shared_block(m)) {
      pool.push_back(m);
      if (g_tw_msg_pool == 2 && pool.size() > MSG_POOL_HIGH) msg_pool_spill(pool);
      return;
    }
    PE_STATS(msg_pool_frees)++;
  }
  delete m;
}

Event* tw_event_new(uint64_t dest_gid, Time offset, LPBase* sender, size_t size) {
  RemoteEvent* msg = remote_event_new(size);
  msg->type_id = get_msg_id<void*>();
  msg->type_size = size;
  return event_alloc(msg, dest_gid, offset, sender);
}

Event* event_alloc() {
  return PE_VALUE(event_buffer)->get_event();
};

Event* event_alloc(RemoteEvent* msg, uint64_t dest_gid, Time offset, LPBase * sender) {
  msg->ts = sender->get_current_time() + offset;
  msg->event_id = sender->owner->get_next_event_id();
  msg->src_lp = sender->gid;
  msg->dest_lp = dest_gid;

  Event* e;
  if (msg->ts >= g_tw_ts_end) {
    e = PE_VALUE(abort_event);
  } else {
    e = event_alloc();
  }

  e->owner = sender;
  e->set_msg(msg);

  return e;
}

static inline uint64_t digest_mix(uint64_t x) {
  // splitmix64's finalizer
  x ^= x >> 30;
  x *= 0xbf58476d1ce4e5b9ULL;
  x ^= x >> 27;
  x *= 0x94d049bb133111ebULL;
  return x ^ (x >> 31);
}

/**
 * --commit-digest: fold a committed event into its LP's hash. Each LP commits
 * in timestamp order, ties in the pending heap's order, so two correct runs
 * give every LP the same hash. Event ids are left out (a rollback renumbers
 * the events it re-creates), and so are payloads (padding bytes may differ);
 * a different random draw changes the timestamps that follow.
 */
static void commit_digest(LPBase* lp, const Event* e) {
  if (g_tw_commit_digest_interval) {
    size_t mark = e->ts / g_tw_commit_digest_interval;
    while (lp->digest_marks.size() < mark) lp->digest_marks.push_back(lp->digest);
  }
  uint64_t h = digest_mix(e->ts) ^ digest_mix(e->src_lp ^ 0x9e3779b97f4a7c15ULL) ^ e->type_id;
  lp->digest = digest_mix(lp->digest * 31 + h);
  lp->digest_count++;
}

/** --commit-log-until: this PE's committed events, written at the end */
struct CommitRecord {
  uint64_t lp, ts, src_lp, event_id, type;
  uint64_t payload[2];  ///< the event's first 16 bytes of data (zero past its size)
};
static thread_local std::vector<CommitRecord> commit_log;

void commit_log_write() {
  if (!g_tw_commit_log_until) return;
  std::string name = "commit_log_" + std::to_string(CkMyPe()) + ".bin";
  FILE* f = fopen(name.c_str(), "wb");
  if (f) {
    fwrite(commit_log.data(), sizeof(CommitRecord), commit_log.size(), f);
    fclose(f);
  }
  commit_log.clear();
  commit_log.shrink_to_fit();
}

/** --event-trace-from/-to */
static thread_local std::vector<EtraceRecord> etrace_log;
static thread_local int etrace_state = 0;  // 0 before the range, 1 open, 2 past it
static thread_local uint64_t etrace_dropped = 0;

void etrace_init() {
  etrace_log.resize(g_tw_etrace_max);
  etrace_log.clear();
}

void etrace_record(uint32_t kind, double wall, Time ts, uint64_t src, uint64_t id,
    uint64_t x, uint64_t y, uint32_t aux) {
  if (etrace_state == 0 && kind <= ET_ROLLBACK) etrace_state = 1;
  if (etrace_log.size() == etrace_log.capacity()) {
    etrace_dropped++;
    return;
  }
  etrace_log.push_back({wall, ts, src, id, x, y, kind, aux});
}

bool etrace_open() { return etrace_state == 1; }

void etrace_pass(double start, double end, bool blocked, unsigned n) {
  if (n == 0 && !etrace_log.empty()) {
    EtraceRecord& r = etrace_log.back();
    if (r.kind == ET_PASS && r.aux == 0 && r.y == (uint64_t)blocked) {
      r.x = (uint64_t)((end - r.wall) * 1e9);
      r.ts++;
      return;
    }
  }
  etrace_record(ET_PASS, start, 1, 0, 0, (uint64_t)((end - start) * 1e9), blocked, n);
}

void etrace_gvt(Time gvt) {
  if (etrace_state != 1) return;
  etrace_record(ET_GVT, CmiWallTimer(), gvt, 0, 0, 0, 0, 0);
  if (gvt > g_tw_etrace_to) etrace_state = 2;
}

void etrace_write() {
  if (!g_tw_etrace_to) return;
  if (etrace_dropped) {
    CkPrintf("PE %d: event trace full, %llu records dropped (--event-trace-max)\n",
        CkMyPe(), (unsigned long long)etrace_dropped);
  }
  std::string name = "event_trace_" + std::to_string(CkMyPe()) + ".bin";
  FILE* f = fopen(name.c_str(), "wb");
  if (f) {
    fwrite(etrace_log.data(), sizeof(EtraceRecord), etrace_log.size(), f);
    fclose(f);
  }
  etrace_log.clear();
  etrace_log.shrink_to_fit();
}

void trace_event(const char* what, const Event* e, long long extra) {
  if (g_tw_trace_lp < 0 || e->dest_lp != (uint64_t)g_tw_trace_lp) return;
  if (e->ts < g_tw_trace_from || e->ts > g_tw_trace_to) return;
  uint32_t p[4] = {0, 0, 0, 0};
  if (e->msg) memcpy(p, e->msg->data, std::min<size_t>(e->type_size, sizeof(p)));
  CkPrintf("TRACE pe %d %s ts %llu src %llu id %llu type %u car %u/%u ptr %p state %d cq %d x %lld\n",
      CkMyPe(), what, (unsigned long long)e->ts, (unsigned long long)e->src_lp,
      (unsigned long long)e->event_id, (unsigned)e->type_id, p[0], p[1], (const void*)e,
      (int)e->state.owner, (int)e->state.cancel_q, extra);
}

void tw_event_free(Event *e, bool commit) {
  if (g_tw_trace_lp >= 0) trace_event(commit ? "commit" : "free", e);
  if(commit == true) {
    if (g_tw_commit_digest) commit_digest(e->owner, e);
    if (g_tw_commit_log_until && e->ts < g_tw_commit_log_until) {
      CommitRecord r = {e->dest_lp, e->ts, e->src_lp, e->event_id, e->type_id, {0, 0}};
      if (e->msg) memcpy(r.payload, e->msg->data, std::min<size_t>(e->type_size, sizeof(r.payload)));
      commit_log.push_back(r);
    }
    e->owner->commit(e);
    PE_STATS(events_committed)++;
  }
  // If we are optimistic, the event may need to be removed from the avl tree,
  // as well as freeing any events caused by it.
  if (g_tw_synchronization_protocol == OPTIMISTIC) {
    if(e->state.avl_tree == 1) {
      e->owner->owner->index_remove(e);
    }

    Event* event = e->caused_by_me;
    while (event) {
      Event* n = event->cause_next;
      // If the owner is not TW_sent, then the event was sent locally and the
      // pointer is still being used by the receiver on this PE. A
      // TW_sent_fast event is the sender's record only; its receiver owns
      // the message.
      if(event->state.owner == TW_sent || event->state.owner == TW_sent_fast) {
        tw_event_free(event, false);
      }
      event = n;
    }
  }

  remote_event_delete(e->msg);
  e->msg = NULL;
  PE_VALUE(event_buffer)->free_event(e);
}

/** Send a remote event: through htram when aggregating, else on its own */
static void send_remote(RemoteEvent* msg, uint64_t dest_chare) {
  if (agg_send(msg, dest_chare)) return;
  if (g_tw_comm_stats) {
    int64_t t0 = comm_send_begin(msg);
    lps(dest_chare).recv_remote_event(msg);
    comm_send_end(t0);
  } else {
    lps(dest_chare).recv_remote_event(msg);
  }
}

void tw_event_send(Event* e) {
  Scheduler* scheduler = CpvAccess(g_scheduler);
  if (e == PE_VALUE(abort_event)) {
    TW_ASSERT(e->ts >= g_tw_ts_end, "Can't send abort event before end\n");
    return;
  }
  TW_ASSERT(g_tw_synchronization_protocol != CONSERVATIVE ||
            e->ts - e->owner->get_current_time() >= g_tw_lookahead,
            "Lookahead violation: try decreasing the lookahead value");

  link_causality(e, e->owner->get_current_event());
  if (etrace_ts(e->ts)) {
    const Event* p = e->owner->get_current_event();
    etrace_record(ET_SEND, CmiWallTimer(), e->ts, e->src_lp, e->event_id,
        p ? p->src_lp : ~0ULL, p ? p->event_id : ~0ULL, (uint32_t)e->dest_lp);
  }

  uint64_t dest_chare_id = g_lp_mapper->get_chare_id(e->dest_lp);
  LPChare* send_chare = (e->owner)->owner;
  LPChare* dest_chare;
  if (dest_chare_id == send_chare->thisIndex) {
    dest_chare = send_chare;
  } else {
    dest_chare = NULL;
  }

  // --gvt-trace=5: the send's parts (exec_parts_<pe>.csv)
  const bool t5 = g_tw_gvt_trace >= 5;
  const double ts0 = t5 ? CmiWallTimer() : 0;
  if (dest_chare != NULL) {
    // Check if an LP is sending to an LP other than itself (for stats).
    if (e->dest_lp == e->src_lp) {
      PE_STATS(self_sends)++;
    } else {
      PE_STATS(local_sends)++;
    }
    dest_chare->recv_local_event(e);
    if (t5) {
      g_wave_timers.local += CmiWallTimer() - ts0;
      g_wave_timers.local_n++;
    }
  } else {
    PE_STATS(remote_sends)++;
    Time delay = e->ts - e->owner->get_current_time();
    ctl_record_delay(delay);
    RemoteEvent* msg = e->get_msg();
    Time window = PE_VALUE(window);
    msg->far = window && delay >= window;
    // The bucketed GVT may hold the event back and send it later
    // (charm_event_release) or delete it with its anti-message.
    const double ts1 = t5 ? CmiWallTimer() : 0;
    bool send_now = scheduler->produce(msg);
    if (t5) g_wave_timers.produce += CmiWallTimer() - ts1;
    e->offset = msg->offset;
    bool fast = false;
    if (send_now) {
      // A chare in this process gets the message by pointer (--local-fast-path)
      const double ts2 = t5 ? CmiWallTimer() : 0;
      // --comm-stats: stamped before the push, after which the receiver owns
      // msg; an event that does not take the fast path is stamped again
      if (g_tw_comm_stats) comm_send_begin(msg);
      fast = fp_send(msg, dest_chare_id);
      const double ts3 = t5 ? CmiWallTimer() : 0;
      if (fast) {
        e->peer = msg;
      } else {
        send_remote(msg, dest_chare_id);
      }
      if (t5) {
        const double ts4 = CmiWallTimer();
        if (fast) {
          g_wave_timers.fp += ts3 - ts2;
          g_wave_timers.fp_n++;
        } else {
          g_wave_timers.fp_miss += ts3 - ts2;
          g_wave_timers.remote += ts4 - ts3;
          g_wave_timers.remote_n++;
        }
      }
    }
    e->msg = NULL;
    if (g_tw_synchronization_protocol == OPTIMISTIC) {
      e->state.owner = fast ? TW_sent_fast : TW_sent;
    } else {
      tw_event_free(e, false);
    }
    if (t5) g_wave_timers.send_total += CmiWallTimer() - ts0;
  }
}

void charm_event_release(RemoteEvent* e) {
  send_remote(e, g_lp_mapper->get_chare_id(e->dest_lp));
}

void tw_event_rollback(Event * event) {
  Event* e = event->caused_by_me;
  LPBase* dest_lp = event->owner;
  if (g_tw_trace_lp >= 0) trace_event("rollback", event);
  if (etrace_ts(event->ts)) {
    etrace_record(ET_ROLLBACK, CmiWallTimer(), event->ts, event->src_lp,
        event->event_id, 0, 0, (uint32_t)event->dest_lp);
  }

  dest_lp->set_current_event(event);
  dest_lp->reverse(event);

  while (e) {
    Event *n = e->cause_next;
    e->cause_next = NULL;

    charm_event_cancel(e);
    e = n;
  }

  event->caused_by_me = NULL;

  PE_STATS(events_rolled_back)++;
}

// Allocate a new remote message, fill it based on e, and send it.
// An anti send will never be to a local chare, because locally sent events
// will never have the owner set to TW_sent.
void charm_anti_send(unsigned dest_chare_id, Event* e) {
  Scheduler* scheduler = CpvAccess(g_scheduler);
  RemoteEvent* eventMsg = new (0) RemoteEvent();
  eventMsg->event_id = e->event_id;
  eventMsg->ts = e->ts;
  eventMsg->dest_lp = e->dest_lp;
  eventMsg->src_lp = e->src_lp;
  eventMsg->anti = true;
  eventMsg->offset = e->offset;

  PE_STATS(anti_sends)++;
  // False when the original was still held: both were deleted unsent
  if (scheduler->produce(eventMsg)) {
    if (g_tw_comm_stats) {
      int64_t t0 = comm_send_begin(eventMsg);
      lps(dest_chare_id).recv_anti_event(eventMsg);
      comm_send_end(t0);
    } else {
      lps(dest_chare_id).recv_anti_event(eventMsg);
    }
  }
}

// Cancels an event by either sending an anti-message, or calling cancel_event
// on the local LP chare.
void charm_event_cancel(Event * e) {
  // Already in cancel q, return
  if(e->state.cancel_q) {
    return;
  }

  // Sent by pointer: an anti-message by pointer, then free the local record
  if(e->state.owner == TW_sent_fast) {
    fp_send_anti(e);
    tw_event_free(e,false);
    return;
  }

  // If already sent, have charm send an anti message, and free the local event
  if(e->state.owner == TW_sent) {
    charm_anti_send(g_lp_mapper->get_chare_id(e->dest_lp), e);
    tw_event_free(e,false);
    return;
  }

  // If is local, then the LP can cancel it
  e->owner->owner->cancel_event(e);
}

#include "event.def.h"
