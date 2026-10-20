# Optional event aggregation through htram (simcore/aggregation.h). Set
# HTRAM_DIR in config.mk to an htram checkout on its pdes branch; leave it
# unset to build without (then --aggregation=1 aborts). Charades compiles
# htram_group.C itself, with the same HTRAM_FLAGS as aggregation.C, because
# the item layout is fixed at compile time and both sides must agree on it.
# PDES_TIMED adds a send timestamp to each item, for --comm-stats latencies.
# PDES_PAYLOAD_BYTES is the largest event payload htram carries (larger ones
# are sent directly): 24 fits Imbalanced PHOLD and traffic (16 did not).
ifneq ($(HTRAM_DIR),)
HTRAM_FLAGS ?= -DPDES -DBUCKETS_BY_DEST -DPDES_TIMED -DPDES_PAYLOAD_BYTES=24
CFLAGS  += -DCHARADES_HTRAM $(HTRAM_FLAGS) -I$(HTRAM_DIR)
CIFLAGS += -DCHARADES_HTRAM
HTRAM_DECL = $(HTRAM_DIR)/htram_group.decl.h
HTRAM_OBJ  = $(BUILD_DIR)/htram/htram_group.o
endif
