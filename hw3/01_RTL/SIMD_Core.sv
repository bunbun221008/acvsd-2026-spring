module SIMD_Core #(
    parameter   DATA_WIDTH = 16
  )(
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
        S_SIMD_READ_DATA_A,
        S_SIMD_READ_DATA_B,
        S_SIMD_COMPUTE,
        S_SIMD_WRITE
     } simd_state;
  ///////////////////////////////reg and wire declarations//////////////////////////////
    // state machine
    simd_state simd_state_w, simd_state_r;
    logic [5:0] row_idx_w, row_idx_r; // index of the row being processed, 6 bits wide to support up to 64 rows
    logic [3:0] inst_idx_w, inst_idx_r; // index of the instruction being executed, 4 bits wide to support up to 16 instructions
    // config register
    logic busy_w, busy_r; 

    // PE
    logic [15:0][3:0][DATA_WIDTH-1:0] pe_reg_w, pe_reg_r; // 16 pe, each pe has 4 registers, each register is DATA_WIDTH bits wide
    logic [DATA_WIDTH-1:0] pe_inst_w, pe_inst_r; // instruction for PE, 16 bits wide
    logic pe_valid_w, pe_valid_r; // whether the instruction for PE is valid
    logic [1:0] pe_store_reg_idx_w, pe_store_reg_idx_r; // which register of PE to store the result, 2 bits wide to support up to 4 registers

    logic [1:0] rd, rs1, rs2; // instruction fields, 2 bits wide to support up to 4 registers   
    logic [15:0][DATA_WIDTH-1:0] fp_addsub_in_0, fp_addsub_in_1, fp_addsub_out;
    logic fp_addsub_op; // 0 for add, 1 for sub
    logic [15:0][DATA_WIDTH-1:0] fp_mul_in_0, fp_mul_in_1, fp_mul_out;
    logic [15:0][DATA_WIDTH-1:0] fp_div_in_0, fp_div_in_1, fp_div_out;

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

    integer i, j;
    genvar gi, gj;
  ///////////////////////////////assignments/////////////////////////////
    assign rd = pe_inst_r[11:10];
    assign rs1 = pe_inst_r[9:8];
    assign rs2 = pe_inst_r[7:6];

  ///////////////////////////////combinational logic//////////////////////////////
    always_comb begin : state_machine
        simd_state_w = simd_state_r;
        row_idx_w = row_idx_r;
        inst_idx_w = inst_idx_r;

        busy_w = busy_r; // busy
        o_simd_irq = 1'b0; // interrupt signal, should be set to 1 when the computation is done

        // pe
        pe_valid_w = pe_valid_r;
        pe_inst_w = pe_inst_r;
        for(i=0; i<16; i++) begin
            for(j=0; j<4; j++) begin
                pe_reg_w[i][j] = pe_reg_r[i][j];
            end
        end
        pe_store_reg_idx_w = pe_store_reg_idx_r;

        fp_addsub_op = 1'b0; // default to add
        for(i=0; i<16; i++) begin
            fp_addsub_in_0[i] = pe_reg_r[i][rs1];
            fp_addsub_in_1[i] = pe_reg_r[i][rs2];
            fp_mul_in_0[i] = pe_reg_r[i][rs1];
            fp_mul_in_1[i] = pe_reg_r[i][rs2];
            fp_div_in_0[i] = pe_reg_r[i][rs1];
            fp_div_in_1[i] = pe_reg_r[i][rs2];
        end

        
        
        // ahb interface
        tb_o_ready = 1'b1;
        tb_o_rdata = {1008'd0, busy_r, 15'd0};

        mem_o_addr = 14'd0;
        mem_o_size = 3'd0;
        mem_o_wdata = 1024'd0;
        mem_o_write = 1'b0;
        mem_o_read = 1'b0;

        case (simd_state_r)
            S_SIMD_IDLE: begin
                row_idx_w = 6'd0;
                inst_idx_w = 4'd0;

                if(tb_i_write && tb_i_addr[13:0] == 14'h2000 && tb_i_wdata[15:0] == 16'h1) begin
                    busy_w = 1'b1;
                end
                if((busy_r || busy_w) && mem_i_ready) begin
                    simd_state_w = S_SIMD_READ_DATA_A;
                    // read a row of matrix A
                    mem_o_addr = {3'd1, row_idx_r, 5'd0}; // address of the row to read, each row is 32 bytes (256 bits) and there are 64 rows
                    mem_o_size = 3'd6; // size of the data to read, 2^6 = 64 bytes
                    mem_o_read = 1'b1;
                    for(i=0; i<16; i++) begin
                        for(j=0; j<4; j++) begin
                            pe_reg_w[i][j] = 0;
                        end
                    end
                end
            end
            S_SIMD_READ_DATA_A: begin
                if(mem_i_ready) begin
                    simd_state_w = S_SIMD_READ_DATA_B;
                    // write the row of matrix A to PE registers
                    for(i=0; i<16; i++) begin
                        pe_reg_w[i][0] = mem_i_rdata[i*16 +: 16];
                    end
                    // read a row of matrix B
                    mem_o_addr = {3'd2, row_idx_r, 5'd0}; // address of the row to read, each row is 32 bytes (256 bits) and there are 64 rows
                    mem_o_size = 3'd6; // size of the data to read, 2^6 = 64 bytes
                    mem_o_read = 1'b1;
                end
            end 
            S_SIMD_READ_DATA_B: begin
                if(mem_i_ready) begin
                    simd_state_w = S_SIMD_COMPUTE;
                    // write the row of matrix B to PE registers
                    for(i=0; i<16; i++) begin
                        pe_reg_w[i][1] = mem_i_rdata[i*16 +: 16];
                    end
                    // read a instruction for PE
                    inst_idx_w = 4'd1;
                    mem_o_addr = {3'd0, row_idx_r, 5'd0}; // address of the row to read, each row is 32 bytes (256 bits) and there are 64 rows
                    mem_o_size = 3'd2; // size of the data to read, 2^6 = 64 bytes
                    mem_o_read = 1'b1;
                end
            end 
            S_SIMD_COMPUTE: begin
                if(mem_i_ready) begin
                    pe_valid_w = 1'b1;
                    pe_inst_w = mem_i_rdata[15:0]; // instruction for PE is stored in the lowest 16 bits of the data read from memory
                    
                    // read a instruction for PE
                    inst_idx_w = inst_idx_r + 1;
                    mem_o_addr = {3'd0, row_idx_r, inst_idx_r, 1'd0}; // address of the row to read, each row is 32 bytes (256 bits) and there are 64 rows
                    mem_o_size = 3'd2; // size of the data to read, 2^6 = 64 bytes
                    mem_o_read = 1'b1;

                    if(inst_idx_r == 4'd0 || (pe_valid_r && pe_inst_r == 4'd15)) begin // after reading the last instruction OR see the STORE instruction, go to write state
                        simd_state_w = S_SIMD_WRITE;
                        mem_o_read = 1'b0; // stop reading instructions
                        inst_idx_w = 4'd0; // reset instruction index

                        // write the result of the computation to memory
                        mem_o_addr = {3'd1, row_idx_r, 5'd0}; // address of the row to write, each row is 32 bytes (256 bits) and there are 64 rows
                        mem_o_size = 3'd6; // size of the data to write, 2^6 = 64 bytes
                        mem_o_write = 1'b1;
                    end
                end

                // pe
                if(pe_valid_r) begin
                    case (pe_inst_r[15:12]) // opcode is stored in the lowest 4 bits of the instruction
                        4'd0: begin // ADD
                            for(i=0; i<16; i++) begin
                                pe_reg_w[i][rd] = pe_reg_r[i][rs1] + pe_reg_r[i][rs2]; 
                            end
                        end
                        4'd1: begin // SUB
                            for(i=0; i<16; i++) begin
                                pe_reg_w[i][rd] = pe_reg_r[i][rs1] - pe_reg_r[i][rs2]; 
                            end
                        end
                        4'd2: begin // MUL
                            for(i=0; i<16; i++) begin
                                pe_reg_w[i][rd] = pe_reg_r[i][rs1] * pe_reg_r[i][rs2]; 
                            end
                        end
                        4'd3: begin // Less Than
                            for(i=0; i<16; i++) begin
                                pe_reg_w[i][rd] = (pe_reg_r[i][rs1] < pe_reg_r[i][rs2]) ? 16'h5555: 16'hAAAA; // if less than, write 0x5555 to the register, otherwise write 0xAAAA
                            end
                        end
                        4'd4: begin // Shift Left
                            for(i=0; i<16; i++) begin
                                pe_reg_w[i][rd] = pe_reg_r[i][rs1] << pe_reg_r[i][rs2][3:0]; 
                            end
                        end
                        4'd5: begin // Arith Shift Right
                            for(i=0; i<16; i++) begin
                                pe_reg_w[i][rd] = pe_reg_r[i][rs1] >>> pe_reg_r[i][rs2][3:0]; 
                            end
                        end
                        4'd6: begin // Bitwise NOT
                            for(i=0; i<16; i++) begin
                                pe_reg_w[i][rd] = ~pe_reg_r[i][rs1]; 
                            end
                        end
                        4'd7: begin // Bitwise OR
                            for(i=0; i<16; i++) begin
                                pe_reg_w[i][rd] = pe_reg_r[i][rs1] | pe_reg_r[i][rs2]; 
                            end
                        end
                        4'd8: begin // Bitwise AND
                            for(i=0; i<16; i++) begin
                                pe_reg_w[i][rd] = pe_reg_r[i][rs1] & pe_reg_r[i][rs2]; 
                            end
                        end
                        4'd9: begin // Bitwise XOR
                            for(i=0; i<16; i++) begin
                                pe_reg_w[i][rd] = pe_reg_r[i][rs1] ^ pe_reg_r[i][rs2]; 
                            end
                        end
                        4'd10: begin // FP ADD
                            fp_addsub_op = 1'b0; // set to add
                            for(i=0; i<16; i++) begin
                                pe_reg_w[i][rd] = fp_addsub_out[i]; 
                            end
                        end
                        4'd11: begin // FP SUB
                            fp_addsub_op = 1'b1; // set to sub
                            for(i=0; i<16; i++) begin
                                pe_reg_w[i][rd] = fp_addsub_out[i];
                            end
                        end
                        4'd12: begin // FP MUL
                            for(i=0; i<16; i++) begin
                                pe_reg_w[i][rd] = fp_mul_out[i];
                            end
                        end
                        4'd13: begin // FP DIV
                            for(i=0; i<16; i++) begin
                                pe_reg_w[i][rd] = fp_div_out[i];
                            end
                        end
                        4'd14: begin // FP Less Than
                            fp_addsub_op = 1'b1; // set to sub, we can use the result of the subtraction to determine whether it is less than or not
                            for(i=0; i<16; i++) begin
                                pe_reg_w[i][rd] = (fp_addsub_out[i][DATA_WIDTH-1]) ? 16'h5555: 16'hAAAA; // if less than, the result of the subtraction will be negative, so we can check the sign bit of the result to determine whether it is less than or not. If less than, write 0x5555 to the register, otherwise write 0xAAAA
                            end
                        end
                        4'd15: begin // STORE 
                            pe_store_reg_idx_w = rd; // which register to store the result is determined by bits [5:4] of the instruction
                        end
                        default: begin
                            pe_valid_w = 1'b0; // invalid instruction, set valid to 0
                        end
                    endcase
                end 
            end
            S_SIMD_WRITE: begin
                // write the result back to memory
                mem_o_wdata = pe_reg_r[15:0][pe_store_reg_idx_r]; // the result of the computation is stored in the pe_store_reg_idx_r register of each PE

                if(mem_i_ready) begin
                    mem_o_write = 1'b0; // stop writing
                    if(row_idx_r == 6'd63) begin // after writing the last row, go back to idle state
                        simd_state_w = S_SIMD_IDLE;
                        busy_w = 1'b0;
                        o_simd_irq = 1'b1; // raise an interrupt to indicate the completion of the computation
                    end else begin
                        row_idx_w = row_idx_r + 1; // move to the next row

                        simd_state_w = S_SIMD_READ_DATA_A; // read the next row of data
                        mem_o_addr = {3'd1, row_idx_w, 5'd0}; // address of the row to read, each row is 32 bytes (256 bits) and there are 64 rows
                        mem_o_size = 3'd6; // size of the data to read, 2^6 = 64 bytes
                        mem_o_read = 1'b1;
                        for(i=0; i<16; i++) begin
                            for(j=0; j<4; j++) begin
                                pe_reg_w[i][j] = 0;
                            end
                        end
                    end
                end
            end
            default: 
        endcase
    end

    
  ///////////////////////////////module instantiations/////////////////////////////
    // PE
    generate
        for(gi=0;gi<16;gi=gi+1)begin: gen_addsub
            DW_fp_addsub #(
                .sig_width (10),
                .exp_width (5),
                .ieee_compliance (1)
            ) u_fp_add (
                .a (fp_addsub_in_0[gi]),
                .b (fp_addsub_in_1[gi]),
                .rnd(0),
                .op(addsub_op),
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
        for(gi=0;gi<16;gi=gi+1)begin: gen_div
            DW_fp_div #(
                .sig_width (10),
                .exp_width (5),
                .ieee_compliance (1)
            ) u_fp_div (
                .a (fp_div_in_0[gi]),
                .b (fp_div_in_1[gi]),
                .rnd(0),
                .z(fp_div_out[gi]),
                .status()
            );
        end
        // for(gi=0;gi<16;gi=gi+1)begin: gen_lessthan
        //      DW_fp_lessthan #(
        //         .sig_width (10),
        //         .exp_width (5),
        //         .ieee_compliance (1)
        //     ) u_fp_lessthan (
        //         .a (fp_lessthan_in_0[gi]),
        //         .b (fp_lessthan_in_1[gi]),
        //         .rnd(0),
        //         .altb(fp_lessthan_out[gi]),
        //         .status()
        //     );
        // end
    endgenerate

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
    
    // ahb slave and master
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
  
  
  /////////////////////////////// sequential logic/////////////////////////////
    always_ff @( posedge i_clk or negedge i_rst_n ) begin
        if ( !i_rst_n ) begin
            simd_state_r <= S_SIMD_IDLE;
            row_idx_r <= 6'd0;
            inst_idx_r <= 4'd0;
            busy_r <= 1'b0;
            pe_valid_r <= 1'b0;
            pe_inst_r <= 16'd0;
            pe_store_reg_idx_r <= 2'd0;
            for(i=0; i<16; i++) begin
                for(j=0; j<4; j++) begin
                    pe_reg_r[i][j] <= 16'd0;
                end
            end
        end
        else begin
            simd_state_r <= simd_state_w;
            row_idx_r <= row_idx_w;
            inst_idx_r <= inst_idx_w;
            busy_r <= busy_w;
            pe_valid_r <= pe_valid_w;
            pe_inst_r <= pe_inst_w;
            pe_store_reg_idx_r <= pe_store_reg_idx_w;
            for(i=0; i<16; i++) begin
                for(j=0; j<4; j++) begin
                    pe_reg_r[i][j] <= pe_reg_w[i][j];
                end
            end
        end
    end
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
