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
	rm -rf binvis visit.o urgReport ucli.key simv.daidir csrc simv sim.log simv.vdb binvis.log cm.log
	vcs -sverilog -cm line jukebox.v
	./simv -cm line -l sim.log
	g++ -g -I$(INC) -c visit.cc ${CFLAGS}
	g++ -g -I$(INC) -o binvis binvis.cc $(VISIT)  -ldl -lm -lpthread  $(LIB) ${CFLAGS}
	binvis simv.vdb >& binvis.log
	@echo Output is in file binvis.log

all_cg:
	rm -rf binvis visit.o urgReport ucli.key simv.daidir csrc simv sim.log simv.vdb binvis.log cm.log
	vcs -sverilog jukebox.v -assert disable_cover -cm line 
	./simv -cm line -l sim.log
	g++ -g -I$(INC) -c visit.cc ${CFLAGS}
	g++ -g -I$(INC) -o binvis binvis.cc $(VISIT)  -ldl -lm -lpthread  $(LIB) ${CFLAGS}
	binvis simv.vdb >& binvis.log
	@echo Output is in file binvis.log



binvis: binvis.cc $(VISIT)
	g++ -g -I$(INC) -o binvis binvis.cc $(VISIT) -ldl -lm -lpthread  $(LIB) ${CFLAGS}

$(VISIT) : visit.cc visit.hh
	g++ -g -I$(INC) -c visit.cc ${CFLAGS}

clean:
	rm -rf binvis visit.o urgReport ucli.key simv.daidir csrc simv sim.log simv.vdb binvis.log cm.log

test: jukebox.v binvis
	vcs -sverilog -cm line jukebox.v
	./simv -cm line -l sim2.log 

run: binvis test
	./binvis simv.vdb >& binvis.log
	@echo Output is in file binvis.log

