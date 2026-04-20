module Shared_Memory #(
    parameter   DATA_WIDTH = 16
 )(
    input   logic   i_clk,
    input   logic   i_rst_n,

    output    logic            o_mem_irq,

    input   logic   [  13:0] i_mem_s_HADDR,
    input   logic            i_mem_s_HWRITE,
    input   logic   [   2:0] i_mem_s_HSIZE,
    input   logic   [   2:0] i_mem_s_HBURST,
    input   logic   [   1:0] i_mem_s_HTRANS,
    input   logic   [1023:0] i_mem_s_HWDATA,
    output    logic            o_mem_s_HREADY,
    output    logic            o_mem_s_HRESP,
    output    logic   [1023:0] o_mem_s_HRDATA,
 );
 /////////////////////////////////parameter /////////////////////////////////////
    localparam SRAM_NUM = 6;

 /////////////////////////////////module declaration/////////////////////////////
    genvar gi;
    generate
        for(gi=0; gi<SRAM_NUM; gi++) begin : gen_sram
            spsram128x64m4 sram(
                .SLP(),    // Active high
                .DSLP(),   // Active high
                .SD(),     // Active high
                .CLK(),
                .CEB(),    // Active low
                .WEB(),    // Active low
                .A(),
                .D(),
                .BWEB(),    // Active low
                .Q(),
                // input   [1:0] RTSEL,
                // input   [1:0] WTSEL,
                .PUDELAY()
            );
        end
    endgenerate

    ahb_slave #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_ahb_slave (
        .i_clk   (i_clk),
        .i_rst_n (i_rst_n),

        // interconnect interface
        .HADDR   (i_mem_s_HADDR),
        .HWRITE  (i_mem_s_HWRITE),
        .HSIZE   (i_mem_s_HSIZE),
        .HBURST  (i_mem_s_HBURST),
        .HTRANS  (i_mem_s_HTRANS),
        .HWDATA  (i_mem_s_HWDATA),
        .HREADY  (o_mem_s_HREADY),
        .HRESP   (o_mem_s_HRESP),
        .HRDATA  (o_mem_s_HRDATA),
        // to core
        .ahb_addr   (i_addr),
        .ahb_size   (i_size),
        .ahb_wdata  (i_wdata),
        .ahb_write  (i_write),
        .ahb_rdata  (o_rdata),
        .ahb_read   (i_read),
        .ahb_ready  (o_ready)
    );
endmodule
