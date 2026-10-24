/**
 * \file fastpath.h
 * Same-process events by pointer (--local-fast-path).
 *
 * An event for a chare on another PE of this process, or on another chare of
 * this PE, skips htram and Charm++ messages: its message is pushed onto the
 * destination PE's inbox (a lock-free list for other PEs, a plain vector for
 * this one), and the destination drains its inbox at the start of every
 * scheduler iteration. The receiver indexes nothing: an anti-message names
 * the event's message directly, and one sender's pushes arrive in order, so
 * the event always arrives first. The message stays alive until the
 * anti-message arrives or the event commits, and an event whose sender can
 * still roll back the event that sent it is not below GVT.
 *
 * GVT counting is unchanged: an event is counted sent at produce() and
 * received when drained, so one waiting in an inbox is in transit. As with
 * --agg-inbox, only where nothing waits on quiescence and every PE keeps
 * iterating: the bucketed GVT, the optimistic scheduler, not --sched-park.
 */

#ifndef FASTPATH_H_
#define FASTPATH_H_

#include <cstdint>

class Event;
class RemoteEvent;

/** Abort unless the run's settings allow --local-fast-path (PE 0, startup) */
void fp_check();
/**
 * Hand msg to its chare by pointer if that chare is in this process (and
 * not the sender's own chare, which never gets here). Returns false, leaving
 * msg to the caller, if the fast path is off or the chare is elsewhere.
 */
bool fp_send(RemoteEvent* msg, uint64_t dest_chare);
/** Cancel e, a TW_sent_fast event, with an anti-message by pointer */
void fp_send_anti(Event* e);
/** Deliver everything waiting in this PE's inboxes */
void fp_drain();

#endif
