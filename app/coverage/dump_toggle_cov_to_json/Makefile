# Default target
.DEFAULT_GOAL := run

# Compiler settings
CXX       := c++
CXXFLAGS  := -g
CFLAGS    := -m64

# Detect platform
plat      := $(shell vcs -platform)

ifeq ($(plat),linux)
  CFLAGS := -m32
endif
ifeq ($(plat),suse32)
  CFLAGS := -m32
endif
ifeq ($(plat),sparcOS5)
  CFLAGS := -m32
endif
ifeq ($(plat),solarisx86)
  CFLAGS := -m32
endif

# Library paths
LD_LIBRARY_PATH ?= $(VCS_HOME)/$(plat)/lib

# Executables
PGM        := dumptgl
BUILD_DIR  := build
SRC_DIR    := src

# Design parameters (overridable)
DESIGN_FILE ?= designs/jukebox.v
MODULE_NAME ?= station

# UCAPI library/include detection
ifneq ($(wildcard $(VCS_HOME)/$(plat)/lib/libucapi.a),)
  LIB := $(VCS_HOME)/$(plat)/lib/libucapi.so
  INC := $(VCS_HOME)/include
else
  LIB := $(VCS_HOME)/lib/libucapi.so
  INC := $(VCS_HOME)/coverage/ucapi/include
endif

# Sources & objects
VISIT_SRC  := $(SRC_DIR)/visit.cc
VISIT_HDR  := $(SRC_DIR)/visit.hh
VISIT_OBJ  := $(BUILD_DIR)/visit.o
PGM_SRC    := $(SRC_DIR)/$(PGM).cpp
PGM_BIN    := $(BUILD_DIR)/$(PGM)

# Build rules
$(PGM_BIN): $(PGM_SRC) $(VISIT_OBJ) | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -I$(INC) -o $@ $^ -ldl -lm -lpthread $(LIB) $(CFLAGS)

$(VISIT_OBJ): $(VISIT_SRC) $(VISIT_HDR) | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -I$(INC) -c $< -o $@ $(CFLAGS)

$(BUILD_DIR):
	mkdir -p $@

# Simulation + coverage run
.PHONY: run

run: $(PGM_BIN)
	@echo ">>> Running simulation with design: $(DESIGN_FILE), module: $(MODULE_NAME)"
	rm -rf $(BUILD_DIR)/simv* $(BUILD_DIR)/csrc $(BUILD_DIR)/*.log $(BUILD_DIR)/*.vdb $(BUILD_DIR)/html
	mkdir -p $(BUILD_DIR)
	vcs -cm tgl -sverilog $(DESIGN_FILE) \
	    -l $(BUILD_DIR)/compile.log \
	    -o $(BUILD_DIR)/simv \
	    -Mdir=$(BUILD_DIR)/csrc \
	    -cm_log $(BUILD_DIR)/cm.log
	./$(BUILD_DIR)/simv -cm tgl -l $(BUILD_DIR)/run.log
	[ -f ucli.key ] && mv ucli.key $(BUILD_DIR)/ || true
	./$(PGM_BIN) $(BUILD_DIR)/simv.vdb $(MODULE_NAME) > $(BUILD_DIR)/toggle_report.json

# Generate HTML coverage report
.PHONY: html
html:
	@echo ">>> Generating HTML coverage report using urg..."
	mkdir -p $(BUILD_DIR)/html
	urg -dir $(BUILD_DIR)/simv.vdb -report $(BUILD_DIR)/html -format both -full64
	@echo ">>> HTML report available in $(BUILD_DIR)/html"

# Cleanup
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)

# Help
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  run                   - Run with default design (jukebox.v, station module)"
	@echo "  run DESIGN_FILE=... MODULE_NAME=... - Run with custom params"
	@echo "  html                  - Generate HTML coverage report"
	@echo "  clean                 - Clean build directory"
	@echo ""
	@echo "Examples:"
	@echo "  make run DESIGN_FILE=designs/jukebox.v MODULE_NAME=station"
	@echo "  make run DESIGN_FILE=designs/soc_register_hierarchy.sv MODULE_NAME=tb_toggle_coverage"
	@echo "  make run MODULE_NAME=testbench"
