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
GHDL_FLAGS := --std=08 -frelaxed -P$(UVVM_LIBS) --workdir=$(BUILD_DIR)

# Design and testbench
DUT := $(SRC_DIR)/adder.vhd
TB  := $(TB_DIR)/tb_adder_uvvm.vhd
TOP := tb_adder_uvvm

# ============================================================
# Targets
# ============================================================

.PHONY: all compile test clean

all: test

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

compile_libs: $(UVVM_COMPILE_STAMP)

# Compile UVVM libraries and create a stamp file (to avoid recompilation)
$(UVVM_COMPILE_STAMP): $(UVVM_SOURCES)
	@echo "==> Compiling UVVM libraries..."
	$(UVVM_DIR)/script/compile_all.sh ghdl
	touch $(UVVM_COMPILE_STAMP)

compile: compile_libs | $(BUILD_DIR)
	@echo "==> Compiling UVVM, DUT and testbench..."
	$(GHDL) -a $(GHDL_FLAGS) $(DUT)
	$(GHDL) -a $(GHDL_FLAGS) $(TB)
	$(GHDL) -e $(GHDL_FLAGS) $(TOP)

test: compile
	@echo "==> Running test (no waveform)..."
	$(GHDL) -r $(GHDL_FLAGS) $(TOP) --assert-level=error

clean:
	@echo "==> Cleaning build artifacts..."
	rm -rf $(BUILD_DIR) $(UVVM_LIBS)
