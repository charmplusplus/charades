include ../../src/config.mk

# -module is a charmc option, so the model always builds with charmc.
CC=$(CHARMC)

OBJS = dragonfly.o router.o terminal.o
# The statistics group is a Charm++ module, linked with -module
STATS_LIB = libmoduledragonfly_stats.a

all: dragonfly
clean:
	rm -f dragonfly charmrun $(STATS_LIB)
	rm -f *.o *.d *~ core* *.decl.h *.def.h
	rm -f output ross.csv

dragonfly_stats.decl.h: dragonfly_stats.ci
	$(CHARMC) $<

stats.o: dragonfly_stats.decl.h

$(STATS_LIB): stats.o
	$(CHARMC) stats.o -o $@

dragonfly: $(OBJS) $(STATS_LIB) $(BUILD_DIR)/libcharades.a
	$(CHARMC) $(CFLAGS) $(OPTIONS) $(OPTS) $(OBJS) -o dragonfly $(LDFLAGS) -L. -module dragonfly_stats -L$(BUILD_DIR) -lcharades

include ../../src/model.mk
