module top # (
    parameter   DATA_WIDTH = 16
) (
    input   logic   CLK,
    input   logic   CLK_CORE,
    input   logic   RST_N,
    output  logic   IRQ,

    input   logic   [  13:0] HADDR,
    input   logic            HWRITE,
    input   logic   [   2:0] HSIZE,
    input   logic   [   2:0] HBURST,
    input   logic   [   1:0] HTRANS,
    input   logic   [1023:0] HWDATA,
    output  logic            HREADY,
    output  logic            HRESP,
    output  logic   [1023:0] HRDATA,

    input   logic   test_mode,      // for PMU bypass
    input   logic   scan_enable     // for DFT, not used in RTL
);

    // SIMD Core
    SIMD_Core #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_SIMD (
        .i_clk   (),
        .i_rst_n ()
    );

    // GEMM Core
    GEMM_Core #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_GEMM (
        .i_clk  (),
        .i_rst_n()
    );

    // Shared Memory
    Shared_Memory #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_Shared_Memory (
        .i_clk   (),
        .i_rst_n ()
    );

    // Interconnect
    Interconnect #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_Interconnect (
        .i_clk   (),
        .i_rst_n ()
    );
    
endmodule