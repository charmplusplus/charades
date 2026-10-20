#include "phold.h"

void PHoldLP::initialize() {
  for (int i = 0; i < start_events; i++) {
    // Set offset using an exponential distribution, adding stagger if necessary
    Time offset = g_tw_lookahead + mean * tw_rand_exponential(rng, 1.0);

    // Create and send the event.
    Event* e = tw_event_new<PHoldMessage>(gid, offset, this);
    tw_event_send(e);
  }
}

/** Odd phases of a phase-changing run use the alternate parameters */
static bool alt_phase(Time now) {
  return phase_length > 0 && (now / phase_length) % 2 == 1;
}

void PHoldLP::forward(PHoldMessage* msg, tw_bf* bf) {
  bool alt = alt_phase(get_current_time());
  double remote = alt ? alt_remote : percent_remote;
  uint64_t dest = gid;
  if (sigma > 0) {
    // Two uniform draws (tw_rand_normal01); reverse() undoes them
    int64_t n = g_total_lps;
    int64_t step = llround(tw_rand_normal_sd(rng, 0.0, sigma));
    dest = (uint64_t)((((int64_t)gid + step) % n + n) % n);
  } else if(tw_rand_unif(rng) <= remote) {
    bf->c1 = 1;
    dest = tw_rand_integer(rng, 0, g_total_lps - 1);
  }

  Time offset = alt ? alt_lookahead + tw_rand_exponential(rng, alt_mean)
                    : g_tw_lookahead + tw_rand_exponential(rng, mean);
  Event* e = tw_event_new<PHoldMessage>(dest, offset, this);
  tw_event_send(e);
}

void PHoldLP::reverse(PHoldMessage* msg, tw_bf* bf) {
  // We definitely used rng for offset, and for the remote percent or the
  // first of the two Gaussian draws
  rng.prev();
  rng.prev();
  if (sigma > 0) {
    rng.prev();
  }

  // If it was a remote message then we also used rng for the destination
  if(bf->c1 == 1) {
    rng.prev();
  }
}

void PHoldLP::commit(PHoldMessage* msg, tw_bf* bf) {}
void PHoldLP::finalize() {}

// Every LP in the PHOLD model has the same type.
class PHoldLPFactory : public LPFactory {
  public:
    LPBase* create_lp(uint64_t gid) const {
      return new PHoldLP();
    }
};

int main(int argc, char **argv, char **env) {
  ArgumentSet args("PHOLD Model");
  args.register_argument("remote", "desired remote event rate", percent_remote);
  args.register_argument("mean", "exponential distribution mean for timestamps", mean);
  args.register_argument("start-events", "number of initial messages per LP", start_events);
  args.register_argument("sigma", "if > 0: Gaussian destinations with this std. dev. in LP ids (ignores remote)", sigma);
  args.register_argument("phase-length", "if > 0: odd phases of this length (virtual time) use the alt- parameters", phase_length);
  args.register_argument("alt-lookahead", "odd phases: lookahead (at least --lookahead; 0 = --lookahead)", alt_lookahead);
  args.register_argument("alt-mean", "odd phases: mean delay (0 = --mean)", alt_mean);
  args.register_argument("alt-remote", "odd phases: remote event rate (negative = --remote)", alt_remote);
  tw_add_arguments(&args);

  tw_init(argc, argv);

  // Check for a valid configuration and adjust mean
  if (g_tw_lookahead > mean) {
    CkAbort("Lookahead must be less than mean\n");
  }
  mean = mean - g_tw_lookahead;
  if (alt_lookahead == 0) alt_lookahead = g_tw_lookahead;
  if (alt_mean == 0) alt_mean = mean + g_tw_lookahead;
  if (alt_remote < 0) alt_remote = percent_remote;
  // The conservative scheduler relies on --lookahead holding for every event
  if (alt_lookahead < g_tw_lookahead) {
    CkAbort("--alt-lookahead must be at least --lookahead\n");
  }
  if (alt_lookahead > alt_mean) {
    CkAbort("Alt lookahead must be less than alt mean\n");
  }
  alt_mean = alt_mean - alt_lookahead;

  // Register messages and create the simulation
  register_msg_type<PHoldMessage>();

  tw_create_simulation(new PHoldLPFactory());

  if (CkMyPe() == 0) {
    printf("========================================\n");
    printf("PHOLD Model Configuration..............\n");
    printf("   Start events...........%u\n", start_events);
    printf("   Mean...................%llu\n", mean);
    if (sigma > 0) {
      printf("   Sigma..................%lf (Gaussian destinations)\n", sigma);
    } else {
      printf("   Remote.................%lf\n", percent_remote);
    }
    if (phase_length > 0) {
      printf("   Phase length...........%llu (odd phases: lookahead %llu, "
             "mean %llu, remote %lf)\n", (unsigned long long)phase_length,
             (unsigned long long)alt_lookahead,
             (unsigned long long)(alt_mean + alt_lookahead), alt_remote);
    }
    printf("========================================\n\n");
  }

  tw_run();
  tw_end();

  return 0;
}
