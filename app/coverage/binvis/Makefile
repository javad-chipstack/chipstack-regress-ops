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


e2e: check_design_file
	make clean_results
	make clean
	make all DESIGN_FILE=$(DESIGN_FILE) && make run DESIGN_FILE=$(DESIGN_FILE) > a1.txt
	make -f Makefile_cpp.mk clean && make -f Makefile_cpp.mk all DESIGN_FILE=$(DESIGN_FILE) > a2.txt
	make clean

check_design_file: $(DESIGN_FILE)
	@test -n "$(DESIGN_FILE)" || (echo "Error: DESIGN_FILE is not set" && exit 1)

all: check_design_file
	rm -rf binvis visit.o urgReport ucli.key simv.daidir csrc simv sim.log simv.vdb binvis.log cm.log
	vcs -sverilog -cm line $(DESIGN_FILE)
	./simv -cm line -l sim.log
	g++ -g -I$(INC) -c visit.cc ${CFLAGS}
	g++ -g -I$(INC) -o binvis binvis.cc $(VISIT)  -ldl -lm -lpthread  $(LIB) ${CFLAGS}
	./binvis simv.vdb >& binvis.log
	@echo Output is in file binvis.log

all_cg: check_design_file
	rm -rf binvis visit.o urgReport ucli.key simv.daidir csrc simv sim.log simv.vdb binvis.log cm.log
	vcs -sverilog $(DESIGN_FILE) -assert disable_cover -cm line 
	./simv -cm line -l sim.log
	g++ -g -I$(INC) -c visit.cc ${CFLAGS}
	g++ -g -I$(INC) -o binvis binvis.cc $(VISIT)  -ldl -lm -lpthread  $(LIB) ${CFLAGS}
	./binvis simv.vdb >& binvis.log
	@echo Output is in file binvis.log

binvis: binvis.cc $(VISIT) check_design_file
	g++ -g -I$(INC) -o binvis binvis.cc $(VISIT) -ldl -lm -lpthread  $(LIB) ${CFLAGS}

$(VISIT) : visit.cc visit.hh
	g++ -g -I$(INC) -c visit.cc ${CFLAGS}

test: binvis check_design_file
	vcs -sverilog -cm line $(DESIGN_FILE)
	./simv -cm line -l sim2.log 

run: binvis test check_design_file
	./binvis simv.vdb >& binvis.log
	@echo Output is in file binvis.log

clean_results:
	rm -rf a1.txt a2.txt coverage_output.json

clean:
	rm -rf binvis_cpp binvis visit.o urgReport ucli.key simv.daidir csrc simv sim.log simv.vdb binvis.log cm.log sim2.log sim2.log binvis_cpp.log 
