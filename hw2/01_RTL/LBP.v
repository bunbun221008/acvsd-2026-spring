`timescale 1ns/1ps
module LBP # (
    parameter DATA_WIDTH = 8,              // AXI4 data width
    parameter ADDR_WIDTH = 15,             // AXI4 address width
    parameter STRB_WIDTH = (DATA_WIDTH/8)  // AXI4 strobe width
)
(
    // Clock and synchronous high reset
    input                   clk_A,
    input                   clk_B,
    input                   rst,

    input                   start,
    output                  finish,

    // Data AXI4 master interface
    output [ADDR_WIDTH-1:0] data_awaddr,
    output [           7:0] data_awlen,
    output [           2:0] data_awsize,
    output [           1:0] data_awburst,
    output                  data_awvalid,
    input                   data_awready,
    output [DATA_WIDTH-1:0] data_wdata,
    output [STRB_WIDTH-1:0] data_wstrb,
    output                  data_wlast,
    output                  data_wvalid,
    input                   data_wready,
    // input  [           1:0] data_bresp,
    // input                   data_bvalid,
    // output                  data_bready,
    output [ADDR_WIDTH-1:0] data_araddr,
    output [           7:0] data_arlen,
    output [           2:0] data_arsize,
    output [           1:0] data_arburst,
    output                  data_arvalid,
    input                   data_arready,
    input  [DATA_WIDTH-1:0] data_rdata,
    input  [           1:0] data_rresp,
    input                   data_rlast,
    input                   data_rvalid,
    output                  data_rready
);
    // register
    logic start_a_r, start_b_r;
    
    // assignment

    always @(posedge clk_A or posedge rst) begin
        if (rst) begin
            start_a_r <= 1'b0;
        end else begin
            start_a_r <= start;
        end
    end

    always @(posedge clk_B or posedge rst) begin
        if (rst) begin
            start_b_r <= 1'b0;
        end else begin
            start_b_r <= start_a_r;
        end
    end

endmodule

module lbp_core # (
    parameter DATA_WIDTH = 8,              // AXI4 data width
    parameter ADDR_WIDTH = 15,             // AXI4 address width
    parameter STRB_WIDTH = (DATA_WIDTH/8)  // AXI4 strobe width
)
(
    input                   clk,
    input                   rst,

    input                   start,
    
    // axi control interface
    output                  lbp_read,
    output                  lbp_write,
    output [ADDR_WIDTH-1:0] lbp_addr,
    output [           7:0] lbp_len,
    output [DATA_WIDTH-1:0] lbp_wdata,
    output                  lbp_finish,
    input  [DATA_WIDTH-1:0] lbp_rdata,
    input                   lbp_rvalid,
    input                   axi_ready
);

endmodule

module axi_control # (
    parameter DATA_WIDTH = 8,              // AXI4 data width
    parameter ADDR_WIDTH = 15,             // AXI4 address width
    parameter STRB_WIDTH = (DATA_WIDTH/8),  // AXI4 strobe width
    parameter PARALLEL = 2                 // how many pixels are processed in parallel
)
(
    input                   clk,
    input                   rst,

    output reg              finish,

    // Data AXI4 master interface
    output [ADDR_WIDTH-1:0] data_awaddr,
    output [           7:0] data_awlen,
    output [           2:0] data_awsize,
    output [           1:0] data_awburst,
    output                  data_awvalid,
    input                   data_awready,
    output [DATA_WIDTH-1:0] data_wdata,
    output [STRB_WIDTH-1:0] data_wstrb,
    output                  data_wlast,
    output                  data_wvalid,
    input                   data_wready,
    // input  [           1:0] data_bresp,
    // input                   data_bvalid,
    // output                  data_bready,
    output [ADDR_WIDTH-1:0] data_araddr,
    output [           7:0] data_arlen,
    output [           2:0] data_arsize,
    output [           1:0] data_arburst,
    output                  data_arvalid,
    input                   data_arready,
    input  [DATA_WIDTH-1:0] data_rdata,
    input  [           1:0] data_rresp,
    input                   data_rlast,
    input                   data_rvalid,
    output                  data_rready,

    // lbp core interface
    input                   lbp_read,
    input                   lbp_write,
    input  [ADDR_WIDTH-1:0] lbp_addr,
    input  [           7:0] lbp_len,
    input  [PARALLEL*DATA_WIDTH-1:0] lbp_wdata,
    input                   lbp_finish,

    output [DATA_WIDTH-1:0] lbp_rdata,
    output reg              lbp_rvalid,
    output                  axi_ready // signal to indicate that axi_control is ready to accept new commands from lbp_core
);
    ////////////////////////////// parameter//////////////////////////////
    parameter S_IDLE = 2'd0;
    parameter S_READ = 2'd1;
    parameter S_WRITE = 2'd2;
    parameter S_FINISH = 2'd3;

    /////////////////////////// reg and wire///////////////////////////
    reg [1:0] state_w, state_r;
    reg counter_w, counter_r; // count how many pixels have been read/written in current burst
    
    // axi interface
    reg awvalid, wvalid, arvalid;
    reg [DATA_WIDTH-1:0] wdata;
    reg wlast;

    // lbp core interface
    reg lbp_rvalid;
    
    ///////////////////////////// assignment///////////////////////////
    // axi interface
    assign data_awaddr = lbp_addr;
    assign data_awlen = lbp_len - 1'b1; // burst length is len, but AXI4 uses len-1
    assign data_awsize = 3'b000; // 1 byte
    assign data_awburst = 2'b01; // INCR
    assign data_awvalid = awvalid;

    assign data_wvalid = wvalid;
    assign data_wdata = wdata;
    assign data_wstrb = {STRB_WIDTH{1'b1}}; // all bytes are valid
    assign data_wlast = wlast;

    assign data_arvalid = arvalid;   
    assign data_araddr = lbp_addr;
    assign data_arlen = lbp_len - 1'b1; // burst length is len, but AXI4 uses len-1
    assign data_arsize = 3'b000; // 1 byte
    assign data_arburst = 2'b01; // INCR

    assign data_rready = 1'b1; // always ready to accept data from AXI4

    // lbp core interface
    assign lbp_rdata = data_rdata;
    assign axi_ready = (state_r == S_IDLE);
    
    ///////////////////////////////// combinational logic/////////////////////////////////
    always @(*) begin
        state_w = state_r;
        counter_w = counter_r;
        awvalid = 1'b0;
        wvalid = 1'b0;
        arvalid = 1'b0;
        wlast = 1'b0;

        case (state_r)
            S_IDLE: begin
                counter_w = 1'b0;
                if(lbp_read) begin
                    arvalid = 1'b1;
                    if(data_arready) begin
                        state_w = S_READ;
                    end
                end else if (lbp_write) begin
                    awvalid = 1'b1;
                    if (data_awready) begin
                        state_w = S_WRITE;
                    end
                end
            end
            S_READ: begin
                if (data_rvalid) begin
                    lbp_rvalid = 1'b1; 
                    if (data_rlast) begin
                        state_w = S_IDLE;
                    end
                end
            end
            S_WRITE: begin
                wvalid = 1'b1;
                wdata = lbp_wdata[counter_r * DATA_WIDTH +: DATA_WIDTH]; // only write one pixel each time
                if (data_wready) begin
                    counter_w = counter_r + 1'b1;
                    if (counter_r == PARALLEL - 1'b1) begin
                        wlast = 1'b1;
                        state_w = (lbp_finish) ? S_FINISH : S_IDLE;
                    end
                end
            end
            S_FINISH: begin
                finish = 1'b1;
            end 
        endcase
    end

endmodule
