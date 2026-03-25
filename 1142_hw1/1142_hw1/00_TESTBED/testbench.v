`timescale 1ns/10ps
`define CYCLE 	    1.5
`define MAX_CYCLE   1000000
`define RST_DELAY   2.0

// Matches Python script: 4 channels, 8192 elements each
`define CHANNEL     4
`define IN_LEN      8192
`define IN_WIDTH    8

`define OUT_LEN     40000 // theoretical maximum is 36864 when 0% sparsity (8192*4*1.125)
`define OUT_WIDTH   8

// -------------------------------------------------------------------------
// File Selection Logic
// -------------------------------------------------------------------------
`ifdef VCS
    `ifdef p0
        `define IDATA       "../00_TESTBED/p0/pat0.dat"
        `define ODATA       "../00_TESTBED/p0/gold0.dat"
    `elsif p1
        `define IDATA       "../00_TESTBED/p1/pat1.dat"
        `define ODATA       "../00_TESTBED/p1/gold1.dat"
    `elsif p2
        `define IDATA       "../00_TESTBED/p2/pat2.dat"
        `define ODATA       "../00_TESTBED/p2/gold2.dat"
    `elsif p3
        `define IDATA       "../00_TESTBED/p3/pat3.dat"
        `define ODATA       "../00_TESTBED/p3/gold3.dat"
    `elsif p4
        `define IDATA       "../00_TESTBED/p4/pat4.dat"
        `define ODATA       "../00_TESTBED/p4/gold4.dat"
    `else
        `define IDATA       "../00_TESTBED/p0/pat0.dat"
        `define ODATA       "../00_TESTBED/p0/gold0.dat"
    `endif
`else
    `ifdef p0
        `define IDATA       "pat0.dat"
        `define ODATA       "gold0.dat"
    `elsif p1
        `define IDATA       "pat1.dat"
        `define ODATA       "gold1.dat"
    `elsif p2
        `define IDATA       "pat2.dat"
        `define ODATA       "gold2.dat"
    `elsif p3
        `define IDATA       "pat3.dat"
        `define ODATA       "gold3.dat"
    `else
        `define IDATA       "pat0.dat"
        `define ODATA       "gold0.dat"
    `endif
`endif

module testbench #(
    parameter IN_WIDTH  = `IN_WIDTH,
    parameter OUT_WIDTH = `OUT_WIDTH,
    parameter CHANNEL   = `CHANNEL
) ();

    // -------------------------------------------------------------------------
    // Signals & Memories
    // -------------------------------------------------------------------------
    wire                     clk;
    wire                     rst;
    wire                     rst_n;
    reg                      in_valid;
    wire                     in_ready;
    
    // Input is 32 bits wide (4 channels * 8 bits) to match 'patX.dat'
    reg [CHANNEL*IN_WIDTH-1:0] in_data; 

    wire                     out_valid;
    wire [OUT_WIDTH-1:0]     out_data; // 8-bit serial output

    reg [CHANNEL*IN_WIDTH-1:0] in_vec [0:`IN_LEN-1];  // Stores input patterns
    reg [OUT_WIDTH-1:0]        golden [0:`OUT_LEN-1]; // Stores golden 8-bit words
    
    integer out_end;
    integer i, j;
    integer correct, error;
    integer real_golden_len; // to check if out_valid is deasserted prematurely

    // -------------------------------------------------------------------------
    // File Loading
    // -------------------------------------------------------------------------
    initial begin
        $readmemb(`IDATA, in_vec);
        // 1. Initialize golden memory to all 'x' (data validity check)
        for (i=0; i<`OUT_LEN; i=i+1) begin
            golden[i] = 8'bx; 
        end
        $readmemb(`ODATA, golden);

        // 2. Calculate real golden length (number of valid outputs expected)
        real_golden_len = 0;
        i = 0;
        while (i < `OUT_LEN && golden[i] !== 8'bx) begin
            real_golden_len = real_golden_len + 1;
            i = i + 1;
        end
    end

    // -------------------------------------------------------------------------
    // Clock Generator Instantiation
    // -------------------------------------------------------------------------
    clk_gen clk_gen_inst (
        .clk   (clk),
        .rst   (rst),
        .rst_n (rst_n)
    );

    // -------------------------------------------------------------------------
    // Design Under Test (DUT) Instantiation
    // -------------------------------------------------------------------------
    top u_top (
        .i_clk            (clk),
        .i_rst_n          (rst_n),
        .i_valid          (in_valid),
        // Mapping 32-bit input to 8-bit ports.
        .i_data_0         (in_data[31:24]), // Ch0
        .i_data_1         (in_data[23:16]), // Ch1
        .i_data_2         (in_data[15:8] ), // Ch2
        .i_data_3         (in_data[7:0]  ), // Ch3
        
        .o_data           (out_data),       // 8-bit output port
        .o_valid          (out_valid)
    );

    // -------------------------------------------------------------------------
    // Waveform Dumping
    // -------------------------------------------------------------------------
    initial begin
        $fsdbDumpfile("top.fsdb");
        $fsdbDumpvars(0, testbench, "+power");
    end

    `ifdef SDF
        initial begin
            $sdf_annotate("top_syn.sdf", u_top);
        end
    `endif

    // -------------------------------------------------------------------------
    // Input Driver
    // -------------------------------------------------------------------------
    initial begin
        in_valid = 0;
        in_data  = 0;
        
        // Wait for reset to finish
        wait (rst_n === 1'b0);
        wait (rst_n === 1'b1);
        @(posedge clk);

        $display("----------------------------------------------");
        $display("-                   START                    -");
        $display("----------------------------------------------");
        $display("Pattern File: %s", `IDATA);

        // Feed Data
        i = 0;
        while (i < `IN_LEN) begin
            @(negedge clk); // Change input at negedge
            in_data  = in_vec[i];
            in_valid = 1'b1;
            i = i + 1;
        end
        
        @(negedge clk); //hold last output for one cycle
        in_valid = 0; //deassert valid after last input
        in_data  = 0;
    end

    // -------------------------------------------------------------------------
    // Output Verification
    // -------------------------------------------------------------------------
    initial begin
        out_end = 0; // Flag to indicate end of output checking
        correct = 0; 
        error   = 0;
        j       = 0;

        // Wait for Reset
        wait (rst_n === 1'b0);
        wait (rst_n === 1'b1);
        //wait (in_valid === 1'b0); // o_valid can be asserted at any time)
        
        // Wait for first valid output (should only be raised once, and stays high)
        wait (out_valid); 
        
        // Compare Cycle-by-Cycle (sample at negedge)
        while (out_valid && j < `OUT_LEN) begin //immediate exit if out_valid deasserted
            @(negedge clk);
            if (out_valid) begin //double check valid at negedge
                if (out_data !== golden[j]) begin
                    error = error + 1;
                    $display("Error at the %d-th byte!", j);
                    $display("Golden=%b, Yours=%b", golden[j], out_data);
                end else begin
                    correct = correct + 1;
                end
            end
            j = j + 1;
        end
        
        // check if we have received more outputs than expected
        if (j === `OUT_LEN) begin //j should never exceed 36864, something is wrong if the previous loop ran to the end
                $display("Error: Overflow! Testbench received more outputs than expected (expected %d), did you forget to deassert out_valid?", real_golden_len);
                error = error + 1;
        end
        else if (golden[j] !== 8'bx) begin 
             $display("Error: Underrun! DUT stopped at %d-th byte (expected %d), but testbench expected more data, did you deassert out_valid prematurely?", j, real_golden_len);
             error = error + 1;
        end
        out_end = 1;
    end

    // -------------------------------------------------------------------------
    // Result Reporting
    // -------------------------------------------------------------------------
    initial begin
        // Wait for output verification to complete
        wait (out_end); 
        
        if (error === 0) begin
            $display("\n----------------------------------------------");
            $display("-                 ALL PASS!                  -");
            $display("----------------------------------------------");
        end else begin
            $display("\n----------------------------------------------");
            $display("-                 FAIL!                      -");
            $display("  Total Errors: %d out of %d bytes", error, real_golden_len);
            $display("----------------------------------------------");
        end

        # (2 * `CYCLE);
        $finish;
    end

endmodule

// -------------------------------------------------------------------------
// Clock Generator
// -------------------------------------------------------------------------
module clk_gen(
    output reg clk,
    output reg rst,
    output reg rst_n
);

    always #(`CYCLE/2.0) clk = ~clk;

    initial begin
        clk = 1'b1;
        //rst = 1'b0; rst_n = 1'b1; #(              0.25  * `CYCLE);
        rst = 1'b1; rst_n = 1'b0; #((`RST_DELAY)        * `CYCLE); //assert reset at t = 0
        rst = 1'b0; rst_n = 1'b1; #(         `MAX_CYCLE * `CYCLE);
        $display("------------------------");
        $display("Error! Runtime exceeded!");
        $display("------------------------");
        $finish; //failsafe 
    end
endmodule
