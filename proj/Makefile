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

# UVM_HOME    := $(HOME)/Documents/1800.2-2020-1.1

# UVM_COMPILE_OPTIONS     := +incdir+$(UVM_HOME)/src -l $(WORK_DIR)/uvm_1_1 $(UVM_HOME)/src/uvm_pkg.sv
# UVM_SIMULATION_OPTIONS  := +UVM_VERBOSITY=UVM_HIGH +UVM_TESTNAME=$(t)

WORKDIR := $(PROJECT_ROOT)/work
XVLOG_FLAGS := --sv --incr --include $(DV_ROOT)/svtb --include $(DV_ROOT)/tests

COMPILE_LIST += -f $(DV_ROOT)/svtb/file_list
COMPILE_LIST += -f $(RTL_ROOT)/file_list
COMPILE_LIST += -f $(DV_ROOT)/tests/file_list

TB_TOP := icache_full_test

SEED = 1

# (c)ompile (o)nly
.PHONY: co
co: | work
	cd $(WORKDIR)
	xvlog $(COMPILE_LIST) $(XVLOG_FLAGS)
	xelab -top $(TB_TOP) -snapshot $(TB_TOP)_snapshot -debug all

# (s)im (o)nly
.PHONY: so
so: | work
	cd $(WORKDIR)
	xsim $(TB_TOP)_snapshot -tclbatch $(PROJECT_ROOT)/xsim_cfg.tcl --sv_seed $(SEED)

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


# compile_UVM: env
#   @vlog $(UVM_COMPILE_OPTIONS) $(COMPILE_LIST) -source

# simc_UVM:
#   @echo "TEST is $(t)"
#   vsim $(UVM_SIMULATION_OPTIONS) $(TOP_MODULE)
