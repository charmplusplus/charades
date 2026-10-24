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

static size_t remote_event_capacity(RemoteEvent* m) {
  envelope* env = UsrToEnv(m);
  size_t head = (size_t)(m->data - (char*)env);
  size_t total = env->getTotalsize();
  return total > head ? total - head : 0;
}

RemoteEvent* remote_event_new(size_t size) {
  if (g_tw_msg_pool && size <= MSG_POOL_DATA) {
    std::vector<RemoteEvent*>& pool = PE_VALUE(msg_pool);
    if (!pool.empty()) {
      RemoteEvent* m = pool.back();
      pool.pop_back();
      m->clear();
      // It may have been received: sending it again needs it marked unused
      _SET_USED(UsrToEnv(m), 0);
      return m;
    }
    return new (MSG_POOL_DATA) RemoteEvent();
  }
  return new (size) RemoteEvent();
}

void remote_event_delete(RemoteEvent* m) {
  if (m == NULL) return;
  if (g_tw_msg_pool) {
    std::vector<RemoteEvent*>& pool = PE_VALUE(msg_pool);
    if (pool.size() < MSG_POOL_MAX && remote_event_capacity(m) >= MSG_POOL_DATA) {
      pool.push_back(m);
      return;
    }
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

void tw_event_free(Event *e, bool commit) {
  if(commit == true) {
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

  uint64_t dest_chare_id = g_lp_mapper->get_chare_id(e->dest_lp);
  LPChare* send_chare = (e->owner)->owner;
  LPChare* dest_chare;
  if (dest_chare_id == send_chare->thisIndex) {
    dest_chare = send_chare;
  } else {
    dest_chare = NULL;
  }

  if (dest_chare != NULL) {
    // Check if an LP is sending to an LP other than itself (for stats).
    if (e->dest_lp == e->src_lp) {
      PE_STATS(self_sends)++;
    } else {
      PE_STATS(local_sends)++;
    }
    dest_chare->recv_local_event(e);
  } else {
    PE_STATS(remote_sends)++;
    Time delay = e->ts - e->owner->get_current_time();
    ctl_record_delay(delay);
    RemoteEvent* msg = e->get_msg();
    Time window = PE_VALUE(window);
    msg->far = window && delay >= window;
    // The bucketed GVT may hold the event back and send it later
    // (charm_event_release) or delete it with its anti-message.
    bool send_now = scheduler->produce(msg);
    e->offset = msg->offset;
    bool fast = false;
    if (send_now) {
      // A chare in this process gets the message by pointer (--local-fast-path)
      fast = fp_send(msg, dest_chare_id);
      if (fast) {
        e->peer = msg;
      } else {
        send_remote(msg, dest_chare_id);
      }
    }
    e->msg = NULL;
    if (g_tw_synchronization_protocol == OPTIMISTIC) {
      e->state.owner = fast ? TW_sent_fast : TW_sent;
    } else {
      tw_event_free(e, false);
    }
  }
}

void charm_event_release(RemoteEvent* e) {
  send_remote(e, g_lp_mapper->get_chare_id(e->dest_lp));
}

void tw_event_rollback(Event * event) {
  Event* e = event->caused_by_me;
  LPBase* dest_lp = event->owner;

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
