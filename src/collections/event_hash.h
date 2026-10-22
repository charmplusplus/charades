#ifndef EVENT_HASH_H
#define EVENT_HASH_H

#include "event.h"
#include "util.h"

#include <cstdint>
#include <cstdlib>
#include <cstring>

/**
 * Open-addressing hash set of events keyed by (ts, event_id, src_lp): the
 * optimistic index that matches an anti-message to its event, replacing the
 * AVL tree (--event-index=1). Same contract: insert_or_remove() inserts, or,
 * if an event with the same key is already there (its anti-message arrived
 * first, or this is the anti-message), removes and returns that one instead.
 *
 * Every remote event received goes in and comes out again when it is
 * committed or cancelled, so this sits on the per-event path: one hash and a
 * short linear probe, against ~log2(n) pointer chases plus rebalancing.
 * Linear probing with tombstones; grows at 50% occupancy (live + tombstones).
 */
class EventHash {
  public:
    EventHash() : slots(nullptr), mask(0), live(0), used(0) {}
    ~EventHash() { free(slots); }
    EventHash(const EventHash&) = delete;
    EventHash& operator=(const EventHash&) = delete;

    /** Insert e, or remove and return the event with e's key if there is one */
    Event* insert_or_remove(Event* e) {
      if (2 * (used + 1) > capacity()) grow();
      uint64_t i = hash(e) & mask;
      int64_t tomb = -1;
      for (;;) {
        Event* s = slots[i];
        if (s == EMPTY) break;
        if (s == TOMB) {
          if (tomb < 0) tomb = (int64_t)i;
        } else if (same_key(s, e)) {
          slots[i] = TOMB;
          live--;
          s->state.avl_tree = 0;
          return s;
        }
        i = (i + 1) & mask;
      }
      if (tomb >= 0) {
        slots[tomb] = e;
      } else {
        slots[i] = e;
        used++;
      }
      live++;
      e->state.avl_tree = 1;
      return nullptr;
    }

    /** Insert e (re-indexing after migration); its key must not be present */
    void insert(Event* e) {
      Event* found = insert_or_remove(e);
      TW_ASSERT(found == nullptr, "EventHash: duplicate key on insert\n");
    }

    /** Remove e itself, which must be in the set */
    void remove(Event* e) {
      TW_ASSERT(slots != nullptr, "EventHash: remove from an empty set\n");
      uint64_t i = hash(e) & mask;
      for (;;) {
        Event* s = slots[i];
        TW_ASSERT(s != EMPTY, "EventHash: removed event is not in the set\n");
        if (s == e) {
          slots[i] = TOMB;
          live--;
          e->state.avl_tree = 0;
          return;
        }
        i = (i + 1) & mask;
      }
    }

    uint64_t size() const { return live; }

  private:
    static constexpr Event* EMPTY = nullptr;
    static inline Event* const TOMB = reinterpret_cast<Event*>(uintptr_t(1));

    Event** slots;
    uint64_t mask;   ///< capacity - 1; capacity is a power of two (or 0)
    uint64_t live;   ///< events in the set
    uint64_t used;   ///< live + tombstones

    uint64_t capacity() const { return slots ? mask + 1 : 0; }

    static bool same_key(const Event* a, const Event* b) {
      return a->event_id == b->event_id && a->src_lp == b->src_lp &&
             a->ts == b->ts;
    }

    static uint64_t hash(const Event* e) {
      // event_id is a per-chare counter and src_lp a global id, so their mix
      // alone is unique; ts is in the key only to match the AVL tree exactly
      uint64_t h = e->event_id * 0x9E3779B97F4A7C15ULL;
      h ^= (e->src_lp + 0x632BE59BD9B4E019ULL) * 0xC2B2AE3D27D4EB4FULL;
      h ^= h >> 29;
      h *= 0xBF58476D1CE4E5B9ULL;
      h ^= h >> 32;
      return h;
    }

    void grow() {
      uint64_t old_cap = capacity();
      Event** old = slots;
      // Double when mostly live; rehash in place (same size) when tombstones
      // made up the load
      uint64_t cap = old_cap == 0 ? 64 : (2 * (live + 1) > old_cap / 2 ? 2 * old_cap : old_cap);
      slots = (Event**)calloc(cap, sizeof(Event*));
      TW_ASSERT(slots != nullptr, "EventHash: out of memory\n");
      mask = cap - 1;
      live = used = 0;
      for (uint64_t j = 0; j < old_cap; j++) {
        Event* s = old[j];
        if (s == EMPTY || s == TOMB) continue;
        uint64_t i = hash(s) & mask;
        while (slots[i] != EMPTY) i = (i + 1) & mask;
        slots[i] = s;
        live++;
        used++;
      }
      free(old);
    }
};

#endif
