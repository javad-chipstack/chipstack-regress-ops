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

$(PGM): src/$(PGM).cpp $(VISIT)
	c++ -g -I$(INC) -o build/$(PGM) src/$(PGM).cpp build/$(VISIT)  -ldl -lm -lpthread $(LIB) ${CFLAGS}

$(VISIT) : src/visit.cc src/visit.hh
	c++ -g -I$(INC) -c src/visit.cc -o build/visit.o ${CFLAGS}
run:
	rm -rf build/*
	mkdir -p build
	# vcs -lca -cm tgl -cm_tgl mda -sverilog designs/jukebox.v -l build/compile.log
	vcs -cm tgl -sverilog designs/jukebox.v -l build/compile.log -o build/simv -Mdir=build/csrc -cm_log build/cm.log
	./build/simv -cm tgl -l build/run.log
	[ -f ucli.key ] && mv ucli.key build/ || true
	c++ -g -I$(INC) -c src/visit.cc -o build/visit.o ${CFLAGS}
	c++ -g -I$(INC) -o build/$(PGM) src/$(PGM).cpp build/$(VISIT) -ldl -lm -lpthread $(LIB) ${CFLAGS}
	./build/dumptgl build/simv.vdb station > build/dump_tgl

clean:
	rm -rf build

