`timescale 1ns / 1ps

module top(
    input i_clk,
    input i_rst_n,
    input i_valid,
    input [7:0] i_data_0,
    input [7:0] i_data_1, 
    input [7:0] i_data_2, 
    input [7:0] i_data_3,
    output o_valid,
    output [7:0] o_data
);

// ----------------------------------------------------
//               Parameters
// ----------------------------------------------------
localparam S_LOAD = 1'd0;
localparam S_OUTPUT = 1'd1;
// ----------------------------------------------------
//               Signal Declarations
// ----------------------------------------------------
reg state_w,state_r;
reg [12:0] byte_counter_w,byte_counter_r;
reg [1:0] channel_counter_w,channel_counter_r;

// sram control signals
reg [6:0] addr[0:23];
reg cen [0:23];
reg wen [0:23];
reg [63:0] sram_in [0:23];
wire [63:0] sram_out [0:23];
reg [63:0] sram_buffer_w[0:3], sram_buffer_r[0:3];
reg [4:0] sram_index;

genvar gi;
integer i,j;
// ----------------------------------------------------
//            Combinational Assignments
// ----------------------------------------------------
always @(*) begin
    state_w = state_r;
    byte_counter_w = byte_counter_r;
    channel_counter_w = channel_counter_r;
    for(i=0; i<24; i=i+1) begin
        addr[i] = 0;
        cen[i] = 1; // default: not selected
        wen[i] = 1; // default: read
        sram_in[i] = 0;
    end

    case(state_r)
        S_LOAD: begin
            if(i_valid) begin
                byte_counter_w = byte_counter_r + 1;
                if(byte_counter_r == 13'd8191) begin
                    byte_counter_w = 0;
                    state_w = S_OUTPUT;
                end 

                // bitmask
                sram_buffer_w[0] = {sram_buffer_r[0][62:0], (i_data_0>8'd10)};
                sram_buffer_w[1] = {sram_buffer_r[1][62:0], (i_data_1>8'd10)};
                sram_buffer_w[2] = {sram_buffer_r[2][62:0], (i_data_2>8'd10)};
                sram_buffer_w[3] = {sram_buffer_r[3][62:0], (i_data_3>8'd10)}; 
                if(byte_counter_r[5:0] == 6'd63) begin
                    for(i=0; i<4; i=i+1) begin
                        sram_in[6*i] = sram_buffer_w[i];
                        cen[6*i] = 0; // select the SRAM
                        wen[6*i] = 0; // write mode
                        addr[6*i] = byte_counter_r[12:6]; // word address
                    end
                end
                // TODO
                // data
                // sram_index = byte_counter_r[12:6];
                // if(byte_counter_r[5:0] == 6'd63) begin
                //     for(i=0; i<4; i=i+1) begin
                //         sram_in[6*i] = sram_buffer_w[i];
                //         cen[6*i] = 0; // select the SRAM
                //         wen[6*i] = 0; // write mode
                //         addr[6*i] = byte_counter_r[12:6]; // word address
                //     end
                // end
            end
        end
        S_OUTPUT: begin
          
        end
    endcase
end
// ----------------------------------------------------
//                Module Instantiation
// ----------------------------------------------------
generate
    for(gi = 0; gi < 24; gi = gi + 1) begin : gen_sram
        TS1N16ADFPCLLLVTA128X64M4SWSHOD sram(
            .A (addr[gi]),
            .CEB (cen[gi]), // active low
            .CLK (clk),
            .WEB (wen[gi]), // write: low, read: high
            .D (sram_in[gi]),
            .Q (sram_out[gi]),
            .BWEB ({64{1'b0}}),
            .RTSEL (2'b01),
            .WTSEL (2'b01),
            .SLP (1'b0),
            .DSLP (1'b0),
            .SD (1'b0),
            .PUDELAY ()
        );
    end
endgenerate

// ----------------------------------------------------
//                Combinational Logic
// ----------------------------------------------------

// ----------------------------------------------------
//                Sequential Logic
// ----------------------------------------------------
    
endmodule
