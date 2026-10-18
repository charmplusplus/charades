include ../../src/config.mk

# -module is a charmc option, so traffic always builds with charmc.
CC=$(CHARMC)

all: traffic
clean:
	rm -f traffic charmrun
	rm -f *.o *.d *~ core*
	rm -f output ross.csv


traffic: traffic.o intersection.o $(BUILD_DIR)/libcharades.a
	$(CHARMC) $(CFLAGS) $(OPTIONS) $(OPTS) -module CommonLBs traffic.o intersection.o -o traffic $(LDFLAGS) -L$(BUILD_DIR) -lcharades

include ../../src/model.mk
