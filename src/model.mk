# Rules shared by the model Makefiles. Include this after the model's own
# targets, so that its first target stays the default.

# Models see htram's generated headers too (setup's extern module aggregation)
include $(CHARADES_SRC)/htram.mk

# Compile each model source on its own, writing its header dependencies
# (framework headers, generated .decl.h files, the model's own headers) to a
# .d file, so that editing any of them rebuilds the model. The library is
# order-only: it must be built first, since that generates the framework's
# .decl.h files, but rebuilding it does not by itself recompile the model.
%.o: %.C $(CHARADES_SRC)/config.mk $(CHARADES_SRC)/htram.mk | $(BUILD_DIR)/libcharades.a
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

# Always bring the framework up to date first: otherwise editing a header in
# src/ and running make here would link against a stale libcharades.a. The
# library is only rewritten when one of its objects changed, so this does not
# force a relink when nothing did.
$(BUILD_DIR)/libcharades.a: FORCE
	$(MAKE) -C $(CHARADES_SRC)

.PHONY: FORCE
FORCE:

-include $(wildcard *.d)
