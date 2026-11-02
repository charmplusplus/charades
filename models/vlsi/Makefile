include ../../src/config.mk

# -module is a charmc option, so the model always builds with charmc.
CC=$(CHARMC)

OBJS = vlsi.o gate.o netlist.o
# The statistics group is a Charm++ module, linked with -module
STATS_LIB = libmodulevlsi_stats.a

all: vlsi
clean:
	rm -f vlsi charmrun $(STATS_LIB)
	rm -f *.o *.d *~ core* *.decl.h *.def.h
	rm -f output ross.csv

vlsi_stats.decl.h: vlsi_stats.ci
	$(CHARMC) $<

stats.o: vlsi_stats.decl.h

$(STATS_LIB): stats.o
	$(CHARMC) stats.o -o $@

vlsi: $(OBJS) $(STATS_LIB) $(BUILD_DIR)/libcharades.a
	$(CHARMC) $(CFLAGS) $(OPTIONS) $(OPTS) $(OBJS) -o vlsi $(LDFLAGS) -L. -module vlsi_stats -L$(BUILD_DIR) -lcharades

include ../../src/model.mk
