# Verilator simulation Makefile for systolic array workshop
# Usage:
#   make pe                          # Stage 1: PE test
#   make array                       # Stage 2: fixed identity test
#   make all                         # Stage 3: full randomized suite
#   make stream                      # Stage 4: systolic_core AXIS tests
#   make axi                         # Stage 5: axi_wrapper Lite tests
#   make pe PE_SRC=../exercises/01_pe.sv

VERILATOR   ?= verilator
ROOT        := $(abspath ..)
SIM_DIR     := $(abspath .)
OBJ_DIR     := $(SIM_DIR)/obj

VL_FLAGS    := --timing -Wall -Wno-fatal --trace -CFLAGS -std=c++17

PE_SRC      ?= $(ROOT)/rtl/pe.sv
ARRAY_SRC   ?= $(ROOT)/rtl/systolic_array.sv
CORE_SRC    ?= $(ROOT)/rtl/systolic_core.sv
AXI_SRC     ?= $(ROOT)/rtl/axi_wrapper.sv
RTL_COMMON  := $(ROOT)/rtl/controller.sv $(ROOT)/rtl/top.sv
RTL_CORE    := $(PE_SRC) $(ARRAY_SRC) $(RTL_COMMON) $(CORE_SRC)
RTL_AXI     := $(RTL_CORE) $(AXI_SRC)

.PHONY: pe array all stream axi clean

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

# Stage 4: systolic_core AXIS streaming
stream: $(OBJ_DIR)/stream/Vtb_systolic_core
	@echo "==> Running systolic_core testbench"
	$(OBJ_DIR)/stream/Vtb_systolic_core

$(OBJ_DIR)/stream/Vtb_systolic_core: $(ROOT)/tb/tb_systolic_core.sv $(RTL_CORE) $(SIM_DIR)/main_stream.cpp
	@mkdir -p $(OBJ_DIR)/stream
	@echo "==> Building stream simulation"
	$(VERILATOR) $(VL_FLAGS) --cc --exe --build \
		-Mdir $(OBJ_DIR)/stream \
		-o Vtb_systolic_core \
		--top-module tb_systolic_core \
		$(ROOT)/tb/tb_systolic_core.sv $(RTL_CORE) \
		$(SIM_DIR)/main_stream.cpp

# Stage 5: axi_wrapper AXI-Lite
axi: $(OBJ_DIR)/axi/Vtb_axi_wrapper
	@echo "==> Running axi_wrapper testbench"
	$(OBJ_DIR)/axi/Vtb_axi_wrapper

$(OBJ_DIR)/axi/Vtb_axi_wrapper: $(ROOT)/tb/tb_axi_wrapper.sv $(RTL_AXI) $(SIM_DIR)/main_axi.cpp
	@mkdir -p $(OBJ_DIR)/axi
	@echo "==> Building axi simulation"
	$(VERILATOR) $(VL_FLAGS) --cc --exe --build \
		-Mdir $(OBJ_DIR)/axi \
		-o Vtb_axi_wrapper \
		--top-module tb_axi_wrapper \
		$(ROOT)/tb/tb_axi_wrapper.sv $(RTL_AXI) \
		$(SIM_DIR)/main_axi.cpp

clean:
	rm -rf $(OBJ_DIR)
