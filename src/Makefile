include config.mk
include htram.mk

C_FILES=$(wildcard *.C)
CI_FILES=$(wildcard *.ci)
MODULES=$(CI_FILES:.ci=.decl.h)
OBJS=$(addprefix $(BUILD_DIR)/, $(C_FILES:.C=.o))

# Header dependencies, as in module.mk.
DEPFLAGS = -MMD -MP

default: all
all: $(BUILD_DIR) $(BUILD_DIR)/libcharades.a charmc_flags.mk

.PHONY : $(SUB_DIRS)

$(BUILD_DIR):
	mkdir $(BUILD_DIR)


# The subdirectories are phony, so this rule always runs; rewrite the archive
# only when it is missing or an object is newer, so that models relink only
# when the framework changed.
$(BUILD_DIR)/libcharades.a: make_ci $(OBJS) $(SUB_DIRS) $(HTRAM_OBJ)
	if [ ! -f $@ ] || [ -n "$$(find $(BUILD_DIR) -name '*.o' -newer $@)" ]; then \
	  rm -f $@; $(CHARMC) $(LFLAGS) $(BUILD_DIR)/*.o $(HTRAM_OBJ) -o $@; fi
	# Reconverse has no charmrun; its executables take +pe directly.
	if [ -f $(CHARM_DIR)/bin/charmrun ]; then cp $(CHARM_DIR)/bin/charmrun $(BUILD_DIR); fi

charmc_flags.mk:
ifneq ($(USE_CHARMC),1)
	$(CHARMC) -print-building-blocks | sed "s/'//g" > charmc_flags.mk
endif

make_ci: $(MODULES) $(HTRAM_DECL)
	for dir in $(SUB_DIRS); do make -C $${dir} make_ci; done

$(SUB_DIRS):
	make -C $@

%.decl.h: %.ci
	$(CHARMC) $<

$(BUILD_DIR)/%.o: %.C $(MODULES) config.mk
	$(CHARMC) $(CFLAGS) $(DEPFLAGS) -c $< -o $@

ifneq ($(HTRAM_DIR),)
$(HTRAM_DECL): $(HTRAM_DIR)/htram_group.ci
	cd $(HTRAM_DIR) && $(CHARMC) $(HTRAM_FLAGS) htram_group.ci

$(HTRAM_OBJ): $(HTRAM_DIR)/htram_group.C $(HTRAM_DECL) config.mk
	mkdir -p $(dir $@)
	$(CHARMC) -O3 -std=c++17 $(HTRAM_FLAGS) -I$(HTRAM_DIR) $(DEPFLAGS) -c $< -o $@

-include $(HTRAM_OBJ:.o=.d)
endif

clean:
	rm -rf *.decl.h *.def.h $(OBJS) $(OBJS:.o=.d) $(BUILD_DIR)/libcharades.a charmc_flags.mk $(BUILD_DIR)/htram
	for dir in $(SUB_DIRS); do make -C $${dir} clean; done

-include $(OBJS:.o=.d)
