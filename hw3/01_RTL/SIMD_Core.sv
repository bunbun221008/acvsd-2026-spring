module SIMD_Core #(
    parameter   DATA_WIDTH = 16
) (
    input   logic   i_clk,
    input   logic   i_rst_n,

    // interconnect interface
    output  logic   o_simd_irq,

    input   logic   [  13:0] i_simd_s_HADDR,
    input   logic            i_simd_s_HWRITE,
    input   logic   [   2:0] i_simd_s_HSIZE,
    input   logic   [   2:0] i_simd_s_HBURST,
    input   logic   [   1:0] i_simd_s_HTRANS,
    input   logic   [1023:0] i_simd_s_HWDATA,
    output  logic            o_simd_s_HREADY,
    output  logic            o_simd_s_HRESP,
    output  logic   [1023:0] o_simd_s_HRDATA,

    output   logic   [  13:0] o_simd_m_HADDR,
    output   logic            o_simd_m_HWRITE,
    output   logic   [   2:0] o_simd_m_HSIZE,
    output   logic   [   2:0] o_simd_m_HBURST,
    output   logic   [   1:0] o_simd_m_HTRANS,
    output   logic   [1023:0] o_simd_m_HWDATA,
    input    logic            i_simd_m_HREADY,
    input    logic            i_simd_m_HRESP,
    input    logic   [1023:0] i_simd_m_HRDATA
);
///////////////////////////////parameters and typedefs////////////////////////////
    typedef enum logic {
         S_SIMD_IDLE,
         S_SIMD_READMEM,
     } simd_state;
///////////////////////////////reg and wire declarations//////////////////////////////
    // state machine
    simd_state simd_state_w, simd_state_r;
    // config register
    logic busy_w, busy_r; 

    // PE
    logic [15:0][3:0][DATA_WIDTH-1:0] pe_reg_w, pe_reg_r; // 16 pe, each pe has 4 registers, each register is DATA_WIDTH bits wide
    logic [DATA_WIDTH-1:0] pe_inst_w, pe_inst_r; // instruction for PE, 16 bits wide

    // tb interface
    logic   [  13:0] tb_i_addr;
    logic   [   2:0] tb_i_size;
    logic   [1023:0] tb_i_wdata;
    logic            tb_i_write;
    logic   [1023:0] tb_o_rdata;
    logic            tb_i_read;
    logic            tb_o_ready;

    // shared memory interface
    logic   [  13:0] mem_o_addr;
    logic   [   2:0] mem_o_size;
    logic   [1023:0] mem_o_wdata;
    logic            mem_o_write;
    logic   [1023:0] mem_i_rdata;
    logic            mem_o_read;
    logic            mem_i_ready;

///////////////////////////////combinational logic//////////////////////////////
    always_comb begin
        simd_state_w = simd_state_r;

        busy_w = busy_r; // busy

        tb_o_ready = 1'b1;
        tb_o_rdata = {1008'd0, busy_r, 15'd0};

        mem_o_addr = 14'd0;
        mem_o_size = 3'd0;
        mem_o_wdata = 1024'd0;
        mem_o_write = 1'b0;
        mem_o_read = 1'b0;

        case (simd_state_r)
            S_SIMD_IDLE: begin
                if(tb_i_write && tb_i_addr[13:0] == 14'h2000 && tb_i_wdata[15:0] == 16'h1) begin
                    busy_w = 1'b1;
                    simd_state_w = S_SIMD_READMEM;
                end
            end
            S_SIMD_READMEM: begin
                
            end 
            default: 
        endcase
    end

    
///////////////////////////////module instantiations/////////////////////////////
    // PE

    // PMU
    logic   PSW_NSLEEPIN, ISO_EN;
    logic   PSW_ACK;

    SIMD_pmu u_SIMD_pmu (
        .i_clk   (i_clk),
        .i_rst_n (i_rst_n),

        .test_mode (),

        .SIMD_PSW_NSLEEPIN (PSW_NSLEEPIN),
        .SIMD_ISO_EN       (ISO_EN),
        .SIMD_PSW_ACK      (PSW_ACK)
    );

    ahb_slave #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_ahb_slave (
        .i_clk   (i_clk),
        .i_rst_n (i_rst_n),

        // interconnect interface
        .HADDR   (i_simd_s_HADDR),
        .HWRITE  (i_simd_s_HWRITE),
        .HSIZE   (i_simd_s_HSIZE),
        .HBURST  (i_simd_s_HBURST),
        .HTRANS  (i_simd_s_HTRANS),
        .HWDATA  (i_simd_s_HWDATA),
        .HREADY  (o_simd_s_HREADY),
        .HRESP   (o_simd_s_HRESP),
        .HRDATA  (o_simd_s_HRDATA),
        // to core
        .ahb_addr   (tb_i_addr),
        .ahb_size   (tb_i_size),
        .ahb_wdata  (tb_i_wdata),
        .ahb_write  (tb_i_write),
        .ahb_rdata  (tb_o_rdata),
        .ahb_read   (tb_i_read),
        .ahb_ready  (tb_o_ready)
    );

    ahb_master #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_ahb_master (
        .i_clk   (i_clk),
        .i_rst_n (i_rst_n),

        // to interconnect
        .HADDR   (o_simd_m_HADDR),
        .HWRITE  (o_simd_m_HWRITE),
        .HSIZE   (o_simd_m_HSIZE),
        .HBURST  (o_simd_m_HBURST),
        .HTRANS  (o_simd_m_HTRANS),
        .HWDATA  (o_simd_m_HWDATA),
        .HREADY  (i_simd_m_HREADY),
        .HRESP   (i_simd_m_HRESP),
        .HRDATA  (i_simd_m_HRDATA),

        // from core
        .ahb_addr   (mem_o_addr),
        .ahb_size   (mem_o_size),
        .ahb_wdata  (mem_o_wdata),
        .ahb_write  (mem_o_write),
        .ahb_rdata  (mem_i_rdata),
        .ahb_read   (mem_o_read),
        .ahb_ready  (mem_i_ready)
    );

endmodule



module SIMD_pmu (
    input   logic   i_clk,
    input   logic   i_rst_n,

    input   logic   test_mode,

    output  logic   SIMD_PSW_NSLEEPIN,
    input   logic   SIMD_PSW_ACK,
    output  logic   SIMD_ISO_EN
);

    // when test_mode is 1, PSW should be always closed and ISO should be always disabled
    
endmodule
