# ============================================================
# Makefile for building and running UVVM-based testbenches with GHDL
# ============================================================

# Directories
BUILD_DIR := build
SRC_DIR   := project/src
TB_DIR    := project/tb
UVVM_DIR  := UVVM

# Libraries
UVVM_LIBS := ghdl

# UVVM source files
UVVM_SOURCES := $(shell find $(UVVM_DIR) -type f)
UVVM_COMPILE_STAMP := $(UVVM_LIBS)/.compiled

# Toolchain
GHDL := ghdl
GHDL_FLAGS := --std=08 -frelaxed -P$(UVVM_LIBS)

# Designs and testbenches
# Blakley
DUT_BLAKLEY := $(SRC_DIR)/blakley.vhd
TB_BLAKLEY  := $(TB_DIR)/tb_blakley.vhd
TOP_BLAKLEY := tb_blakley
BUILD_DIR_BLAKLEY := $(BUILD_DIR)/$(TOP_BLAKLEY)
# Modular exponentiation
DUT_EXP := $(SRC_DIR)/adder.vhd
TB_EXP  := $(TB_DIR)/tb_adder_uvvm.vhd
TOP_EXP := tb_adder_uvvm
BUILD_DIR_EXP := $(BUILD_DIR)/$(TOP_EXP)

# ============================================================
# Targets
# ============================================================

.PHONY: all compile-blakley compile-exp compile test clean

all: test

$(BUILD_DIR_BLAKLEY):
	mkdir -p $(BUILD_DIR_BLAKLEY)

$(BUILD_DIR_EXP):
	mkdir -p $(BUILD_DIR_EXP)

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

compile-exp: compile_libs | $(BUILD_DIR_EXP)
	@echo "==> Compiling DUT and testbench for modular exponentiation..."
	$(GHDL) -a $(GHDL_FLAGS) --workdir=$(BUILD_DIR_EXP) $(DUT_EXP)
	$(GHDL) -a $(GHDL_FLAGS) --workdir=$(BUILD_DIR_EXP) $(TB_EXP)
	$(GHDL) -e $(GHDL_FLAGS) --workdir=$(BUILD_DIR_EXP) -o $(BUILD_DIR_EXP)/$(TOP_EXP) $(TOP_EXP)

compile: compile-blakley compile-exp

test-blakley: compile-blakley
	@echo "==> Running tests for blakley..."
	@sh -c 'if $(GHDL) --version | grep -q "LLVM JIT"; then \
		exec $(GHDL) -r $(GHDL_FLAGS) $(TOP_BLAKLEY) --assert-level=error; \
	else \
		exec $(BUILD_DIR)/$(TOP_BLAKLEY)/$(TOP_BLAKLEY) --assert-level=error; \
	fi'

test-exp: compile
	@echo "==> Running tests for modular exponentiation..."
	@sh -c 'if $(GHDL) --version | grep -q "LLVM JIT"; then \
		exec $(GHDL) -r $(GHDL_FLAGS) $(TOP_EXP) --assert-level=error; \
	else \
		exec $(BUILD_DIR)/$(TOP_EXP)/$(TOP_EXP) --assert-level=error; \
	fi'

test: test-blakley test-exp	

clean:
	@echo "==> Cleaning build artifacts..."
	rm -rf $(BUILD_DIR) $(UVVM_LIBS)
