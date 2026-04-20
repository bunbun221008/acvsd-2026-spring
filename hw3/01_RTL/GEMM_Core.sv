module GEMM_Core #(
    parameter   DATA_WIDTH = 16
) (
    input   logic   i_clk,
    input   logic   i_rst_n,

    output    logic            o_gemm_irq,

    input   logic   [  13:0] i_gemm_s_HADDR,
    input   logic            i_gemm_s_HWRITE,
    input   logic   [   2:0] i_gemm_s_HSIZE,
    input   logic   [   2:0] i_gemm_s_HBURST,
    input   logic   [   1:0] i_gemm_s_HTRANS,
    input   logic   [1023:0] i_gemm_s_HWDATA,
    output  logic            o_gemm_s_HREADY,
    output  logic            o_gemm_s_HRESP,
    output  logic   [1023:0] o_gemm_s_HRDATA,

    output   logic   [  13:0] o_gemm_m_HADDR,
    output   logic            o_gemm_m_HWRITE,
    output   logic   [   2:0] o_gemm_m_HSIZE,
    output   logic   [   2:0] o_gemm_m_HBURST,
    output   logic   [   1:0] o_gemm_m_HTRANS,
    output   logic   [1023:0] o_gemm_m_HWDATA,
    input    logic            i_gemm_m_HREADY,
    input    logic            i_gemm_m_HRESP,
    input    logic   [1023:0] i_gemm_m_HRDATA
);
  ///////////////////////////////parameter and localparam declaration////////////////////////////
    typedef enum logic {
        S_GEMM_IDLE,
        S_GEMM_READ_DATA_A,
        S_GEMM_READ_DATA_B,
        S_GEMM_COMPUTE,
        S_GEMM_WRITE
    } gemm_state;

    localparam COMPUTE_COL_NUM = 4;
    localparam A_READ_SIZE = $clog2(2* 32/COMPUTE_COL_NUM);
    localparam WRITE_SIZE = $clog2(COMPUTE_COL_NUM*2); // size of the data to write back to memory, 2^4 = 16 bytes, which can store 8 elements of the result

  ////////////////////////////reg and wire declaration//////////////////////////
    // state machine
    gemm_state gemm_state_w, gemm_state_r;
    logic [4:0] a_row_idx_w, a_row_idx_r, b_col_idx_w, b_col_idx_r; // index of the row/column being processed, 5 bits wide to support up to 32 rows/columns
    logic [1:0] a_row_block_idx_w, a_row_block_idx_r; // index of the block of the row being processed, 2 bits wide to support up to 4 blocks (since we read 8 elements at a time)

    //mac
    logic [31:0][DATA_WIDTH-1:0] fp_mul_in_0, fp_mul_in_1, fp_mul_out; 
    logic [31:0][DATA_WIDTH-1:0] fp_add_in_0, fp_add_in_1, fp_add_out; 

    // config register
    logic busy_w, busy_r; 

    // cache registers for matrix A and B
    logic [32/COMPUTE_COL_NUM-1:0][DATA_WIDTH-1:0] a_cache_w, a_cache_r; // 8 elements
    logic [COMPUTE_COL_NUM-1:0][31:0][DATA_WIDTH-1:0] b_cache_w, b_cache_r; // 4 x 32, 4 columns of 32 elements each
    logic [COMPUTE_COL_NUM-1:0][DATA_WIDTH-1:0] z_cache_w, z_cache_r; // 4 elements for the result of the computation

    // ahb
    logic   [  13:0] tb_i_addr;
    logic   [   2:0] tb_i_size;
    logic   [1023:0] tb_i_wdata;
    logic            tb_i_write;
    logic            tb_i_read;

    logic   [1023:0] tb_o_rdata;
    logic            tb_o_ready;

    logic   [  13:0] mem_o_addr;
    logic   [   2:0] mem_o_size;
    logic   [1023:0] mem_o_wdata;
    logic            mem_o_write;
    logic            mem_o_read;

    logic   [1023:0] mem_i_rdata;
    logic            mem_i_ready;

    integer i, j;
    genvar gi, gj;

  ///////////////////////////////combinational logic//////////////////////////////
    always_comb begin : state_machine
        gemm_state_w = gemm_state_r;
        a_row_idx_w = a_row_idx_r;
        b_col_idx_w = b_col_idx_r;
        a_row_block_idx_w = a_row_block_idx_r;


        busy_w = busy_r; // busy
        o_gemm_irq = 1'b0; // interrupt signal, should be set to 1 when the computation is done

        // ahb interface
        tb_o_ready = 1'b1;
        tb_o_rdata = {1008'd0, busy_r, 15'd0};

        mem_o_addr = 14'd0;
        mem_o_size = 3'd0;
        mem_o_wdata = 1024'd0;
        mem_o_write = 1'b0;
        mem_o_read = 1'b0;

        case (gemm_state_r)
            S_GEMM_IDLE: begin
                a_row_idx_w = 5'd0;
                b_col_idx_w = 5'd0;
                a_row_block_idx_w = 2'd0;

                if(tb_i_write && tb_i_addr[13:0] == 14'h2400 && tb_i_wdata[15:0] == 16'h1) begin
                    busy_w = 1'b1;
                end
                if((busy_r || busy_w) && mem_i_ready) begin
                    gemm_state_w = S_GEMM_READ_DATA_B;
                    // read 4 columns of matrix B
                    mem_o_addr = {3'd1, 5'd0, 6'd0};
                    mem_o_size = 3'd7; 
                    mem_o_read = 1'b1;
                end
            end
            S_GEMM_READ_DATA_B: begin
                if(mem_i_ready) begin
                    // write the column of matrix B to cache registers
                    for(i=0; i<32; i++) begin
                        b_cache_w[2'd2*b_col_idx_r[1]][i] = mem_i_rdata[i*16 +: 16];
                        b_cache_w[2'd2*b_col_idx_r[1]+1][i] = mem_i_rdata[(i+32)*16 +: 16];
                    end
  //WARNING: b_col_idx_r[1] is not general for different COMPUTE_COL_NUM, need to change bit number when we want to support different number of columns to compute at the same time
                    // read the next column of matrix B
                    b_col_idx_w = b_col_idx_r + 2'd2; // move to the next 2 columns (since we read 2 columns at a time)
                    mem_o_addr = {3'd1, b_col_idx_w, 6'd0}; // address of the row to read, each row is 32 bytes (256 bits) and there are 64 rows
                    mem_o_size = 3'd7; // size of the data to read,
                    mem_o_read = 1'b1;
                    
                    if(b_col_idx_r[1] == COMPUTE_COL_NUM/2 - 1'd1) begin // after reading 4 columns of matrix B, read the first 8 elements of current row of matrix A
                        gemm_state_w = S_GEMM_READ_DATA_A;

                        mem_o_addr = {3'd0, a_row_idx_r, 6'd0}; 
                        mem_o_size = A_READ_SIZE; // size of the data to read, 2^4 = 16 bytes. read 8 elements 
                        mem_o_read = 1'b1;
                    end
                end
            end 
            S_GEMM_READ_DATA_A: begin
                if(mem_i_ready) begin
                    gemm_state_w = S_GEMM_COMPUTE;
                    // write the row of matrix B to PE registers
                    for(i=0; i<32/COMPUTE_COL_NUM; i++) begin
                        a_cache_w[i] = mem_i_rdata[i*16 +: 16];
                    end
                end
            end 
            S_GEMM_COMPUTE: begin
                // write the result to z cache register
                for(i=0; i<COMPUTE_COL_NUM; i++) begin
                    z_cache_w[i] = fp_add_out[8*i+7];
                end
                if(mem_i_ready) begin
                    gemm_state_w = S_GEMM_READ_DATA_A;
                    a_row_block_idx_w = a_row_block_idx_r + 1; // move to the next block of the row
                    mem_o_addr = {3'd0, a_row_idx_r, a_row_block_idx_w, 4'd0}; 
                    mem_o_size = A_READ_SIZE; // size of the data to read, 2^4 = 16 bytes. read 8 elements 
                    mem_o_read = 1'b1;

                    if(a_row_block_idx_r == 32/COMPUTE_COL_NUM - 1) begin // after computing with the current row of matrix A and 4 columns of matrix B, write the result back to memory
                        gemm_state_w = S_GEMM_WRITE;
                        a_row_block_idx_w = 2'd0; // reset block index for the next row

                        mem_o_addr = {3'd0, a_row_idx_r, b_col_idx_r-5'd4, 1'd0}; 
                        mem_o_size = WRITE_SIZE; // size of the data to write back to memory, 2^4 = 16 bytes. write 8 elements 
                        mem_o_read = 1'b0;
                        mem_o_write = 1'b1; // start writing the result back to memory
                    end
                end
            end
            S_GEMM_WRITE: begin
                // write the result back to memory
                mem_o_wdata = z_cache_r; // the result of the computation is stored in the pe_store_reg_idx_r register of each PE

                if(mem_i_ready) begin
                    // reset z cache
                    for(i=0; i<COMPUTE_COL_NUM; i++) begin
                        z_cache_w[i] = 0;
                    end


                    if(a_row_idx_r == 5'd31 && b_col_idx_r == 5'd0) begin
                        gemm_state_w = S_GEMM_IDLE;
                        busy_w = 1'b0;
                        o_gemm_irq = 1'b1; // raise an interrupt to signal the completion of the computation
                    end
                    else if(a_row_idx_r == 5'd31) begin // after writing the result of the current row of matrix A and 4 columns of matrix B, move to the next 4 columns of matrix B and reset row index
                        gemm_state_w = S_GEMM_READ_DATA_B;
                        a_row_idx_w = 5'd0; // reset row index

                        mem_o_addr = {3'd1, b_col_idx_r, 6'd0}; // address of the row to read, each row is 32 bytes (256 bits) and there are 64 rows
                        mem_o_size = 3'd7; // size of the data to read,
                        mem_o_read = 1'b1;
                    end
                    else begin // move to the next row of matrix A
                        gemm_state_w = S_GEMM_READ_DATA_A;
                        a_row_idx_w = a_row_idx_r + 1; // move to the next row
                        mem_o_addr = {3'd0, a_row_idx_w, 6'd0}; 
                        mem_o_size = A_READ_SIZE; // size of the data to read, 2^4 = 16 bytes. read 8 elements 
                        mem_o_read = 1'b1;
                    end
                    
                end
            end
            default: 
        endcase
    end

    // mac
    always_comb begin
        for(i=0; i<COMPUTE_COL_NUM; i++) begin
            for(j=0; j<32/COMPUTE_COL_NUM; j++) begin
                fp_mul_in_0[i*8+j] = a_cache_r[j][DATA_WIDTH-1:0];
                fp_mul_in_1[i*8+j] = b_cache_r[i][j][DATA_WIDTH-1:0];
            end

            // sum up 8 fp_mul_out and z_cache_r to get the new z_cache_w
            // 1st stage of addition tree, add the 8 fp_mul_out to get 4 intermediate results
            fp_add_in_0[8*i] = fp_mul_out[8*i];
            fp_add_in_1[8*i] = fp_mul_out[8*i+1];
            fp_add_in_0[8*i+1] = fp_mul_out[8*i+2];
            fp_add_in_1[8*i+1] = fp_mul_out[8*i+3];
            fp_add_in_0[8*i+2] = fp_mul_out[8*i+4];
            fp_add_in_1[8*i+2] = fp_mul_out[8*i+5];
            fp_add_in_0[8*i+3] = fp_mul_out[8*i+6];
            fp_add_in_1[8*i+3] = fp_mul_out[8*i+7];
            // 2nd stage of addition tree, add the 4 intermediate results to get 2 results
            fp_add_in_0[8*i+4] = fp_add_out[8*i];
            fp_add_in_1[8*i+4] = fp_add_out[8*i];
            fp_add_in_0[8*i+5] = fp_add_out[8*i+1];
            fp_add_in_1[8*i+5] = fp_add_out[8*i+1];
            // 3rd stage of addition tree, add the 2 results to get the final result
            fp_add_in_0[8*i+6] = fp_add_out[8*i+4];
            fp_add_in_1[8*i+6] = fp_add_out[8*i+5];

            // add the result to the previous value in z_cache
            fp_add_in_0[8*i+7] = fp_add_out[8*i+6];
            fp_add_in_1[8*i+7] = z_cache_r[i];
        end
    end
  ///////////////////////////module instantiation///////////////////////////
    // PMU
    logic   PSW_NSLEEPIN, ISO_EN;
    logic   PSW_ACK;

    GEMM_pmu u_GEMM_pmu (
        .i_clk   (i_clk),
        .i_rst_n (i_rst_n),

        .test_mode (),

        .GEMM_PSW_NSLEEPIN (PSW_NSLEEPIN),
        .GEMM_ISO_EN       (ISO_EN),
        .GEMM_PSW_ACK      (PSW_ACK)
    );

    // ahb slave and master
    ahb_slave #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_ahb_slave (
        .i_clk   (i_clk),
        .i_rst_n (i_rst_n),

        // interconnect interface
        .HADDR   (i_gemm_s_HADDR),
        .HWRITE  (i_gemm_s_HWRITE),
        .HSIZE   (i_gemm_s_HSIZE),
        .HBURST  (i_gemm_s_HBURST),
        .HTRANS  (i_gemm_s_HTRANS),
        .HWDATA  (i_gemm_s_HWDATA),
        .HREADY  (o_gemm_s_HREADY),
        .HRESP   (o_gemm_s_HRESP),
        .HRDATA  (o_gemm_s_HRDATA),
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
        .HADDR   (o_gemm_m_HADDR),
        .HWRITE  (o_gemm_m_HWRITE),
        .HSIZE   (o_gemm_m_HSIZE),
        .HBURST  (o_gemm_m_HBURST),
        .HTRANS  (o_gemm_m_HTRANS),
        .HWDATA  (o_gemm_m_HWDATA),
        .HREADY  (i_gemm_m_HREADY),
        .HRESP   (i_gemm_m_HRESP),
        .HRDATA  (i_gemm_m_HRDATA),

        // from core
        .ahb_addr   (mem_o_addr),
        .ahb_size   (mem_o_size),
        .ahb_wdata  (mem_o_wdata),
        .ahb_write  (mem_o_write),
        .ahb_rdata  (mem_i_rdata),
        .ahb_read   (mem_o_read),
        .ahb_ready  (mem_i_ready)
    );

    generate
        for(gi=0;gi<32;gi=gi+1)begin: gen_add
            DW_fp_add #(
                .sig_width (10),
                .exp_width (5),
                .ieee_compliance (1)
            ) u_fp_add (
                .a (fp_add_in_0[gi]),
                .b (fp_add_in_1[gi]),
                .rnd(0),
                .z(fp_addsub_out[gi]),
                .status()
            );
        end
        for(gi=0;gi<16;gi=gi+1)begin: gen_mul
            DW_fp_mul #(
                .sig_width (10),
                .exp_width (5),
                .ieee_compliance (1)
            ) u_fp_mul (
                .a (fp_mul_in_0[gi]),
                .b (fp_mul_in_1[gi]),
                .rnd(0),
                .z(fp_mul_out[gi]),
                .status()
            );
        end
    endgenerate

  ///////////////////////////sequential logic///////////////////////////  
    always_ff @( posedge i_clk or negedge i_rst_n ) begin
        if ( !i_rst_n ) begin
            gemm_state_r <= S_GEMM_IDLE;
            a_row_idx_r <= 5'd0;
            b_col_idx_r <= 5'd0;
            a_row_block_idx_r <= 2'd0;
            busy_r <= 1'b0;

            for(i=0; i<32/COMPUTE_COL_NUM; i++) begin
                a_cache_r[i] <= '0;
            end
            for(i=0; i<COMPUTE_COL_NUM; i++) begin
                for(j=0; j<32; j++) begin
                    b_cache_r[i][j] <= '0;
                end
            end
            for(i=0; i<COMPUTE_COL_NUM; i++) begin
                z_cache_r[i] <= '0;
            end
        end
        else begin
            gemm_state_r <= gemm_state_w;
            a_row_idx_r <= a_row_idx_w;
            b_col_idx_r <= b_col_idx_w;
            a_row_block_idx_r <= a_row_block_idx_w;
            busy_r <= busy_w;

            for(i=0; i<32/COMPUTE_COL_NUM; i++) begin
                a_cache_r[i] <= a_cache_w[i];
            end
            for(i=0; i<COMPUTE_COL_NUM; i++) begin
                for(j=0; j<32; j++) begin
                    b_cache_r[i][j] <= b_cache_w[i][j];
                end
            end
            for(i=0; i<COMPUTE_COL_NUM; i++) begin
                z_cache_r[i] <= z_cache_w[i];
            end
        end
    end
endmodule


module GEMM_pmu (
    input   logic   i_clk,
    input   logic   i_rst_n,

    input   logic   test_mode,

    output  logic   GEMM_PSW_NSLEEPIN,
    input   logic   GEMM_PSW_ACK,
    output  logic   GEMM_ISO_EN
);

    // when test_mode is 1, PSW should be always closed and ISO should be always disabled
    
endmodule
