include ../config.mk ../htram.mk

C_FILES=$(wildcard *.C)
CPP_FILES=$(wildcard *.cpp)
CI_FILES=$(wildcard *.ci)
MODULES=$(CI_FILES:.ci=.decl.h)
OBJS=$(addprefix $(BUILD_DIR)/, $(C_FILES:.C=.o) $(CPP_FILES:.cpp=.o))

# The compiler writes each object's header dependencies to a .d file next to
# it, so editing any header (including one in another directory, or a
# generated .decl.h) rebuilds exactly the objects that include it.
DEPFLAGS = -MMD -MP

default: all
all: $(BUILD_DIR) $(OBJS)

$(BUILD_DIR):
	mkdir $(BUILD_DIR)

make_ci: $(MODULES)

%.decl.h: %.ci ../config.mk ../htram.mk
	$(CHARMC) $(CIFLAGS) $<

$(BUILD_DIR)/%.o: %.C $(MODULES) ../config.mk ../htram.mk
	$(CHARMC) $(CFLAGS) $(DEPFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: %.cpp $(MODULES) ../config.mk ../htram.mk
	$(CHARMC) $(CFLAGS) $(DEPFLAGS) -c $< -o $@

clean:
	rm -rf *.decl.h *.def.h $(OBJS) $(OBJS:.o=.d)

-include $(OBJS:.o=.d)
