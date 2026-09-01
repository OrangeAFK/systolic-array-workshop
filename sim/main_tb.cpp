// Verilator C++ main for tb_systolic_array
#include "Vtb_systolic_array.h"
#include "verilated.h"

vluint64_t main_time = 0;

double sc_time_stamp() {
    return main_time;
}

static void tick(Vtb_systolic_array* tb) {
    tb->clk = 0;
    tb->eval();
    tb->clk = 1;
    tb->eval();
    main_time++;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtb_systolic_array* tb = new Vtb_systolic_array;

    while (!Verilated::gotFinish()) {
        tick(tb);
        if (main_time > 500000) {
            VL_PRINTF("ERROR: simulation timeout\n");
            break;
        }
    }

    delete tb;
    return 0;
}
