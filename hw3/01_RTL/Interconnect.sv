module Interconnect #(
    parameter   DATA_WIDTH = 16
) (
    input   logic   i_clk,
    input   logic   i_rst_n,
    input   logic   irq,

    // tb interface
    input   logic   [  13:0] tb_m_HADDR,
    input   logic            tb_m_HWRITE,
    input   logic   [   2:0] tb_m_HSIZE,
    input   logic   [   2:0] tb_m_HBURST,
    input   logic   [   1:0] tb_m_HTRANS,
    input   logic   [1023:0] tb_m_HWDATA,
    output  logic            tb_m_HREADY,
    output  logic            tb_m_HRESP,
    output  logic   [1023:0] tb_m_HRDATA,

    // SIMD core interface
    input   logic   [  13:0] simd_m_HADDR,
    input   logic            simd_m_HWRITE,
    input   logic   [   2:0] simd_m_HSIZE,
    input   logic   [   2:0] simd_m_HBURST,
    input   logic   [   1:0] simd_m_HTRANS,
    input   logic   [1023:0] simd_m_HWDATA,
    output  logic            simd_m_HREADY,
    output  logic            simd_m_HRESP,
    output  logic   [1023:0] simd_m_HRDATA,

    output   logic   [  13:0] simd_s_HADDR,
    output   logic            simd_s_HWRITE,
    output   logic   [   2:0] simd_s_HSIZE,
    output   logic   [   2:0] simd_s_HBURST,
    output   logic   [   1:0] simd_s_HTRANS,
    output   logic   [1023:0] simd_s_HWDATA,
    input    logic            simd_s_HREADY,
    input    logic            simd_s_HRESP,
    input    logic   [1023:0] simd_s_HRDATA,

    // GEMM core interface
    input   logic   [  13:0] gemm_m_HADDR,
    input   logic            gemm_m_HWRITE,
    input   logic   [   2:0] gemm_m_HSIZE,
    input   logic   [   2:0] gemm_m_HBURST,
    input   logic   [   1:0] gemm_m_HTRANS,
    input   logic   [1023:0] gemm_m_HWDATA,
    output  logic            gemm_m_HREADY,
    output  logic            gemm_m_HRESP,
    output  logic   [1023:0] gemm_m_HRDATA,

    output   logic   [  13:0] gemm_s_HADDR,
    output   logic            gemm_s_HWRITE,
    output   logic   [   2:0] gemm_s_HSIZE,
    output   logic   [   2:0] gemm_s_HBURST,
    output   logic   [   1:0] gemm_s_HTRANS,
    output   logic   [1023:0] gemm_s_HWDATA,
    input    logic            gemm_s_HREADY,
    input    logic            gemm_s_HRESP,
    input    logic   [1023:0] gemm_s_HRDATA,

    // Shared Memory interface
    output   logic   [  13:0] mem_s_HADDR,
    output   logic            mem_s_HWRITE,
    output   logic   [   2:0] mem_s_HSIZE,
    output   logic   [   2:0] mem_s_HBURST,
    output   logic   [   1:0] mem_s_HTRANS,
    output   logic   [1023:0] mem_s_HWDATA,
    input    logic            mem_s_HREADY,
    input    logic            mem_s_HRESP,
    input    logic   [1023:0] mem_s_HRDATA,
);
    //////////////////////////parameter /////////////////////////////////////
    typedef enum logic [1:0] { 
        S_MEM,
        S_SIMD,
        S_GEMM,
    } state;
    ////////////////////////////reg and wire declarations//////////////////////////
    state state_w, state_r;


    /////////////////////////////assignments/////////////////////////////
    // simd
    assign simd_s_HADDR = tb_m_HADDR;
    assign simd_s_HSIZE = tb_m_HSIZE;
    assign simd_s_HBURST = tb_m_HBURST;
    assign simd_s_HTRANS = tb_m_HTRANS;
    assign simd_s_HWDATA = tb_m_HWDATA;
    assign simd_s_HWRITE = tb_m_HWRITE;

    assign simd_m_HREADY = mem_s_HREADY;
    assign simd_m_HRESP = mem_s_HRESP;
    assign simd_m_HRDATA = mem_s_HRDATA;

    // gemm
    assign gemm_s_HADDR = tb_m_HADDR;
    assign gemm_s_HSIZE = tb_m_HSIZE;
    assign gemm_s_HBURST = tb_m_HBURST;
    assign gemm_s_HTRANS = tb_m_HTRANS;
    assign gemm_s_HWDATA = tb_m_HWDATA;
    assign gemm_s_HWRITE = tb_m_HWRITE;

    assign gemm_m_HREADY = mem_s_HREADY;
    assign gemm_m_HRESP = mem_s_HRESP;
    assign gemm_m_HRDATA = mem_s_HRDATA;


    // shared memory
    always_comb begin
        state_w = state_r;
        case (state_r)
            S_MEM: begin
                if(tb_m_HWRITE && tb_m_HTRANS[1] && tb_m_HWDATA[15:0] == 16'd1)
                    if(tb_m_HADDR == 14'h2000) state_w = S_SIMD;
                    else if(tb_m_HADDR == 14'h2400) state_w = S_GEMM;

                // tb connect to shared memory
                mem_s_HADDR = tb_m_HADDR;
                mem_s_HSIZE = tb_m_HSIZE;
                mem_s_HBURST = tb_m_HBURST;
                mem_s_HTRANS = tb_m_HTRANS;
                mem_s_HWDATA = tb_m_HWDATA;
                mem_s_HWRITE = tb_m_HWRITE;

                tb_m_HREADY = mem_s_HREADY;
                tb_m_HRESP = mem_s_HRESP;
                tb_m_HRDATA = mem_s_HRDATA;

            end 
            S_SIMD: begin
                if(irq) state_w = S_MEM;

                // SIMD core connect to shared memory
                mem_s_HADDR = simd_m_HADDR;
                mem_s_HSIZE = simd_m_HSIZE;
                mem_s_HBURST = simd_m_HBURST;
                mem_s_HTRANS = simd_m_HTRANS;
                mem_s_HWDATA = simd_m_HWDATA;
                mem_s_HWRITE = simd_m_HWRITE;

                tb_m_HREADY = simd_s_HREADY;
                tb_m_HRESP = simd_s_HRESP;
                tb_m_HRDATA = simd_s_HRDATA;
            end 
            S_GEMM: begin
                if(irq) state_w = S_MEM;

                // GEMM core connect to shared memory
                mem_s_HADDR = gemm_m_HADDR;
                mem_s_HSIZE = gemm_m_HSIZE;
                mem_s_HBURST = gemm_m_HBURST;
                mem_s_HTRANS = gemm_m_HTRANS;
                mem_s_HWDATA = gemm_m_HWDATA;
                mem_s_HWRITE = gemm_m_HWRITE;

                tb_m_HREADY = gemm_s_HREADY;
                tb_m_HRESP = gemm_s_HRESP;
                tb_m_HRDATA = gemm_s_HRDATA;
            end 
            default: 
        endcase
    end
endmodule
