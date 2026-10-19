#ifndef PHOLD_H_
#define PHOLD_H_

#include "charades.h"

// Global configuration variables
static uint8_t start_events = 1;
static double percent_remote = 0.1;
static Time mean = 1000;
// If > 0, every event goes to an LP drawn from a normal distribution with
// this standard deviation (in LP ids, wrapping around) centred on the sender,
// and percent_remote is ignored: the Gaussian PHOLD of Bachan et al.,
// PADS'24 (Devastator), where sigma sets how much traffic leaves a node.
static double sigma = 0;

// Message and LP type declarations
class PHoldMessage {};

class PHoldLP : public LP<PHoldLP, PHoldMessage> {
private:
public:
  PHoldLP() {}
  void initialize();
  void forward(PHoldMessage* msg, tw_bf* bf);
  void reverse(PHoldMessage* msg, tw_bf* bf);
  void commit(PHoldMessage* msg, tw_bf* bf);
  void finalize();
};

#endif
