include ../../../src/config.mk

ifneq ($(USE_CHARMC),1)
include ../../../src/charmc_flags.mk
CC=$(CHARM_CXX)
CFLAGS += $(CHARM_CXX_FLAGS)
LFLAGS += $(CHARM_LDXX_FLAGS)
else
CC=$(CHARMC)
endif

all: phold
clean:
	rm -f phold charmrun
	rm -f *.o *.d *~ core*
	rm -f output ross.csv


phold: phold.o $(BUILD_DIR)/libcharades.a
	$(CC) $(CFLAGS) $(LFLAGS) phold.o -o phold -L$(BUILD_DIR) -lcharades

include ../../../src/model.mk
