/**
 * \file aggregation.h
 * Remote events through htram (--aggregation=1).
 *
 * An aggregated event is counted as produced when it enters htram and as
 * consumed when htram delivers it, exactly as a direct send is, so GVT
 * algorithms that count events in transit (bucketed, CD) stay correct with
 * events waiting in buffers; what they need is that the waiting ends, which
 * the flushes below guarantee. A blocking GVT (synchronous) waits for
 * quiescence, which does not see buffered events, so every PE flushes before
 * it joins a round. Anti-messages and GVT control traffic never go through
 * htram; an anti-message that overtakes its event is already handled by the
 * receiver.
 *
 * Without an htram build (HTRAM_DIR unset in config.mk) agg_create() aborts
 * and the rest are no-ops.
 */

#ifndef AGGREGATION_H_
#define AGGREGATION_H_

#include <charm++.h>
#include <cstdint>

class RemoteEvent;
class Statistics;

/** PE 0: create htram and the per-PE aggregators, then invoke done */
void agg_create(CkCallback done);

/**
 * Send a remote event through htram, taking ownership of msg. Returns false,
 * leaving msg to the caller, if the event must be sent directly: aggregation
 * is off, its payload does not fit htram's slot, or it is out of scope.
 */
bool agg_send(RemoteEvent* msg, uint64_t dest_chare);

/** This PE has nothing it may execute: ship what it has buffered */
void agg_flush_idle();
/** GVT moved: ship per --agg-gvt-flush */
void agg_flush_gvt();
/** Ship everything this PE has buffered (before a blocking GVT round) */
void agg_flush_all();

/** Copy htram's message and byte counts for this PE into s */
void agg_collect_stats(Statistics* s);

#endif
