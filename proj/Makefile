# Vivado project makefile
#
# + project/
# | + dv/
# | | + svtb/
# | | | * file_list
# | | | * ${project}_pkg.sv
# | | + tests/
# | | | * file_list
# | | | * foo_test.sv
# | + rtl/
# | | * file_list
# | | * foo.sv
# | * Makefile (this file!)
# | * project.sh

.ONESHELL:
.SHELLFLAGS = -ec

.DEFAULT_GOAL := sim

ifndef PROJECT_ROOT
  $(error You must define the project root by sourcing project.sh)
endif

UVM_HOME    := $(HOME)/Documents/uvm-1.2/
LIB_DPI = mydpi

UVM_XVLOG_FLAGS := -L uvm
UVM_XELAB_FLAGS := -L uvm
UVM_XSIM_FLAGS  := -testplusarg UVM_TESTNAME=$(t) -testplusarg UVM_VERBOSITY=UVM_LOW

WORKDIR := $(PROJECT_ROOT)/work
XVLOG_FLAGS := --sv --incr --include $(DV_ROOT)/svtb --include $(DV_ROOT)/tests
XELAB_FLAGS := --timescale=1ns/1ps --override_timeprecision -sv_lib ${LIB_DPI}

COMPILE_LIST += ${DV_ROOT}/svtb/torrence_types.sv
COMPILE_LIST += -f $(RTL_ROOT)/file_list
COMPILE_LIST += -f $(DV_ROOT)/file_list

TB_TOP := tb_top

RANDOM_NUMBER = $(shell shuf -i 0-4294967296 -n 1)
s = $(RANDOM_NUMBER)


.PHONY: cmodels
cmodels:
	xsc -o ${WORKDIR}/${LIB_DPI}.so \
		-f ${DV_DPI_C}/file_list \
		--gcc_compile_options "-I/usr/include/x86_64-linux-gnu" --gcc_compile_options "-L/usr/lib/x86_64-linux-gnu"

# (c)ompile (o)nly
.PHONY: co
co: cmodels | work
	cd $(WORKDIR)
	xvlog $(UVM_XVLOG_FLAGS) $(COMPILE_LIST) $(XVLOG_FLAGS)
	xelab -top $(TB_TOP) -snapshot $(TB_TOP)_snapshot -debug all $(UVM_XELAB_FLAGS) $(XELAB_FLAGS)

# (s)im (o)nly
.PHONY: so
so: | work
	cd $(WORKDIR)
	xsim $(TB_TOP)_snapshot -tclbatch $(PROJECT_ROOT)/xsim_cfg.tcl --sv_seed $(s) $(UVM_XSIM_FLAGS)

.PHONY: sim
sim: co so

.PHONY: waves
waves: | work
	if [ -f $(TB_TOP)_snapshot.wcfg ]; then
		cp $(TB_TOP)_snapshot.wcfg $(WORKDIR)
	fi
	cd $(WORKDIR)
	xsim -autoloadwcfg --gui $(TB_TOP)_snapshot.wdb &

work:
	mkdir $(WORKDIR)

.PHONY: clean
clean:
	rm -rf $(WORKDIR)

.PHONY: help
help:
	@echo "#### RULES ####"
	@echo "* co - compile only (xvlog and xelab)"
	@echo "* so - sim only (xsim)"
	@echo "  * s=<seed_override>"
	@echo "  * t=<test_name>"
	@echo "* waves - show most recent simulation in waveform"
