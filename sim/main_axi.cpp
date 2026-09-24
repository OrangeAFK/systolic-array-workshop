// Verilator C++ main for tb_axi_wrapper
#include "Vtb_axi_wrapper.h"
#include "verilated.h"

vluint64_t main_time = 0;

double sc_time_stamp() {
    return main_time;
}

static void tick(Vtb_axi_wrapper* tb) {
    tb->clk = 0;
    tb->eval();
    tb->clk = 1;
    tb->eval();
    main_time++;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtb_axi_wrapper* tb = new Vtb_axi_wrapper;

    while (!Verilated::gotFinish()) {
        tick(tb);
        if (main_time > 2000000) {
            VL_PRINTF("ERROR: simulation timeout\n");
            break;
        }
    }

    delete tb;
    return 0;
}
