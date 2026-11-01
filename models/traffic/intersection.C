#include "intersection.h"

IntersectionLP::IntersectionLP(uint32_t cars)
    : initial_cars(cars), total_cars_arrived(0), total_cars_finished(0) {
  for (int i = 0; i < 4; i++) {
    in_lane[i] = out_lane[i] = 0;
  }
}

/** Signed shortest step from a to b on a ring of n (the grid is a torus) */
static inline int64_t ring_delta(uint32_t a, uint32_t b, uint32_t n) {
  int64_t d = ((int64_t)b - a + n) % n;
  return d <= (int64_t)n / 2 ? d : d - n;
}

/**
 * --trip-radius R: a destination within R of (x, y) in x and y, wrapping
 * around the torus, never (x, y) itself: one draw over the (2R + 1)^2 - 1
 * other cells of the square. R is below half the grid, so no two offsets
 * reach the same cell and every trip is at most 2R steps.
 */
void IntersectionLP::near_destination(uint32_t x, uint32_t y, Car* car) {
  int64_t R = g_trip_radius, w = 2 * R + 1, centre = (w * w) / 2;
  int64_t k = tw_rand_integer(rng, 0, w * w - 2);
  if (k >= centre) k++;
  car->dest_x = (uint32_t)(((int64_t)x + k % w - R + g_num_x) % g_num_x);
  car->dest_y = (uint32_t)(((int64_t)y + k / w - R + g_num_y) % g_num_y);
}

void IntersectionLP::initialize() {
  this_x = gid % g_num_x;
  this_y = gid / g_num_x;

  neighbors[NORTH] = ((this_y - 1 + g_num_y) % g_num_y) * g_num_x + this_x;
  neighbors[SOUTH] = ((this_y + 1) % g_num_y) * g_num_x + this_x;
  neighbors[EAST] = this_y * g_num_x + ((this_x + 1) % g_num_x);
  neighbors[WEST] = this_y * g_num_x + ((this_x - 1 + g_num_x) % g_num_x);

  for (int i = 0; i < initial_cars; i++) {
    Time offset = g_tw_lookahead + tw_rand_exponential(rng, mean);
    Event* e = tw_event_new<ArrivalMsg>(gid, offset, this);
    ArrivalMsg* msg = e->get_data<ArrivalMsg>();
    msg->car.src = gid;
    msg->car.id = i;
    msg->car.current_lane = tw_rand_integer(rng, 0, 3);

    if (g_trip_radius) {
      near_destination(this_x, this_y, &msg->car);
    } else if (g_percent_end > tw_rand_unif(rng)) {
      msg->car.dest_x = tw_rand_integer(rng, 0, g_end_size-1) + g_end_x;
      msg->car.dest_y = tw_rand_integer(rng, 0, g_end_size-1) + g_end_y;
    } else {
      msg->car.dest_x = tw_rand_integer(rng, 0, g_num_x-1);
      msg->car.dest_y = tw_rand_integer(rng, 0, g_num_y-1);
    }

    tw_event_send(e);
  }
}
void IntersectionLP::finalize() {
#ifdef PRINT
  CkPrintf("Total cars finished at (%i,%i): %i\n", this_x, this_y, total_cars_finished);
#endif
}

void IntersectionLP::forward(ArrivalMsg* msg, tw_bf* bf) {
  bool here = this_x == msg->car.dest_x && this_y == msg->car.dest_y;
  if (here && !g_trip_radius) {
    total_cars_finished++;
  } else {
    // --trip-radius: a car at its destination starts its next trip here
    Car car = msg->car;
    bf->c2 = here;
    if (here) {
      total_cars_finished++;
      near_destination(this_x, this_y, &car);
    }
    uint8_t new_lane = (car.current_lane + 2) % 4;
    Time offset = g_tw_lookahead + tw_rand_exponential(rng, mean);
    Event* e = tw_event_new<DirectionMsg>(gid, offset, this);
    DirectionMsg* new_msg = e->get_data<DirectionMsg>();
    new_msg->car = car;
    new_msg->car.current_lane = new_lane;
    tw_event_send(e);

    total_cars_arrived++;
    in_lane[new_lane]++;
  }
}

void IntersectionLP::reverse(ArrivalMsg* msg, tw_bf* bf) {
  if (this_x == msg->car.dest_x && this_y == msg->car.dest_y && !g_trip_radius) {
    total_cars_finished--;
  } else {
    uint8_t new_lane = (msg->car.current_lane + 2) % 4;
    rng.prev();
    if (bf->c2) {  // the next trip's destination
      rng.prev();
      total_cars_finished--;
    }
    total_cars_arrived--;
    in_lane[new_lane]--;
  }
}

void IntersectionLP::commit(ArrivalMsg* msg, tw_bf* bf) {}

void IntersectionLP::forward(DepartureMsg* msg, tw_bf* bf) {
  uint64_t destination = neighbors[msg->car.current_lane];
  Time offset = g_tw_lookahead + tw_rand_exponential(rng, mean);
  Event* e = tw_event_new<ArrivalMsg>(destination, offset, this);
  ArrivalMsg* new_msg = e->get_data<ArrivalMsg>();
  new_msg->car = msg->car;
  tw_event_send(e);

  out_lane[msg->car.current_lane]--;
}

void IntersectionLP::reverse(DepartureMsg* msg, tw_bf* bf) {
  rng.prev();
  out_lane[msg->car.current_lane]++;
}

void IntersectionLP::commit(DepartureMsg* msg, tw_bf* bf) {}

// TODO: Add lane capacity in
// TODO: Add multiple incoming/outgoing lanes
void IntersectionLP::forward(DirectionMsg* msg, tw_bf* bf) {
  uint8_t new_lane, decision;
  if (this_x != msg->car.dest_x && this_y != msg->car.dest_y) {
    // Decide whether to move horizontal or vertically at random
    decision = tw_rand_integer(rng, 0, 1);
  } else if (this_x != msg->car.dest_x) {
    // Move horizontal
    decision = 0;
  } else if (this_y != msg->car.dest_y) {
    // Move vertical
    decision = 1;
  } else {
    // Error
    CkAbort("Choosing a direction from our destination\n");
  }

  // --trip-radius: destinations wrap around the torus, so take the short way
  bool east = g_trip_radius ? ring_delta(this_x, msg->car.dest_x, g_num_x) > 0
                            : this_x < msg->car.dest_x;
  bool south = g_trip_radius ? ring_delta(this_y, msg->car.dest_y, g_num_y) > 0
                             : this_y < msg->car.dest_y;
  if (decision == 0) {
    bf->c0 = 0;
    if (east) {
      bf->c1 = 0;
      new_lane = EAST;
    } else {
      bf->c1 = 1;
      new_lane = WEST;
    }
  } else {
    bf->c0 = 1;
    if (south) {
      bf->c1 = 0;
      new_lane = SOUTH;
    } else {
      bf->c1 = 1;
      new_lane = NORTH;
    }
  }

  Time offset = g_tw_lookahead + tw_rand_exponential(rng, mean);
  Event* e = tw_event_new<DepartureMsg>(gid, offset, this);
  DepartureMsg* new_msg = e->get_data<DepartureMsg>();
  new_msg->car = msg->car;
  new_msg->car.current_lane = new_lane;
  tw_event_send(e);

  in_lane[msg->car.current_lane]--;
  out_lane[new_lane]++;
}

void IntersectionLP::reverse(DirectionMsg* msg, tw_bf* bf) {
  uint8_t new_lane;
  if (this_x != msg->car.dest_x && this_y != msg->car.dest_y) {
    // The decision needed a random number
    rng.prev();
  }
  if (bf->c0 == 0) { // Was a horizontal move
    if (bf->c1 == 0) {
      new_lane = EAST;
    } else {
      new_lane = WEST;
    }
  } else { // Was a vertical move
    if (bf->c1 == 0) {
      new_lane = SOUTH;
    } else {
      new_lane = NORTH;
    }
  }
  rng.prev();
  in_lane[msg->car.current_lane]++;
  out_lane[new_lane]--;
}

void IntersectionLP::commit(DirectionMsg* msg, tw_bf* bf) {}
