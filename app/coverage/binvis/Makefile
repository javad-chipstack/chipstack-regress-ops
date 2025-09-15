# =============================================================================
# BinVis C++ - JSON Coverage Analysis Tool
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

# VDB file path (can be overridden from command line)
# If not specified, will use build/simv.vdb (created by test target)
VDB_FILE ?= $(BUILD_DIR)/simv.vdb

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
BINVIS_CPP_SRC = $(SRC_DIR)/binvis_cpp.cc
VISIT_SRC = $(SRC_DIR)/visit.cc
VISIT_HDR = $(SRC_DIR)/visit.hh

# Executable
BINVIS_CPP = $(BUILD_DIR)/binvis_cpp

# Simulation artifacts (all in build directory)
SIMV = $(BUILD_DIR)/simv
VDB = $(BUILD_DIR)/simv.vdb
SIM_LOG = $(BUILD_DIR)/sim.log

# Output files
OUTPUT_LOG = $(BUILD_DIR)/binvis_cpp.log
JSON_OUTPUT = $(BUILD_DIR)/coverage_output.json

# =============================================================================
# Default target
# =============================================================================
.DEFAULT_GOAL := help

# =============================================================================
# Help target
# =============================================================================
help:
	@echo "BinVis C++ - JSON Coverage Analysis Tool"
	@echo "========================================="
	@echo ""
	@echo "Workflow: PRE-VDB → POST-VDB"
	@echo "  PRE-VDB:  Build tools + Run simulation → Create VDB file"
	@echo "  POST-VDB: Analyze VDB → Generate JSON output"
	@echo ""
	@echo "Available targets:"
	@echo "  help          - Show this help message"
	@echo "  build         - Build binvis_cpp executable (PRE-VDB)"
	@echo "  sim           - Compile and run simulation to create VDB (PRE-VDB)"
	@echo "  json          - Complete workflow: build + sim + analysis (PRE-VDB + POST-VDB)"
	@echo "  json-from-vdb - Generate JSON from existing VDB file (POST-VDB only)"
	@echo "  clean         - Clean all build and simulation artifacts"
	@echo ""
	@echo "Usage examples:"
	@echo "  # Complete workflow with design file"
	@echo "  make DESIGN_FILE=examples/jukebox.v json"
	@echo "  make DESIGN_FILE=examples/covergroup_showcase.sv json"
	@echo ""
	@echo "  # Use existing VDB file"
	@echo "  make VDB_FILE=/path/to/existing/simv.vdb json-from-vdb"
	@echo "  make VDB_FILE=../other_project/build/simv.vdb json-from-vdb"
	@echo ""

# =============================================================================
# SECTION 1: PRE-VDB (Build Tools & Simulation to VDB Creation)
# =============================================================================

# Build the analysis tool
build: $(BINVIS_CPP)

$(BINVIS_CPP): $(BINVIS_CPP_SRC) $(VISIT_OBJ)
	@echo "Building binvis_cpp (JSON version)..."
	g++ -g -I$(INC) -o $@ $(BINVIS_CPP_SRC) $(VISIT_OBJ) -ldl -lm -lpthread $(LIB) $(CFLAGS)

$(VISIT_OBJ): $(VISIT_SRC) $(VISIT_HDR)
	@echo "Compiling visit.cc..."
	@mkdir -p $(BUILD_DIR)
	g++ -g -I$(INC) -c $(VISIT_SRC) -o $@ $(CFLAGS)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Utility function for design file validation
check_design_file:
	@test -n "$(DESIGN_FILE)" || (echo "Error: DESIGN_FILE is not set" && exit 1)
	@test -f "$(DESIGN_FILE)" || (echo "Error: Design file $(DESIGN_FILE) not found" && exit 1)

# Compile and run simulation to create VDB
sim: check_design_file | $(BUILD_DIR)
	@echo "Compiling and running simulation for $(DESIGN_FILE)..."
	cd $(BUILD_DIR) && vcs -sverilog -cm line ../$(DESIGN_FILE)
	cd $(BUILD_DIR) && ./simv -cm line -l sim.log

# =============================================================================
# SECTION 2: POST-VDB (Analysis & JSON Generation)
# =============================================================================

# Complete workflow: build tools, run simulation, generate JSON
json: build sim
	@echo "Generating JSON coverage output from $(VDB_FILE)..."
	cd $(BUILD_DIR) && ./binvis_cpp simv.vdb > coverage_output.json
	@echo "JSON coverage data written to $(JSON_OUTPUT)"

# Generate JSON from existing VDB file (skip simulation)
json-from-vdb: build check_vdb_file
	@echo "Generating JSON coverage output from existing VDB file: $(VDB_FILE)..."
	cd $(BUILD_DIR) && ./binvis_cpp $(abspath $(VDB_FILE)) > coverage_output.json
	@echo "JSON coverage data written to $(JSON_OUTPUT)"

# Utility function for VDB file validation
check_vdb_file:
	@test -n "$(VDB_FILE)" || (echo "Error: VDB_FILE is not set" && exit 1)
	@test -d "$(VDB_FILE)" || (echo "Error: VDB directory $(VDB_FILE) not found" && exit 1)

# Clean all artifacts (both pre-VDB and post-VDB)
clean:
	@echo "Cleaning all build and simulation artifacts..."
	rm -rf $(BUILD_DIR)

# =============================================================================
# Phony targets
# =============================================================================
.PHONY: help build sim json json-from-vdb check_design_file check_vdb_file clean
