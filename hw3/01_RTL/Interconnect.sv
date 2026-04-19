module Interconnect #(
    parameter   DATA_WIDTH = 16
) (
    input   logic   i_clk,
    input   logic   i_rst_n,
    output   logic  o_irq,

    // tb interface
    input   logic   [  13:0] i_tb_m_HADDR,
    input   logic            i_tb_m_HWRITE,
    input   logic   [   2:0] i_tb_m_HSIZE,
    input   logic   [   2:0] i_tb_m_HBURST,
    input   logic   [   1:0] i_tb_m_HTRANS,
    input   logic   [1023:0] i_tb_m_HWDATA,
    output  logic            o_tb_m_HREADY,
    output  logic            o_tb_m_HRESP,
    output  logic   [1023:0] o_tb_m_HRDATA,

    // SIMD core interface
    input   logic   [  13:0] i_simd_m_HADDR,
    input   logic            i_simd_m_HWRITE,
    input   logic   [   2:0] i_simd_m_HSIZE,
    input   logic   [   2:0] i_simd_m_HBURST,
    input   logic   [   1:0] i_simd_m_HTRANS,
    input   logic   [1023:0] i_simd_m_HWDATA,
    output  logic            o_simd_m_HREADY,
    output  logic            o_simd_m_HRESP,
    output  logic   [1023:0] o_simd_m_HRDATA,

    output   logic   [  13:0] o_simd_s_HADDR,
    output   logic            o_simd_s_HWRITE,
    output   logic   [   2:0] o_simd_s_HSIZE,
    output   logic   [   2:0] o_simd_s_HBURST,
    output   logic   [   1:0] o_simd_s_HTRANS,
    output   logic   [1023:0] o_simd_s_HWDATA,
    input    logic            i_simd_s_HREADY,
    input    logic            i_simd_s_HRESP,
    input    logic   [1023:0] i_simd_s_HRDATA,

    input    logic            i_simd_irq,

    // GEMM core interface
    input   logic   [  13:0] i_gemm_m_HADDR,
    input   logic            i_gemm_m_HWRITE,
    input   logic   [   2:0] i_gemm_m_HSIZE,
    input   logic   [   2:0] i_gemm_m_HBURST,
    input   logic   [   1:0] i_gemm_m_HTRANS,
    input   logic   [1023:0] i_gemm_m_HWDATA,
    output  logic            o_gemm_m_HREADY,
    output  logic            o_gemm_m_HRESP,
    output  logic   [1023:0] o_gemm_m_HRDATA,

    output   logic   [  13:0] o_gemm_s_HADDR,
    output   logic            o_gemm_s_HWRITE,
    output   logic   [   2:0] o_gemm_s_HSIZE,
    output   logic   [   2:0] o_gemm_s_HBURST,
    output   logic   [   1:0] o_gemm_s_HTRANS,
    output   logic   [1023:0] o_gemm_s_HWDATA,
    input    logic            i_gemm_s_HREADY,
    input    logic            i_gemm_s_HRESP,
    input    logic   [1023:0] i_gemm_s_HRDATA,

    input    logic            i_gemm_irq,

    // Shared Memory interface
    output   logic   [  13:0] o_mem_s_HADDR,
    output   logic            o_mem_s_HWRITE,
    output   logic   [   2:0] o_mem_s_HSIZE,
    output   logic   [   2:0] o_mem_s_HBURST,
    output   logic   [   1:0] o_mem_s_HTRANS,
    output   logic   [1023:0] o_mem_s_HWDATA,
    input    logic            i_mem_s_HREADY,
    input    logic            i_mem_s_HRESP,
    input    logic   [1023:0] i_mem_s_HRDATA,

    input    logic            i_mem_irq,
);
    //////////////////////////parameter /////////////////////////////////////
    typedef enum logic [1:0] { 
        S_MEM,
        S_SIMD,
        S_GEMM,
    } inter_state;
    ////////////////////////////reg and wire declarations//////////////////////////
    inter_state inter_state_w, inter_state_r;


    /////////////////////////////assignments/////////////////////////////
    assign o_irq = i_simd_irq || i_gemm_irq || i_mem_irq;

    // simd
    assign o_simd_s_HADDR = tb_m_HADDR;
    assign o_simd_s_HSIZE = tb_m_HSIZE;
    assign o_simd_s_HBURST = tb_m_HBURST;
    assign o_simd_s_HTRANS = tb_m_HTRANS;
    assign o_simd_s_HWDATA = tb_m_HWDATA;
    assign o_simd_s_HWRITE = tb_m_HWRITE;

    assign o_simd_m_HREADY = i_mem_s_HREADY;
    assign o_simd_m_HRESP = i_mem_s_HRESP;
    assign o_simd_m_HRDATA = i_mem_s_HRDATA;

    // gemm
    assign o_gemm_s_HADDR = tb_m_HADDR;
    assign o_gemm_s_HSIZE = tb_m_HSIZE;
    assign o_gemm_s_HBURST = tb_m_HBURST;
    assign o_gemm_s_HTRANS = tb_m_HTRANS;
    assign o_gemm_s_HWDATA = tb_m_HWDATA;
    assign o_gemm_s_HWRITE = tb_m_HWRITE;

    assign o_gemm_m_HREADY = i_mem_s_HREADY;
    assign o_gemm_m_HRESP = i_mem_s_HRESP;
    assign o_gemm_m_HRDATA = i_mem_s_HRDATA;


    // shared memory
    always_comb begin
        inter_state_w = inter_state_r;
        /////////////////////// memory access control///////////////////////
        case (inter_state_r)
            S_MEM: begin
                if(tb_m_HWRITE && tb_m_HTRANS[1] && tb_m_HWDATA[15:0] == 16'd1)
                    if(tb_m_HADDR == 14'h2000) 
                        inter_state_w = S_SIMD;
                    else if(tb_m_HADDR == 14'h2400) 
                        inter_state_w = S_GEMM;

                // tb connect to shared memory
                o_mem_s_HADDR = i_tb_m_HADDR;
                o_mem_s_HSIZE = i_tb_m_HSIZE;
                o_mem_s_HBURST = i_tb_m_HBURST;
                o_mem_s_HTRANS = i_tb_m_HTRANS;
                o_mem_s_HWDATA = i_tb_m_HWDATA;
                o_mem_s_HWRITE = i_tb_m_HWRITE;
            end 
            S_SIMD: begin
                if(simd_irq) inter_state_w = S_MEM;

                // SIMD core connect to shared memory
                o_mem_s_HADDR = i_simd_m_HADDR;
                o_mem_s_HSIZE = i_simd_m_HSIZE;
                o_mem_s_HBURST = i_simd_m_HBURST;
                o_mem_s_HTRANS = i_simd_m_HTRANS;
                o_mem_s_HWDATA = i_simd_m_HWDATA;
                o_mem_s_HWRITE = i_simd_m_HWRITE;
            end 
            S_GEMM: begin
                if(gemm_irq) inter_state_w = S_MEM;

                // GEMM core connect to shared memory
                o_mem_s_HADDR = i_gemm_m_HADDR;
                o_mem_s_HSIZE = i_gemm_m_HSIZE;
                o_mem_s_HBURST = i_gemm_m_HBURST;
                o_mem_s_HTRANS = i_gemm_m_HTRANS;
                o_mem_s_HWDATA = i_gemm_m_HWDATA;
                o_mem_s_HWRITE = i_gemm_m_HWRITE;
            end 
            default: 
        endcase

        /////////////////////////// tb response mux //////////////////////////
        case({i_tb_m_HADDR[13], i_tb_m_HADDR[11:10]}) 
            3'b100: begin
                o_tb_m_HREADY = i_simd_s_HREADY;
                o_tb_m_HRESP = i_simd_s_HRESP;
                o_tb_m_HRDATA = i_simd_s_HRDATA;
            end 
            3'b101: begin
                o_tb_m_HREADY = i_gemm_s_HREADY;
                o_tb_m_HRESP = i_gemm_s_HRESP;
                o_tb_m_HRDATA = i_gemm_s_HRDATA;
            end 
            default: begin
                o_tb_m_HREADY = i_mem_s_HREADY;
                o_tb_m_HRESP = i_mem_s_HRESP;
                o_tb_m_HRDATA = i_mem_s_HRDATA;
            end
        endcase
    end
endmodule
