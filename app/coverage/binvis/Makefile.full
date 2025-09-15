# =============================================================================
# BinVis - Coverage Analysis Tool
# =============================================================================
# A tool for analyzing VCS coverage data and generating JSON output
# 
# Directory Structure:
#   src/          - Source code files
#   examples/     - Example SystemVerilog designs
#   tests/        - Test files and utilities
#   docs/         - Documentation
#   build/        - Build artifacts (generated)
# =============================================================================

# =============================================================================
# Configuration
# =============================================================================

# Default design file (can be overridden from command line)
# DESIGN_FILE ?= examples/covergroup_showcase.sv
DESIGN_NAME = $(basename $(notdir $(DESIGN_FILE)))

# Build directory
BUILD_DIR = build

# Platform detection and compiler flags
CFLAGS := -m64
plat := $(shell vcs -platform 2>/dev/null || echo "linux64")
ifeq ($(plat),linux)
    CFLAGS := -m32
endif
ifeq ($(plat),suse32)
    CFLAGS := -m32
endif

# VCS library and include paths
ifeq ($(wildcard $(LD_LIBRARY_PATH)),) 
    LD_LIBRARY_PATH := $(LD_LIBRARY_PATH):$(VCS_HOME)/${plat}/lib
else 
    LD_LIBRARY_PATH := $(LD_LIBRARY_PATH):$(VCS_HOME)/${plat}/lib 
endif 

ifeq ($(wildcard $(VCS_HOME)/${plat}/lib/libucapi.so),)
    LIB = $(VCS_HOME)/lib/libucapi.so
    INC = $(VCS_HOME)/coverage/ucapi/include
else
    LIB = $(VCS_HOME)/${plat}/lib/libucapi.so
    INC = $(VCS_HOME)/include
endif

# Source files
SRC_DIR = src
VISIT_OBJ = $(BUILD_DIR)/visit.o
BINVIS_SRC = $(SRC_DIR)/binvis.cc
BINVIS_CPP_SRC = $(SRC_DIR)/binvis_cpp.cc
VISIT_SRC = $(SRC_DIR)/visit.cc
VISIT_HDR = $(SRC_DIR)/visit.hh

# Executables
BINVIS = $(BUILD_DIR)/binvis
BINVIS_CPP = $(BUILD_DIR)/binvis_cpp

# Simulation artifacts (all in build directory)
SIMV = $(BUILD_DIR)/simv
VDB = $(BUILD_DIR)/simv.vdb
SIM_LOG = $(BUILD_DIR)/sim.log

# Output files
OUTPUT_LOG = $(BUILD_DIR)/binvis.log
OUTPUT_CPP_LOG = $(BUILD_DIR)/binvis_cpp.log
JSON_OUTPUT = $(BUILD_DIR)/coverage_output.json

# =============================================================================
# Default target
# =============================================================================
.DEFAULT_GOAL := help

# =============================================================================
# Help target
# =============================================================================
help:
	@echo "BinVis - Coverage Analysis Tool"
	@echo "================================"
	@echo ""
	@echo "Available targets:"
	@echo "  help          - Show this help message"
	@echo "  all           - Build both binvis and binvis_cpp"
	@echo "  binvis        - Build original binvis (text output)"
	@echo "  binvis_cpp    - Build binvis_cpp (JSON output)"
	@echo "  test          - Compile and run simulation"
	@echo "  json          - Generate JSON coverage output"
	@echo "  compare       - Compare original vs C++ versions"
	@echo "  clean         - Clean build artifacts"
	@echo "  clean-all     - Clean everything including simulation files"
	@echo ""
	@echo "Usage examples:"
	@echo "  make DESIGN_FILE=examples/jukebox.v json"
	@echo "  make DESIGN_FILE=examples/covergroup_showcase.sv compare"
	@echo ""

# =============================================================================
# Build targets
# =============================================================================

all: binvis binvis_cpp

binvis: $(BINVIS)

binvis_cpp: $(BINVIS_CPP)

$(BINVIS): $(BINVIS_SRC) $(VISIT_OBJ) | $(BUILD_DIR)
	@echo "Building binvis (original version)..."
	g++ -g -I$(INC) -o $@ $(BINVIS_SRC) $(VISIT_OBJ) -ldl -lm -lpthread $(LIB) $(CFLAGS)

$(BINVIS_CPP): $(BINVIS_CPP_SRC) $(VISIT_OBJ) | $(BUILD_DIR)
	@echo "Building binvis_cpp (JSON version)..."
	g++ -g -I$(INC) -o $@ $(BINVIS_CPP_SRC) $(VISIT_OBJ) -ldl -lm -lpthread $(LIB) $(CFLAGS)

$(VISIT_OBJ): $(VISIT_SRC) $(VISIT_HDR) | $(BUILD_DIR)
	@echo "Compiling visit.cc..."
	g++ -g -I$(INC) -c $(VISIT_SRC) -o $@ $(CFLAGS)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# =============================================================================
# Simulation targets
# =============================================================================

test: check_design_file | $(BUILD_DIR)
	@echo "Compiling and running simulation for $(DESIGN_FILE)..."
	cd $(BUILD_DIR) && vcs -sverilog -cm line ../$(DESIGN_FILE)
	cd $(BUILD_DIR) && ./simv -cm line -l sim.log

test-cg: check_design_file | $(BUILD_DIR)
	@echo "Compiling and running simulation with covergroups for $(DESIGN_FILE)..."
	cd $(BUILD_DIR) && vcs -sverilog ../$(DESIGN_FILE) -assert disable_cover -cm line
	cd $(BUILD_DIR) && ./simv -cm line -l sim.log

# =============================================================================
# Analysis targets
# =============================================================================

run: binvis test
	@echo "Running binvis analysis..."
	cd $(BUILD_DIR) && ./binvis simv.vdb > binvis.log 2>&1
	@echo "Output written to $(OUTPUT_LOG)"

run-cpp: binvis_cpp test
	@echo "Running binvis_cpp analysis..."
	cd $(BUILD_DIR) && ./binvis_cpp simv.vdb > binvis_cpp.log 2>&1
	@echo "Output written to $(OUTPUT_CPP_LOG)"

json: binvis_cpp test
	@echo "Generating JSON coverage output..."
	cd $(BUILD_DIR) && ./binvis_cpp simv.vdb > coverage_output.json
	@echo "JSON coverage data written to $(JSON_OUTPUT)"

compare: binvis binvis_cpp test
	@echo "Comparing original vs C++ versions..."
	cd $(BUILD_DIR) && ./binvis simv.vdb > binvis_original.log 2>&1
	cd $(BUILD_DIR) && ./binvis_cpp simv.vdb > binvis_cpp.log 2>&1
	@echo "Comparing outputs..."
	@if diff $(BUILD_DIR)/binvis_original.log $(BUILD_DIR)/binvis_cpp.log > /dev/null; then \
		echo "SUCCESS: Outputs are identical!"; \
	else \
		echo "DIFFERENCES FOUND:"; \
		diff $(BUILD_DIR)/binvis_original.log $(BUILD_DIR)/binvis_cpp.log | head -20; \
	fi

# =============================================================================
# Utility targets
# =============================================================================

check_design_file:
	@test -n "$(DESIGN_FILE)" || (echo "Error: DESIGN_FILE is not set" && exit 1)
	@test -f "$(DESIGN_FILE)" || (echo "Error: Design file $(DESIGN_FILE) not found" && exit 1)

show-config:
	@echo "Configuration:"
	@echo "  DESIGN_FILE = $(DESIGN_FILE)"
	@echo "  DESIGN_NAME = $(DESIGN_NAME)"
	@echo "  BUILD_DIR   = $(BUILD_DIR)"
	@echo "  VCS_HOME    = $(VCS_HOME)"
	@echo "  Platform    = $(plat)"
	@echo "  CFLAGS      = $(CFLAGS)"

# =============================================================================
# Clean targets
# =============================================================================

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)

clean-sim:
	@echo "Cleaning simulation artifacts..."
	rm -rf $(BUILD_DIR)/simv $(BUILD_DIR)/simv.vdb $(BUILD_DIR)/sim.log
	rm -rf $(BUILD_DIR)/urgReport $(BUILD_DIR)/ucli.key $(BUILD_DIR)/simv.daidir
	rm -rf $(BUILD_DIR)/csrc $(BUILD_DIR)/cm.log

clean-all: clean clean-sim
	@echo "Cleaning everything..."

# =============================================================================
# Development targets
# =============================================================================

debug: CFLAGS += -DDEBUG -g3
debug: binvis_cpp
	@echo "Built debug version of binvis_cpp"

install: binvis binvis_cpp
	@echo "Installing binaries..."
	@mkdir -p $(HOME)/bin
	cp $(BINVIS) $(BINVIS_CPP) $(HOME)/bin/

# =============================================================================
# Phony targets
# =============================================================================
.PHONY: help all binvis binvis_cpp test test-cg run run-cpp json compare \
        check_design_file show-config clean clean-sim clean-all debug install