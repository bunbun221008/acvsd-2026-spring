module ahb_slave #(
    parameter   DATA_WIDTH = 16
) (
    input   logic   i_clk,
    input   logic   i_rst_n,

    // ahb signals
    input   logic   [  13:0] HADDR,
    input   logic            HWRITE,
    input   logic   [   2:0] HSIZE,
    input   logic   [   2:0] HBURST,
    input   logic   [   1:0] HTRANS,
    input   logic   [1023:0] HWDATA,
    output  logic            HREADY,
    output  logic            HRESP,
    output  logic   [1023:0] HRDATA,
    // to core
    output  logic   [  13:0] ahb_addr,
    output  logic   [   2:0] ahb_size,
    output  logic   [1023:0] ahb_wdata,
    output  logic            ahb_write,
    input   logic   [1023:0] ahb_rdata,
    output  logic            ahb_read,
    input   logic            ahb_ready,
);
    logic [1:0] error_w, error_r;
    logic ready;

    assign ahb_addr = HADDR;
    assign ahb_size = HSIZE;
    assign ahb_wdata = HWDATA;
    assign ahb_write = HWRITE && HTRANS[1] && !(error_r || error_w);
    assign ahb_read = ~HWRITE && HTRANS[1] && !(error_r || error_w);
    assign HREADY = ready;
    assign HRESP = |error_r;
    assign HRDATA = ahb_rdata;

    always_comb begin;
        error_w = {error_r[0],1'b0};
        if((HADDR>=14'h1800 && HADDR<=14'h1FFF) || (HADDR>=14'h2C00 && HADDR<=14'h3FFF))
            error_w = 2'b01;

        if(error_r[0]) ready = 1'b0;
        else if(error_r[1]) ready = 1'b1;
        else ready = ahb_ready;
    end 

    always_ff @( posedge i_clk or negedge i_rst_n ) begin
        if ( !i_rst_n ) begin
            error_r <= 2'b00;
        end
        else begin
            error_r <= error_w;
        end
    end
endmodule

module ahb_master #(
    parameter   DATA_WIDTH = 16
) (
    input   logic   i_clk,
    input   logic   i_rst_n,

    output  logic   [  13:0] HADDR,
    output  logic            HWRITE,
    output  logic   [   2:0] HSIZE,
    output  logic   [   2:0] HBURST,
    output  logic   [   1:0] HTRANS,
    output  logic   [1023:0] HWDATA,
    input   logic            HREADY,
    input   logic            HRESP,
    input   logic   [1023:0] HRDATA,

    // to core
    input  logic   [  13:0] ahb_addr,
    input  logic   [   2:0] ahb_size,
    input  logic   [1023:0] ahb_wdata,
    input  logic            ahb_write,
    output   logic   [1023:0] ahb_rdata,
    input  logic            ahb_read,
    output   logic            ahb_ready
);
    assign HADDR = ahb_addr;
    assign HSIZE = ahb_size;
    assign HBURST = 3'b000;
    assign HWDATA = ahb_wdata;
    assign HWRITE = ahb_write;
    assign HTRANS = (ahb_write || ahb_read) ? 2'b10 : 2'b00;
    assign ahb_rdata = HRDATA;
    assign ahb_ready = HREADY && !HRESP;
endmodule