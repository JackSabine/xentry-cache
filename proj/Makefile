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

.DEFAULT_GOAL := sim

ifndef PROJECT_ROOT
  $(error You must define the project root by sourcing project.sh)
endif

UVM_HOME    := $(HOME)/Documents/uvm-1.2/

UVM_XVLOG_FLAGS := -L uvm
UVM_XELAB_FLAGS := -L uvm
UVM_XSIM_FLAGS  := -testplusarg UVM_TESTNAME=$(t) -testplusarg UVM_VERBOSITY=UVM_DEBUG

WORKDIR := $(PROJECT_ROOT)/work
XVLOG_FLAGS := --sv --incr --include $(DV_ROOT)/svtb --include $(DV_ROOT)/tests
XELAB_FLAGS := --timescale=1ns/1ps --override_timeprecision

COMPILE_LIST += -f $(DV_ROOT)/svtb/file_list
COMPILE_LIST += -f $(RTL_ROOT)/file_list
# COMPILE_LIST += -f $(DV_ROOT)/tests/file_list

TB_TOP := tb_top

SEED = 1

# (c)ompile (o)nly
.PHONY: co
co: | work
	cd $(WORKDIR)
	xvlog $(UVM_XVLOG_FLAGS) $(COMPILE_LIST) $(XVLOG_FLAGS)
	xelab -top $(TB_TOP) -snapshot $(TB_TOP)_snapshot -debug all $(UVM_XELAB_FLAGS) $(XELAB_FLAGS)

# (s)im (o)nly
.PHONY: so
so: | work
	cd $(WORKDIR)
	xsim $(TB_TOP)_snapshot -tclbatch $(PROJECT_ROOT)/xsim_cfg.tcl --sv_seed $(SEED) $(UVM_XSIM_FLAGS)

.PHONY: sim
sim: co so

.PHONY: waves
waves: | work
	cd $(WORKDIR)
	xsim -autoloadwcfg --gui $(TB_TOP)_snapshot.wdb &

work:
	mkdir $(WORKDIR)

.PHONY: clean
clean:
	rm -rf $(WORKDIR)
