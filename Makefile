# ============================================================
# Makefile for building and running UVVM-based testbenches with GHDL
# ============================================================

# Directories
BUILD_DIR := build
SRC_DIR   := project/RSA_accelerator/source
TB_DIR    := project/tb
UVVM_DIR  := UVVM

# Libraries
UVVM_LIBS := ghdl

# UVVM source files
UVVM_SOURCES := $(shell find $(UVVM_DIR) -type f)
UVVM_COMPILE_STAMP := $(UVVM_LIBS)/.compiled

# Toolchain
GHDL := ghdl
GHDL_FLAGS := --std=08 -frelaxed -fsynopsys -P$(UVVM_LIBS)

# Designs and testbenches
# Blakley
DUT_BLAKLEY := $(SRC_DIR)/blakley.vhd
TB_BLAKLEY  := $(TB_DIR)/tb_blakley.vhd
TOP_BLAKLEY := tb_blakley
BUILD_DIR_BLAKLEY := $(BUILD_DIR)/$(TOP_BLAKLEY)
# Modular exponentiation
DUT_EXP_SM := $(SRC_DIR)/FSM_general_module_1.vhd
TB_EXP_SM  := $(TB_DIR)/tb_mod_exp_sm.vhd
TOP_EXP_SM := tb_mod_exp_sm
BUILD_DIR_EXP_SM := $(BUILD_DIR)/$(TOP_EXP_SM)
# Modular exponentiation combinatorial logic
DUT_EXP_COMB := \
	$(SRC_DIR)/FSM_general_module_1.vhd \
	$(SRC_DIR)/general_module_combinatory_file.vhd
TB_EXP_COMB  := $(TB_DIR)/tb_mod_exp_combinatorial.vhd
TOP_EXP_COMB := tb_mod_exp_combinatorial
BUILD_DIR_EXP_COMB := $(BUILD_DIR)/$(TOP_EXP_COMB)

# ============================================================
# Targets
# ============================================================

.PHONY: all compile-blakley compile-exp-sm compile-exp-comb compile \
			test-blakley test-exp-sm test-exp-comb test clean

all: test

$(BUILD_DIR_BLAKLEY):
	mkdir -p $(BUILD_DIR_BLAKLEY)

$(BUILD_DIR_EXP_SM):
	mkdir -p $(BUILD_DIR_EXP_SM)

$(BUILD_DIR_EXP_COMB):
	mkdir -p $(BUILD_DIR_EXP_COMB)

compile_libs: $(UVVM_COMPILE_STAMP)

# Compile UVVM libraries and create a stamp file (to avoid recompilation)
$(UVVM_COMPILE_STAMP): $(UVVM_SOURCES)
	@echo "==> Compiling UVVM libraries..."
	$(UVVM_DIR)/script/compile_all.sh ghdl
	touch $(UVVM_COMPILE_STAMP)

compile-blakley: compile_libs | $(BUILD_DIR_BLAKLEY)
	@echo "==> Compiling DUT and testbench for blakley..."
	$(GHDL) -a $(GHDL_FLAGS) --workdir=$(BUILD_DIR_BLAKLEY) $(DUT_BLAKLEY)
	$(GHDL) -a $(GHDL_FLAGS) --workdir=$(BUILD_DIR_BLAKLEY) $(TB_BLAKLEY)
	$(GHDL) -e $(GHDL_FLAGS) --workdir=$(BUILD_DIR_BLAKLEY) -o $(BUILD_DIR_BLAKLEY)/$(TOP_BLAKLEY) $(TOP_BLAKLEY)

compile-exp-sm: compile_libs | $(BUILD_DIR_EXP_SM)
	@echo "==> Compiling DUT and testbench for the state machine of modular exponentiation..."
	$(GHDL) -a $(GHDL_FLAGS) --workdir=$(BUILD_DIR_EXP_SM) $(DUT_EXP_SM)
	$(GHDL) -a $(GHDL_FLAGS) --workdir=$(BUILD_DIR_EXP_SM) $(TB_EXP_SM)
	$(GHDL) -e $(GHDL_FLAGS) --workdir=$(BUILD_DIR_EXP_SM) -o $(BUILD_DIR_EXP_SM)/$(TOP_EXP_SM) $(TOP_EXP_SM)

compile-exp-comb: compile_libs | $(BUILD_DIR_EXP_COMB)
	@echo "==> Compiling DUT and testbench for the combinatorial logic of modular exponentiation..."
	$(GHDL) -a $(GHDL_FLAGS) --workdir=$(BUILD_DIR_EXP_COMB) $(DUT_EXP_COMB)
	$(GHDL) -a $(GHDL_FLAGS) --workdir=$(BUILD_DIR_EXP_COMB) $(TB_EXP_COMB)
	$(GHDL) -e $(GHDL_FLAGS) --workdir=$(BUILD_DIR_EXP_COMB) -o $(BUILD_DIR_EXP_COMB)/$(TOP_EXP_COMB) $(TOP_EXP_COMB)

compile: compile-blakley compile-exp compile-exp-comb

test-blakley: compile-blakley
	@echo "==> Running tests for blakley..."
	@sh -c 'if $(GHDL) --version | grep -q "LLVM JIT"; then \
		exec $(GHDL) -r $(GHDL_FLAGS) --workdir=$(BUILD_DIR_BLAKLEY) $(TOP_BLAKLEY) --assert-level=error; \
	else \
		exec $(BUILD_DIR_BLAKLEY)/$(TOP_BLAKLEY) --assert-level=error; \
	fi'

test-exp-sm: compile-exp-sm
	@echo "==> Running tests for the state machine of modular exponentiation..."
	@sh -c 'if $(GHDL) --version | grep -q "LLVM JIT"; then \
		exec $(GHDL) -r $(GHDL_FLAGS) --workdir=$(BUILD_DIR_EXP_SM) $(TOP_EXP_SM) --assert-level=error; \
	else \
		exec $(BUILD_DIR_EXP_SM)/$(TOP_EXP_SM) --assert-level=error; \
	fi'

test-exp-comb: compile-exp-comb
	@echo "==> Running tests for the combinatorial logic of modular exponentiation..."
	@sh -c 'if $(GHDL) --version | grep -q "LLVM JIT"; then \
		exec $(GHDL) -r $(GHDL_FLAGS) --workdir=$(BUILD_DIR_EXP_COMB) $(TOP_EXP_COMB) --assert-level=error; \
	else \
		exec $(BUILD_DIR_EXP_COMB)/$(TOP_EXP_COMB) --assert-level=error; \
	fi'

test: test-blakley test-exp-sm	test-exp-comb

clean:
	@echo "==> Cleaning build artifacts..."
	rm -rf $(BUILD_DIR) $(UVVM_LIBS)
