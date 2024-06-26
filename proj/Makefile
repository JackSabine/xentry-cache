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

.DEFAULT_GOAL := sim

ifndef PROJECT_ROOT
  $(error You must define the project root by sourcing project.sh)
endif

####################################################################
# Manual configure

# DPI-C Modules/Filenames
DPIC_SOURCES := get_environment_variable

# UVM Verbosity
v = UVM_LOW

# xsim random number generation
RANDOM_NUMBER = $(shell shuf -i 0-4294967296 -n 1)
s = $(RANDOM_NUMBER)

# TB specification
TB_TOP := tb_top

# Provide files to compile (must be added below)
include $(RTL_ROOT)/file_list.mk
include $(DV_ROOT)/file_list.mk
####################################################################
# Output directory configuration
WORK := work
WORKDIR := $(PROJECT_ROOT)/$(WORK)

####################################################################
# DPI-C compilation settings
CC := xsc

INC := -I/usr/include/x86_64-linux-gnu
LIB := -L/usr/lib/x86_64-linux-gnu
CFLAGS := $(addprefix --gcc_compile_options ",$(addsuffix ",$(INC))) $(addprefix --gcc_compile_options ",$(addsuffix ",$(LIB)))

# Auto-generate shared object paths
DPIC_SHARED_OBJECTS := $(addsuffix .so,$(addprefix $(WORKDIR)/,$(DPIC_SOURCES)))

# Auto-generate shared object arg for XELAB
DPIC_SV_LIB_FLAGS := $(addprefix -sv_lib ,$(DPIC_SOURCES))

####################################################################
# HDL compilation/elaboration/simulation settings

# UVM flags
UVM_XVLOG_FLAGS := -L uvm
UVM_XELAB_FLAGS := -L uvm
UVM_XSIM_FLAGS  := -testplusarg UVM_TESTNAME=$(t) -testplusarg UVM_VERBOSITY=$(v)

# Other/non-UVM flags
XVLOG_FLAGS := --sv --incr --include $(DV_ROOT)/svtb --include $(DV_ROOT)/tests
XELAB_FLAGS := --timescale=1ns/1ps --override_timeprecision $(DPIC_SV_LIB_FLAGS)
XSIM_FLAGS  :=

# Compilation/dependency list for xvlog
SRC_FILES_RTL_ABS_PATH := $(addprefix $(RTL_ROOT)/,$(SRC_FILES_RTL))
SRC_FILES_DV_ABS_PATH := $(addprefix $(DV_ROOT)/,$(SRC_FILES_DV))

COMPILE_LIST += ${DV_ROOT}/svtb/torrence_types.sv
COMPILE_LIST += $(SRC_FILES_RTL_ABS_PATH)
COMPILE_LIST += $(SRC_FILES_DV_ABS_PATH)

HDL_SENSITIVITY_LIST := $(shell find ${PROJECT_ROOT}/ -type f -name "*.sv")

####################################################################
# Rules

$(WORKDIR)/%.so: $(DV_DPI_C)/%.c | work
	@echo "----- Compiling DPI-C -----"
	cd $(WORKDIR) && $(CC) $< -o $@ $(CFLAGS)

$(WORKDIR)/xsim.dir/$(WORK)/$(WORK).rlx: $(HDL_SENSITIVITY_LIST) | work
	@echo "----- Compiling HDL -----"
	cd $(WORKDIR) && xvlog $(UVM_XVLOG_FLAGS) $(COMPILE_LIST) $(XVLOG_FLAGS)

$(WORKDIR)/xsim.dir/$(TB_TOP)_snapshot/xsimk: $(DPIC_SHARED_OBJECTS) $(WORKDIR)/xsim.dir/$(WORK)/$(WORK).rlx
	@echo "----- Elaborating HDL -----"
	cd $(WORKDIR) && xelab -top $(TB_TOP) -snapshot $(TB_TOP)_snapshot -debug all $(UVM_XELAB_FLAGS) $(XELAB_FLAGS)

# (c)ompile (o)nly
.PHONY: co
co: $(WORKDIR)/xsim.dir/$(TB_TOP)_snapshot/xsimk
	@echo "----- Compilation complete -----"

.PHONY: sim
sim: co
	@echo "----- Running simulation -----"
	@if [ ! -n "$$t" ]; then \
		echo "UVM_TESTNAME is unset during 'so' step, specify with t=..."; \
		exit 9; \
	fi
	cd $(WORKDIR) && xsim $(TB_TOP)_snapshot -tclbatch $(PROJECT_ROOT)/xsim_cfg.tcl --sv_seed $(s) $(UVM_XSIM_FLAGS); \

.PHONY: waves
waves: | work
	@echo "----- Opening waves -----"
	@if [ -f $(TB_TOP)_snapshot.wcfg ]; then \
		cp $(TB_TOP)_snapshot.wcfg $(WORKDIR); \
	fi
	cd $(WORKDIR) && xsim -autoloadwcfg --gui $(TB_TOP)_snapshot.wdb &

work:
	@mkdir $(WORKDIR)

.PHONY: clean
clean:
	@rm -rf $(WORKDIR)

.PHONY: help
help:
	@echo "#### RULES ####"
	@echo "* co - compile only (xvlog and xelab)"
	@echo "* so - sim only (xsim)"
	@echo "  * s=<seed_override>"
	@echo "  * t=<test_name>"
	@echo "  * v=UVM_<verbosity, NONE/LOW/MEDIUM/HIGH/DEBUG>"
	@echo "* waves - show most recent simulation in waveform"
