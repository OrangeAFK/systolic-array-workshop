# Verilator simulation Makefile for systolic array workshop
# Usage:
#   make pe                          # Stage 1: PE test
#   make array                       # Stage 2: fixed identity test
#   make all                         # Stage 3: full randomized suite
#   make pe PE_SRC=../exercises/01_pe.sv

VERILATOR   ?= verilator
ROOT        := $(abspath ..)
SIM_DIR     := $(abspath .)
OBJ_DIR     := $(SIM_DIR)/obj

VL_FLAGS    := --timing -Wall -Wno-fatal --trace -CFLAGS -std=c++17

PE_SRC      ?= $(ROOT)/rtl/pe.sv
ARRAY_SRC   ?= $(ROOT)/rtl/systolic_array.sv
RTL_COMMON  := $(ROOT)/rtl/controller.sv $(ROOT)/rtl/top.sv

.PHONY: pe array all stream clean

# Stage 1: processing element
pe: $(OBJ_DIR)/pe/Vtb_pe
	@echo "==> Running PE testbench"
	$(OBJ_DIR)/pe/Vtb_pe

$(OBJ_DIR)/pe/Vtb_pe: $(ROOT)/tb/tb_pe.sv $(PE_SRC) $(SIM_DIR)/main_pe.cpp
	@mkdir -p $(OBJ_DIR)/pe
	@echo "==> Building PE simulation"
	$(VERILATOR) $(VL_FLAGS) --cc --exe --build \
		-Mdir $(OBJ_DIR)/pe \
		-o Vtb_pe \
		--top-module tb_pe \
		$(ROOT)/tb/tb_pe.sv $(PE_SRC) \
		$(SIM_DIR)/main_pe.cpp

# Stage 2: 4x4 array (fixed identity test)
array: $(OBJ_DIR)/array/Vtb_systolic_array
	@echo "==> Running array testbench (identity test)"
	$(OBJ_DIR)/array/Vtb_systolic_array

$(OBJ_DIR)/array/Vtb_systolic_array: $(ROOT)/tb/tb_systolic_array.sv $(PE_SRC) $(ARRAY_SRC) $(RTL_COMMON) $(SIM_DIR)/main_tb.cpp
	@mkdir -p $(OBJ_DIR)/array
	@echo "==> Building array simulation"
	$(VERILATOR) $(VL_FLAGS) --cc --exe --build \
		-Mdir $(OBJ_DIR)/array \
		-o Vtb_systolic_array \
		--top-module tb_systolic_array \
		$(ROOT)/tb/tb_systolic_array.sv $(PE_SRC) $(ARRAY_SRC) $(RTL_COMMON) \
		$(SIM_DIR)/main_tb.cpp

# Stage 3: full randomized test suite
all: $(OBJ_DIR)/all/Vtb_systolic_array
	@echo "==> Running full test suite"
	$(OBJ_DIR)/all/Vtb_systolic_array +full

$(OBJ_DIR)/all/Vtb_systolic_array: $(ROOT)/tb/tb_systolic_array.sv $(PE_SRC) $(ARRAY_SRC) $(RTL_COMMON) $(SIM_DIR)/main_tb.cpp
	@mkdir -p $(OBJ_DIR)/all
	@echo "==> Building full simulation"
	$(VERILATOR) $(VL_FLAGS) --cc --exe --build \
		-Mdir $(OBJ_DIR)/all \
		-o Vtb_systolic_array \
		--top-module tb_systolic_array \
		$(ROOT)/tb/tb_systolic_array.sv $(PE_SRC) $(ARRAY_SRC) $(RTL_COMMON) \
		$(SIM_DIR)/main_tb.cpp

clean:
	rm -rf $(OBJ_DIR)
