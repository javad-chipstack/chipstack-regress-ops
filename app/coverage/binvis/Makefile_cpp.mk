# Makefile for C++ version of binvis
# This version generates the same output as the original binvis

# Design file parameter - can be overridden from command line (includes extension)
# DESIGN_FILE ?= jukebox.v
# Design name derived from design file (without extension)
DESIGN_NAME = $(basename $(DESIGN_FILE))

CFLAGS:=-m64 

plat:= $(shell vcs -platform )
ifeq  ($(plat),linux)
      CFLAGS:=-m32
endif

ifeq ($(plat),suse32)
      CFLAGS:=-m32
endif

ifeq ($(wildcard $(LD_LIBRARY_PATH)),) 
   LD_LIBRARY_PATH:=$(LD_LIBRARY_PATH):$(VCS_HOME)/${plat}/lib
else 
   LD_LIBRARY_PATH:=$(LD_LIBRARY_PATH):$(VCS_HOME)/${plat}/lib 
endif 

ifeq ($(wildcard $(VCS_HOME)/${plat}/lib/libucapi.so),)
   LIB = $(VCS_HOME)/lib/libucapi.so
   INC = $(VCS_HOME)/coverage/ucapi/include
else
   LIB = $(VCS_HOME)/${plat}/lib/libucapi.so
   INC = $(VCS_HOME)/include
endif

VISIT = visit.o

all:
	rm -rf binvis_cpp visit.o urgReport ucli.key simv.daidir csrc simv sim.log simv.vdb binvis_cpp.log cm.log
	vcs -sverilog -cm line $(DESIGN_FILE)
	./simv -cm line -l sim.log
	g++ -g -I$(INC) -c visit.cc ${CFLAGS}
	g++ -g -I$(INC) -o binvis_cpp binvis_cpp.cc $(VISIT) -ldl -lm -lpthread $(LIB) ${CFLAGS}
	./binvis_cpp simv.vdb >& binvis_cpp.log
	@echo Output is in file binvis_cpp.log

all_cg:
	rm -rf binvis_cpp visit.o urgReport ucli.key simv.daidir csrc simv sim.log simv.vdb binvis_cpp.log cm.log
	vcs -sverilog $(DESIGN_FILE) -assert disable_cover -cm line 
	./simv -cm line -l sim.log
	g++ -g -I$(INC) -c visit.cc ${CFLAGS}
	g++ -g -I$(INC) -o binvis_cpp binvis_cpp.cc $(VISIT) -ldl -lm -lpthread $(LIB) ${CFLAGS}
	./binvis_cpp simv.vdb >& binvis_cpp.log
	@echo Output is in file binvis_cpp.log

binvis_cpp: binvis_cpp.cc $(VISIT)
	g++ -g -I$(INC) -o binvis_cpp binvis_cpp.cc $(VISIT) -ldl -lm -lpthread $(LIB) ${CFLAGS}

$(VISIT) : visit.cc visit.hh
	g++ -g -I$(INC) -c visit.cc ${CFLAGS}

clean:
	rm -rf binvis_cpp visit.o urgReport ucli.key simv.daidir csrc simv sim.log simv.vdb binvis_cpp.log cm.log

test: $(DESIGN_FILE) binvis_cpp
	vcs -sverilog -cm line $(DESIGN_FILE)
	./simv -cm line -l sim2.log 

run: binvis_cpp test
	./binvis_cpp simv.vdb >& binvis_cpp.log
	@echo Output is in file binvis_cpp.log

# Target to compare outputs
compare: binvis_cpp
	make -f Makefile binvis DESIGN_FILE=$(DESIGN_FILE)
	./binvis simv.vdb >& binvis_original.log
	./binvis_cpp simv.vdb >& binvis_cpp.log
	@echo "Comparing outputs..."
	@if diff binvis_original.log binvis_cpp.log > /dev/null; then \
		echo "SUCCESS: Outputs are identical!"; \
	else \
		echo "DIFFERENCES FOUND:"; \
		diff binvis_original.log binvis_cpp.log | head -20; \
	fi

# Target to generate JSON coverage output
json: binvis_cpp test
	./binvis_cpp simv.vdb > coverage_output.json
	@echo "JSON coverage data written to coverage_output.json"

# Target to generate JSON coverage output with hit counts
json_hits: binvis_cpp test
	./binvis_cpp simv.vdb > coverage_output_with_hits.json
	@echo "JSON coverage data with hit counts written to coverage_output_with_hits.json"

.PHONY: all all_cg clean test run compare json json_hits
