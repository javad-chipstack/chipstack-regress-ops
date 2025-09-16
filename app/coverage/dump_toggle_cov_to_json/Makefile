all: run 

CFLAGS:=-m64 

plat:= $(shell vcs -platform )
ifeq  ($(plat),linux)
      CFLAGS:=-m32
endif

ifeq ($(plat),suse32)
      CFLAGS:=-m32
endif
      
ifeq ($(plat),sparcOS5)
      CFLAGS:=-m32 
endif

ifeq ($(plat),solarisx86)
      CFLAGS:=-m32
endif

ifeq ($(wildcard $(LD_LIBRARY_PATH)),) 
   LD_LIBRARY_PATH:=$(VCS_HOME)/${plat}/lib
else 
   LD_LIBRARY_PATH:=$(VCS_HOME)/${plat}/lib 
endif 


PGM = dumptgl

# Design parameters - can be overridden from command line
DESIGN_FILE ?= designs/jukebox.v
MODULE_NAME ?= station

ifeq ($(wildcard $(VCS_HOME)/${plat}/lib/libucapi.a),)
   LIB = $(VCS_HOME)/lib/libucapi.so
   INC = $(VCS_HOME)/coverage/ucapi/include
else
   LIB = $(VCS_HOME)/${plat}/lib/libucapi.so
   INC = $(VCS_HOME)/include
endif

VISIT = visit.o

$(PGM): src/$(PGM).cpp $(VISIT)
	c++ -g -I$(INC) -o build/$(PGM) src/$(PGM).cpp build/$(VISIT)  -ldl -lm -lpthread $(LIB) ${CFLAGS}

$(VISIT) : src/visit.cc src/visit.hh
	c++ -g -I$(INC) -c src/visit.cc -o build/visit.o ${CFLAGS}
run:
	rm -rf build/*
	mkdir -p build
	# vcs -lca -cm tgl -cm_tgl mda -sverilog $(DESIGN_FILE) -l build/compile.log
	vcs -cm tgl -sverilog $(DESIGN_FILE) -l build/compile.log -o build/simv -Mdir=build/csrc -cm_log build/cm.log
	./build/simv -cm tgl -l build/run.log
	[ -f ucli.key ] && mv ucli.key build/ || true
	c++ -g -I$(INC) -c src/visit.cc -o build/visit.o ${CFLAGS}
	c++ -g -I$(INC) -o build/$(PGM) src/$(PGM).cpp build/$(VISIT) -ldl -lm -lpthread $(LIB) ${CFLAGS}
	./build/dumptgl build/simv.vdb $(MODULE_NAME) > build/tgl_report.txt

# Convenience targets for different designs/modules
run-jukebox:
	$(MAKE) run DESIGN_FILE=designs/jukebox.v MODULE_NAME=station

run-soc-register:
	$(MAKE) run DESIGN_FILE=designs/soc_register_hierarchy.sv MODULE_NAME=tb_toggle_coverage

# Add more targets as needed:
# run-my-design:
#	$(MAKE) run DESIGN_FILE=designs/my_design.v MODULE_NAME=my_module

help:
	@echo "Available targets:"
	@echo "  run                    - Run with default design (jukebox.v, station module)"
	@echo "  run-jukebox            - Run with jukebox design and station module"
	@echo "  run-soc-register       - Run with soc_register_hierarchy.sv design and tb_toggle_coverage module"
	@echo "  run DESIGN_FILE=...    - Run with custom design file"
	@echo "  run MODULE_NAME=...    - Run with custom module name"
	@echo "  run DESIGN_FILE=... MODULE_NAME=... - Run with both custom"
	@echo "  clean                 - Clean build directory"
	@echo ""
	@echo "Examples:"
	@echo "  make run DESIGN_FILE=designs/my_design.v MODULE_NAME=my_module"
	@echo "  make run MODULE_NAME=testbench"
	@echo "  make run-soc-register"

clean:
	rm -rf build

