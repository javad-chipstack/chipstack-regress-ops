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

ifeq ($(wildcard $(VCS_HOME)/${plat}/lib/libucapi.a),)
   LIB = $(VCS_HOME)/lib/libucapi.so
   INC = $(VCS_HOME)/coverage/ucapi/include
else
   LIB = $(VCS_HOME)/${plat}/lib/libucapi.so
   INC = $(VCS_HOME)/include
endif

VISIT = visit.o

$(PGM): $(PGM).cc $(VISIT)
	c++ -g -I$(INC) -o $(PGM) $(PGM).cc $(VISIT)  -ldl -lm -lpthread -lnsl $(LIB) ${CFLAGS}

$(VISIT) : visit.cc visit.hh
	c++ -g -I$(INC) -c visit.cc ${CFLAGS}
run:
	rm -rf csrc simv.daidir simv.vdb cm.log simv simv.out vcs.out ccompile.out ucli.key testname *.o *Report dumptgl
	# vcs -lca -cm tgl -cm_tgl mda -sverilog jukebox.v -l compile.log
	vcs -cm tgl -sverilog jukebox.v -l compile.log
	./simv -cm tgl -l run.log
	c++ -g -I$(INC) -c visit.cc ${CFLAGS}
	c++ -g -I$(INC) -o $(PGM) $(PGM).cc $(VISIT) -ldl -lm -lpthread  $(LIB)  ${CFLAGS}
	./dumptgl simv.vdb station > dump_tgl

clean:
	rm -rf csrc simv.daidir simv.vdb cm.log simv simv.out vcs.out ccompile.out ucli.key testname *.o *Report dumptgl
	rm -f $(PGM) 

