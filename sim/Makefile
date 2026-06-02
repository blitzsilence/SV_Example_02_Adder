# File list
TOP       = tb_adder
RTL				= ../rtl/adder.v
TB		    = ../tb/tb_adder.sv

## Makefile Target
all: clean comp sim

comp:			
	vcs -full64 -sverilog \
		-fsdb -kdb -lca \
    -debug_access+all \
		-timescale=1ns/1ns \
		$(RTL) $(TB) -top $(TOP)\
		-l tb_adder.log
	
sim:
	./simv
				
verdi:
	verdi -ssf tb_adder.fsdb -nologo &

.PHONY: all comp sim verdi clean cleanall

clean:
	rm -rf csrc simv simv.* *.fsdb *.log *.daidir
	
cleanall: clean	
	rm -rf novas* ucli.key vc_hdrs.h *_sim_dir
	rm -rf coverage merge.vdb urgReport vdCovLog verdiLog 
