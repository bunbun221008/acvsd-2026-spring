`timescale 1ns/1ps
`define PERIOD      10.0
`define PERIOD_CORE 10.0
`define MAX_TIME    50000   // Modify to your need
`define ERR_LIMIT   100
`define RST_DELAY   3.0
`define I_DELAY     1.0
`define O_DELAY     0.5

`define SDF_FILE "../04_GATE/top_syn.sdf"

`define DATA_LEN    1024
`define ADDR_LEN    42
`define ADDR_I_FILE "../00_TB/pattern/addr_i.dat"
`define INST_FILE   "../00_TB/pattern/inst.dat"
`define DATA_A_FILE "../00_TB/pattern/data_a.dat"
`define DATA_B_FILE "../00_TB/pattern/data_b.dat"
`ifdef SIMD
    `define ADDR_O_FILE "../00_TB/pattern/addr_o.dat"
    `define DATA_Z_FILE "../00_TB/pattern/data_z_SIMD.dat"
`elsif GEMM
    `define ADDR_O_FILE "../00_TB/pattern/addr_o.dat"
    `define DATA_Z_FILE "../00_TB/pattern/data_z_GEMM.dat"
`endif

module testbench ();

`ifdef FSDB
    initial begin
        $fsdbDumpfile("top.fsdb");
    `ifdef UPF
        $fsdbDumpvars(0, "+all", "+mda", "+power");
    `else
        $fsdbDumpvars(0, "+all", "+mda");
    `endif
    end
`endif

`ifdef SDF
    initial begin
        $display("Annotating with SDF file: %s", `SDF_FILE);
        $sdf_annotate(`SDF_FILE, u_top);
    end
`endif


    // Parameters
    localparam  DATA_WIDTH   = 16;
    localparam  EXP_WIDTH    =  5;
    localparam  FRAC_WIDTH   = 10;
    localparam  UNKNOWN_DATA = {DATA_WIDTH{1'bx}};


    // Data
    logic   [ 14+1+3+10-1 : 0] addr_i [0 : `ADDR_LEN-1];
    logic   [ 14+1+3+10-1 : 0] addr_o [0 : `ADDR_LEN-1];
    logic   [DATA_WIDTH-1 : 0] inst   [0 : `DATA_LEN-1];
    logic   [DATA_WIDTH-1 : 0] data_a [0 : `DATA_LEN-1];
    logic   [DATA_WIDTH-1 : 0] data_b [0 : `DATA_LEN-1];
    logic   [DATA_WIDTH-1 : 0] data_z [0 : `DATA_LEN-1];
    logic   [DATA_WIDTH-1 : 0] data_in  [0 : 3 * `DATA_LEN-1];
    logic   [DATA_WIDTH-1 : 0] data_out [0 : 3 * `DATA_LEN-1];
    logic   [DATA_WIDTH-1 : 0] data_tmp [0 : 3 * `DATA_LEN-1];

    initial begin
        $readmemh(`ADDR_I_FILE, addr_i);
        $readmemh(`INST_FILE, inst);
        $readmemh(`DATA_A_FILE, data_a);
        $readmemh(`DATA_B_FILE, data_b);
    `ifdef DATA_Z_FILE
        $readmemh(`ADDR_O_FILE, addr_o);
        $readmemh(`DATA_Z_FILE, data_z);
    `endif

    `ifdef SIMD
        $display("-- SIMD Mode --");
        data_in  = {inst, data_a, data_b};
        data_out = {inst, data_z, data_b};
    `elsif GEMM
        $display("-- GEMM Mode --");
        data_in  = {data_a, data_b, data_b};
        data_out = {data_a, data_b, data_z};
    `endif
    end


    // TB signals
    integer sim_start, sim_end;
    integer error;
    logic   clk, clk_core, rst, rst_n;

    clk_gen clk_0 (
        .clk      (clk     ),
        .clk_core (clk_core),
        .rst      (rst     ),
        .rst_n    (rst_n   )
    );


    // Design under test
    logic            IRQ, tb_IRQ;
    logic   [  13:0] HADDR, tb_HADDR;
    logic            HWRITE, tb_HWRITE;
    logic   [   2:0] HSIZE, tb_HSIZE;
    logic   [   2:0] HBURST, tb_HBURST;
    logic   [   1:0] HTRANS, tb_HTRANS;
    logic   [1023:0] HWDATA, tb_HWDATA;
    logic            HREADY, tb_HREADY;
    logic            HRESP, tb_HRESP;
    logic   [1023:0] HRDATA, tb_HRDATA;
    logic            test_mode;     // for PMU bypass
    logic            scan_enable;   // for DFT, not used in RTL

    always @(tb_HADDR ) HADDR  <= #(`I_DELAY) tb_HADDR;
    always @(tb_HWRITE) HWRITE <= #(`I_DELAY) tb_HWRITE;
    always @(tb_HSIZE ) HSIZE  <= #(`I_DELAY) tb_HSIZE;
    always @(tb_HBURST) HBURST <= #(`I_DELAY) tb_HBURST;
    always @(tb_HTRANS) HTRANS <= #(`I_DELAY) tb_HTRANS;
    always @(tb_HWDATA) HWDATA <= #(`I_DELAY) tb_HWDATA;
    always @(IRQ   ) tb_IRQ    <= #(`O_DELAY) IRQ;
    always @(HREADY) tb_HREADY <= #(`O_DELAY) HREADY;
    always @(HRESP ) tb_HRESP  <= #(`O_DELAY) HRESP;
    always @(HRDATA) tb_HRDATA <= #(`O_DELAY) HRDATA;

    top #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_top (
        .CLK        (clk     ),
        .CLK_CORE   (clk_core),
        .RST_N      (rst_n   ),
        .IRQ        (IRQ     ),
        .HADDR      (HADDR   ),
        .HWRITE     (HWRITE  ),
        .HSIZE      (HSIZE   ),
        .HBURST     (HBURST  ),
        .HTRANS     (HTRANS  ),
        .HWDATA     (HWDATA  ),
        .HREADY     (HREADY  ),
        .HRESP      (HRESP   ),
        .HRDATA     (HRDATA  ),

        .test_mode (1'b0),  // for PMU bypass
        .scan_enable (1'b0) // for DFT, not used in RTL
    );


    // Tasks
    task automatic AHB_WR (
        input   logic [      14-1 : 0] addr,
        input   logic [       3-1 : 0] size,
        input   logic [      10-1 : 0] length,
        input   logic [1024 * 8-1 : 0] wdata
    );
        integer busy_round;
        logic   [1024 * 8 : 0] tb_data_mask;
        logic   [  1024-1 : 0] tb_data_pipe;
        begin
            busy_round = (length > 1) ? $random() % (length-1) + 1 : 1;
            tb_data_mask  = 0;
            for (int i = 0; i < 2**size; i++)
                tb_data_mask[i * 8 +: 8] = 8'hFF;
            tb_data_pipe = 'x;

            tb_HWRITE = 1'b1;
            tb_HSIZE  = size;
            tb_HBURST = (length > 1) ? 3'b001 : 3'b000; // INCR or SINGLE
            for (int i = 0; i < length; i++) begin
                tb_HADDR = addr + i * 2**size;
                if (i == busy_round) begin
                    tb_HTRANS = 2'b01;  // BUSY
                    tb_data_pipe = 'x;
                    @ (posedge clk);
                    if (tb_HREADY === 1'b1) begin
                        tb_HWDATA = tb_data_pipe;
                    end
                end
                tb_HTRANS = (i == 0) ? 2'b10 : 2'b11;   // NONSEQ : SEQ
                tb_data_pipe = (wdata >> (i * 8 * 2**size)) & tb_data_mask;
                @ (posedge clk);
                while (tb_HREADY !== 1'b1) @ (posedge clk);
                tb_HWDATA = tb_data_pipe;
            end
            tb_HWRITE = 1'b0;
            tb_HTRANS = 2'b00;  // IDLE
            tb_HWDATA = 'x;
            @ (posedge clk);
        end
    endtask

    task automatic AHB_RD (
        input   logic [      14-1 : 0] addr,
        input   logic [       3-1 : 0] size,
        input   logic [      10-1 : 0] length,
        output  logic [1024 * 8-1 : 0] rdata
    );
        integer busy_round;
        integer index_pipe;
        logic   [1024 * 8 : 0] tb_data_mask;
        begin
            rdata = 0;
            busy_round = (length > 1) ? $random() % (length-1) + 1 : 1;
            tb_data_mask  = 0;
            for (int i = 0; i < 2**size; i++)
                tb_data_mask[i * 8 +: 8] = 8'hFF;
            index_pipe = 1024;
            
            tb_HWRITE = 1'b0;
            tb_HSIZE  = size;
            tb_HBURST = (length > 1) ? 3'b001 : 3'b000; // INCR or SINGLE
            for (int i = 0; i < length; i++) begin
                tb_HADDR = addr + i * 2**size;
                if (i == busy_round) begin
                    tb_HTRANS = 2'b01;  // BUSY
                    @ (posedge clk);
                    if (tb_HREADY === 1'b1) begin
                        rdata = rdata | (tb_HRDATA & tb_data_mask) << (index_pipe * 8 * 2**size);
                        index_pipe = 1024;
                    end
                end
                tb_HTRANS = (i == 0) ? 2'b10 : 2'b11;   // NONSEQ : SEQ
                @ (posedge clk);
                while (tb_HREADY !== 1'b1) @ (posedge clk);
                rdata = rdata | ( (tb_HRDATA & tb_data_mask) << (index_pipe * 8 * 2**size) );
                index_pipe = i;
            end
            tb_HWRITE = 1'b0;
            tb_HTRANS = 2'b00;  // IDLE
            @ (posedge clk);
            while (tb_HREADY !== 1'b1) @ (posedge clk);
            rdata = rdata | ( (tb_HRDATA & tb_data_mask) << (index_pipe * 8 * 2**size) );
        end
    endtask

    integer error_dect_en;
    task automatic AHB_ERROR (
        input   logic [14-1 : 0] addr,
        input   logic [ 3-1 : 0] size
    );
        begin
            tb_HADDR  = addr;
            tb_HWRITE = 1'b0;
            tb_HSIZE  = size;
            tb_HBURST = 3'b000;
            tb_HTRANS = 2'b10;  // NONSEQ
            @ (posedge clk);
            while (tb_HREADY !== 1'b1) @ (posedge clk);

            error_dect_en = 0;
            tb_HADDR  = 0;
            @ (posedge clk);
            while (tb_HRESP !== 1'b1) begin
                if (tb_HREADY !== 1'b0) begin
                    $display("[Error] No error response for invalid address %4H at time %0t! Terminating simulation.", addr, $time);
                    #(2 * `PERIOD);
                    $finish;
                end
                @ (posedge clk);
            end

            tb_HTRANS = 2'b00;  // IDLE
            @ (posedge clk);
            if (tb_HREADY !== 1'b1 || tb_HRESP !== 1'b1) begin
                $display("[Error] Incomplete error response for invalid address %4H at time %0t! Terminating simulation.", addr, $time);
                #(2 * `PERIOD);
                $finish;
            end

            tb_HTRANS = 2'b00;  // IDLE
            @ (posedge clk);
            error_dect_en = 1;
        end
    endtask

    task automatic POLLING (
        input   logic [1:0] SIMD_busy,  // 00: expect 0, 11: expect 1, 01: any, 10: skip
        input   logic [1:0] GEMM_busy,  // 00: expect 0, 11: expect 1, 01: any, 10: skip
        input   logic [1:0] MBIST_busy, // 00: expect 0, 11: expect 1, 01: any, 10: skip
        output  logic       idle
    );
        logic   [1024-1 : 0] rdata;
        begin
            idle = 1;

            if (SIMD_busy != 2'b10) begin
                AHB_RD (14'h2002, 3'd1, 10'd1, rdata);
                idle = (rdata[15] !== 1'b0) ? 0 : idle;
                if (( SIMD_busy == 2'b00 && rdata[15] !== 1'b0 ) || ( SIMD_busy == 2'b11 && rdata[15] !== 1'b1 ))
                    $display("[Warning] Unexpected SIMD_busy bit at time %0t!", $time);
            end

            if (GEMM_busy != 2'b10) begin
                AHB_RD (14'h2402, 3'd1, 10'd1, rdata);
                idle = (rdata[15] !== 1'b0) ? 0 : idle;
                if (( GEMM_busy == 2'b00 && rdata[15] !== 1'b0 ) || ( GEMM_busy == 2'b11 && rdata[15] !== 1'b1 ))
                    $display("[Warning] Unexpected GEMM_busy bit at time %0t!", $time);
            end

            if (MBIST_busy != 2'b10) begin
                AHB_RD (14'h2802, 3'd1, 10'd1, rdata);
                idle = (rdata[15] !== 1'b0) ? 0 : idle;
                if (( MBIST_busy == 2'b00 && rdata[15] !== 1'b0 ) || ( MBIST_busy == 2'b11 && rdata[15] !== 1'b1 ))
                    $display("[Warning] Unexpected MBIST_busy bit at time %0t!", $time);
            end

            if ((SIMD_busy | GEMM_busy | MBIST_busy) == 0) begin
                if ($urandom() % 2 == 0) begin
                    tb_HADDR  = ($urandom() % 14'h1400 / 2) * 2 + 14'h2C00;
                    tb_HSIZE  = 3'd1;
                    tb_HTRANS = 2'b00;  // IDLE
                    @ (posedge clk);
                    while (tb_HREADY !== 1'b1) @ (posedge clk);
                    @ (posedge clk);
                    AHB_ERROR ($urandom() % 14'h0400 + 14'h1800, 3'd0);
                end
                else begin
                    tb_HADDR  = $urandom() % 14'h0400 + 14'h1800;
                    tb_HSIZE  = 3'd0;
                    tb_HTRANS = 2'b00;  // IDLE
                    @ (posedge clk);
                    while (tb_HREADY !== 1'b1) @ (posedge clk);
                    @ (posedge clk);
                    AHB_ERROR (($urandom() % 14'h1400 / 2) * 2 + 14'h2C00, 3'd1);
                end
            end
        end
    endtask

    task automatic CHECK (
        input   logic [DATA_WIDTH-1 : 0] golden_data,
        input   logic [DATA_WIDTH-1 : 0] out_data,
        input   logic [        14-1 : 0] addr,
        input   logic exact
    );
        real    golden_val;
        real    out_val;
        real    diff;
        begin
            golden_val = 0;
            out_val    = 0;

            if (exact) begin
                if (golden_data !== out_data) begin
                    if (error < `ERR_LIMIT)
                        $display("[Error] Wrong content at address %4H; expected %4H, get %4H", addr*2, golden_data, out_data);
                    error += 1;
                end
            end
            else begin
                golden_val = fp16_to_real(golden_data);
                out_val    = fp16_to_real(out_data);
                if (golden_val != golden_val) begin
                    if (out_val == out_val) begin
                        if (error < `ERR_LIMIT)
                            $display("[Error] Wrong content at address %4H; expected  NaN, get %4H", addr*2, out_data);
                        error += 1;
                    end
                end
                else if (out_val != out_val) begin
                    if (error < `ERR_LIMIT)
                        $display("[Error] Wrong content at address %4H; expected %4H, get  NaN", addr*2, golden_data);
                    error += 1;
                end
                else begin
                    diff = (out_val - golden_val) / golden_val;
                    diff = (diff < 0) ? -diff : diff;
                    if (diff > 0.05) begin
                        if (error < `ERR_LIMIT)
                            $display("[Error] Wrong content at address %4H; expected %4H, get %4H", addr*2, golden_data, out_data);
                        error += 1;
                    end
                end
            end
        end
    endtask


    // fp16_to_real
    function real fp16_to_real(input logic [15:0] fp16);
        logic           sign;
        logic   [4 : 0] exp;
        logic   [9 : 0] frac;   
        real    fraction_val;
        real    exponent_val;
        real    result;

        begin
            sign = fp16[15];
            exp  = fp16[14:10];
            frac = fp16[9:0];

            exponent_val = 0;
            fraction_val = 0;
            result       = 0;

            if (^fp16 === 1'bx) begin
                result = 0.0 / 0.0;
            end
            else if (exp == 5'h1F && frac != 10'h0) begin
                // Case 1: Infinity or NaN
                result = 0.0 / 0.0;
            end
            else if (exp == 5'h00) begin
                // Case 2: Zero or Subnormal
                if (frac == 10'h0) begin
                    result = 0.0;
                end
                else begin
                // Case 2: Zero or Subnormal
                    exponent_val = 2.0 ** (-14);
                    fraction_val = real'(frac) / 1024.0;
                    result       = exponent_val * fraction_val;
                end
            end
            else begin
                // Case 3: Normal Number
                exponent_val = 2.0 ** (int'(exp) - 15); 
                fraction_val = 1.0 + (real'(frac) / 1024.0);
                result       = exponent_val * fraction_val;
            end
            fp16_to_real = (sign) ? -result : result;
        end
    endfunction


    // Simulation timer
    integer start_time, end_time;
    initial begin
        sim_start = 0;
        sim_end   = 0;

        // init
        wait (rst_n === 1'b0);
        wait (rst_n === 1'b1);
        fork
            repeat (3) @ (posedge clk);
            repeat (3) @ (posedge clk_core);
        join

        @ (posedge clk);
        sim_start = 1;
        start_time = $time;
        $display("*--------------------------------------------*");
        $display("|                   START                    |");
        $display("*--------------------------------------------*");

        wait (sim_end === 1);
        end_time = $time;

        $display("*--------------------------------------------*");
        if (error === 0)
            $display("|                 ALL PASS!                  |");
        else
            $display("|   Wrong! Total Error: %5d                |", error);
        $display("*--------------------------------------------*");
        $display("|   Total sim time: %6d ns                |", (end_time - start_time));
        $display("*--------------------------------------------*");

        # (2 * `PERIOD);
        $finish;
    end

    // Error response
    initial begin
        error_dect_en = 0;
        wait (sim_start);

        error_dect_en = 1;
        forever begin
            @ (posedge clk);
            if (error_dect_en && tb_HRESP !== 1'b0) begin
                $display("[Error] Unexpected error response at time %0t! Terminating simulation.", $time);
                #(2 * `PERIOD); $finish;
            end
            if ((tb_HREADY ^ tb_HREADY) !== 1'b0) begin
                $display("[Error] Unexpected x value for HREADY at time %0t! Terminating simulation.", $time);
                #(2 * `PERIOD); $finish;
            end
            if ((tb_HRESP ^ tb_HRESP) !== 1'b0) begin
                $display("[Error] Unexpected x value for HRESP at time %0t! Terminating simulation.", $time);
                #(2 * `PERIOD); $finish;
            end
            if ((tb_IRQ ^ tb_IRQ) !== 1'b0) begin
                $display("[Warning] Unexpected x value for IRQ at time %0t!", $time);
            end
        end
    end

    // IRQ
    logic             irq_clear;
    logic   [8-1 : 0] irq_pipe;
    always_ff @( posedge clk or posedge irq_clear) begin
        if (irq_clear) begin
            irq_pipe <= 0;
        end else begin
            irq_pipe <= tb_IRQ;
            for (int i = 1; i < 8; i++)
                irq_pipe[i] <= irq_pipe[i-1];
        end
    end

    // Main logic
    integer io_end;
    integer random_wait;
    logic   chip_idle;
    logic   [1024-1 : 0] wdata;
    logic   [1024-1 : 0] rdata;
    logic   [  14-1 : 0] io_addr;
    logic   [   3-1 : 0] io_size;
    logic   [  10-1 : 0] io_length;
    initial begin
        irq_clear = 0;
        io_end    = 0;
        chip_idle = 0;
        wait (rst_n == 1'b0);
        tb_HADDR  = 0;
        tb_HWRITE = 0;
        tb_HSIZE  = 0;
        tb_HBURST = 0;
        tb_HTRANS = 0;
        tb_HWDATA = 0;
        irq_clear = 1;
        wdata     = 0;
        rdata     = 0;
        io_addr   = 0;
        io_size   = 0;
        io_length = 0;
        for (int i = 0; i < 3*`DATA_LEN; i++) data_tmp[i] = 0;
        wait (rst_n == 1'b0);
        irq_clear = 0;
        wait (sim_start);

        // Polling
        $display("-- INIT    --");
        chip_idle = 0;
        while (chip_idle != 1) begin
            POLLING (2'b00, 2'b00, 2'b00, chip_idle);
        end

        // MBIST
    `ifdef MBIST
        $display("-- MBIST   --");
        wdata = 16'h0001;
        AHB_WR(14'h2800, 3'd1, 10'd1, wdata);
        chip_idle = 0;
        while (chip_idle != 1) begin
            random_wait = $urandom() % 8 + 24;
            for (int i = 0; i < random_wait; i++) begin
                @ (posedge clk);
                if (irq_pipe) begin
                    irq_clear = 1; #1; irq_clear = 0;
                    break;
                end
            end
            if ($urandom() % 4 == 0)
                POLLING (2'b00, 2'b00, 2'b01, chip_idle);   // check all
            else
                POLLING (2'b10, 2'b10, 2'b01, chip_idle);   // chack only MBIST
        end
        AHB_RD (14'h2802, 3'd1, 10'd1, rdata);
        $display("[Info] Faulty address at %4H", rdata[13:0]);
        AHB_RD (14'h2804, 3'd1, 10'd1, rdata);
        $display("[Info] Faulty address at %4H", rdata[13:0]);
        AHB_RD (14'h2806, 3'd1, 10'd1, rdata);
        $display("[Info] Faulty address at %4H", rdata[13:0]);

        chip_idle = 0;
        while (chip_idle != 1) POLLING (2'b00, 2'b00, 2'b00, chip_idle);
        @ (posedge clk);
        irq_clear = 1; #1; irq_clear = 0;
    `endif

        // Load data
    `ifdef DATA_Z_FILE
        $display("-- LOAD    --");
        for (int i = 0; i < `ADDR_LEN; i++) begin
            io_addr   = addr_i[i][14 +: 14];
            io_size   = addr_i[i][10 +:  3];
            io_length = addr_i[i][ 0 +: 10];

        `ifdef GEMM
            if (io_addr == 14'h1000)
                break;
        `endif

            wdata = 0;
            for (int j = 0; j < 2**io_size; j++) begin
                wdata[j*8 +: 8] = data_in[(io_addr + j)/2][j[0]*8 +: 8];
            end
            AHB_WR (addr_i[i][14 +: 14], addr_i[i][10 +: 3], addr_i[i][0 +: 10], wdata);
        end
        
        chip_idle = 0;
        while (chip_idle != 1) POLLING (2'b00, 2'b00, 2'b00, chip_idle);
        @ (posedge clk);
        irq_clear = 1; #1; irq_clear = 0;
    `endif

        // Execution
    `ifdef DATA_Z_FILE
        $display("-- EXECUTE --");
        wdata = 16'h0001;
        `ifdef SIMD
            AHB_WR (14'h2000, 3'd1, 10'd1, wdata);
        `elsif GEMM
            AHB_WR (14'h2400, 3'd1, 10'd1, wdata);
        `endif
        chip_idle = 0;
        while (chip_idle != 1) begin
            random_wait = $urandom() % 8 + 24;
            for (int i = 0; i < random_wait; i++) begin
                @ (posedge clk);
                if (irq_pipe) begin
                    irq_clear = 1; #1; irq_clear = 0;
                    break;
                end
            end
            if ($urandom() % 4 == 0)
            `ifdef SIMD
                POLLING (2'b01, 2'b00, 2'b00, chip_idle);   // check all
            `elsif GEMM
                POLLING (2'b00, 2'b01, 2'b00, chip_idle);   // check all
            `endif
            else
            `ifdef SIMD
                POLLING (2'b01, 2'b10, 2'b10, chip_idle);   // chack only SIMD
            `elsif GEMM
                POLLING (2'b10, 2'b01, 2'b10, chip_idle);   // chack only GEMM
            `endif
        end

        chip_idle = 0;
        while (chip_idle != 1) POLLING (2'b00, 2'b00, 2'b00, chip_idle);
        @ (posedge clk);
        irq_clear = 1; #1; irq_clear = 0;
    `endif

        // Store data
    `ifdef DATA_Z_FILE
        $display("-- STORE   --");
        for (int i = 0; i < `ADDR_LEN; i++) begin
            io_addr   = addr_o[i][14 +: 14];
            io_size   = addr_o[i][10 +:  3];
            io_length = addr_o[i][ 0 +: 10];

            AHB_RD (io_addr, io_size, io_length, rdata);
            for (int j = 0; j < 2**io_size; j++) begin
                data_tmp[j >> 1][j[0]*8 +: 8] = rdata[j*8 +: 8];
            end
        end
    `endif

        // Polling
        $display("-- CLEANUP --");
        chip_idle = 0;
        while (chip_idle != 1) begin
            POLLING (2'b00, 2'b00, 2'b00, chip_idle);
        end

        io_end = 1;
    end

    // Check answer
    integer check_addr;
    logic   exact;
    initial begin
        error      = 0;
        wait (io_end);

    `ifdef DATA_Z_FILE
        $display("-- CHECK   --");
        exact = 1;
        check_addr = 0;
        for (int i = 0; i < `DATA_LEN; i++) begin
            CHECK (data_out[check_addr + i], data_tmp[check_addr + i], check_addr + i, exact);
        end

    `ifdef SIMD
        exact = 0;
    `elsif GEMM
        exact = 1;
    `endif
        check_addr = `DATA_LEN;
        for (int i = 0; i < `DATA_LEN; i++) begin
            CHECK (data_out[check_addr + i], data_tmp[check_addr + i], check_addr + i, exact);
        end

    `ifdef SIMD
        exact = 1;
    `elsif GEMM
        exact = 0;
    `endif
        check_addr = 2 * `DATA_LEN;
        for (int i = 0; i < `DATA_LEN; i++) begin
            CHECK (data_out[check_addr + i], data_tmp[check_addr + i], check_addr + i, exact);
        end
    `endif

        sim_end = 1;
    end

endmodule

module clk_gen (
    output  logic clk,
    output  logic clk_core,
    output  logic rst,
    output  logic rst_n
);

    always #(`PERIOD  / 2.0) clk  = ~clk ;
    initial begin
        clk = 1'b0;
        rst = 1'b0; rst_n = 1'b1; #(      0.25 * `PERIOD);
        rst = 1'b1; rst_n = 1'b0; #(`RST_DELAY * `PERIOD);
        rst = 1'b0; rst_n = 1'b1; #(`MAX_TIME);
        $display("*-----------------------------*");
        $display("| Error! Time limit exceeded! |");
        $display("*-----------------------------*");
        $finish;
    end

    real    rand_delay;
    initial begin
        clk_core = 1'b0;
        rand_delay = (($random % 50) / 100.0) * `PERIOD_CORE;
        $display("Random delay for clk_core: %f ns", rand_delay);
        #(rand_delay);

        forever #(`PERIOD_CORE / 2.0) clk_core = ~clk_core;
    end

endmodule
