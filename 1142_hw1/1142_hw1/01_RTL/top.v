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
wire [12:0] byte_counter_minus1;
reg [1:0] channel_counter_w,channel_counter_r;

// input
reg [7:0] i_data_r[0:3];
reg i_valid_r;
// output
reg o_valid_w, o_valid_r;
reg [7:0] o_data_w, o_data_r;

// sram control signals
reg [6:0] addr[0:23];
reg cen [0:23];
reg wen [0:23];
reg [63:0] sram_in [0:23];
wire [63:0] sram_out [0:23];

reg [4:0] sram_index;

reg [63:0] bitmask_buffer_w[0:3], bitmask_buffer_r[0:3];
reg [63:0] data_buffer_w[0:3], data_buffer_r[0:3];
reg [12:0] data_counter_w[0:3], data_counter_r[0:3];

genvar gi;
integer i,j;
// ----------------------------------------------------
//            Combinational Assignments
// ----------------------------------------------------
assign o_valid = o_valid_r;
assign o_data = o_data_r;

assign byte_counter_minus1 = byte_counter_r - 13'd1;
// ----------------------------------------------------
//                Module Instantiation
// ----------------------------------------------------
generate
    for(gi = 0; gi < 24; gi = gi + 1) begin : gen_sram
        TS1N16ADFPCLLLVTA128X64M4SWSHOD sram(
            .A (addr[gi]),
            .CEB (cen[gi]), // active low
            .CLK (i_clk),
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
always @(*) begin
    state_w = state_r;
    byte_counter_w = byte_counter_r;
    channel_counter_w = channel_counter_r;
    sram_index = 0;
    o_data_w = 0;
    o_valid_w = 0;
    for(i=0; i<4; i=i+1) begin
        bitmask_buffer_w[i] = bitmask_buffer_r[i];
        data_buffer_w[i] = data_buffer_r[i];
        data_counter_w[i] = data_counter_r[i];
    end
    for(i=0; i<24; i=i+1) begin
        cen[i] = 1; // default: not selected
        wen[i] = 1; // default: read
        addr[i] = 0;
        sram_in[i] = 0;
    end

    case(state_r)
        S_LOAD: begin
            if(i_valid_r) begin
                byte_counter_w = byte_counter_r + 1;
                if(byte_counter_r == 13'd8191) begin
                    byte_counter_w = 0;
                    state_w = S_OUTPUT;
                end 

                // bitmask
                for(i=0; i<4; i=i+1) begin
                    bitmask_buffer_w[i] = {bitmask_buffer_r[i][62:0], (i_data_r[i]>8'd10)?1'b1:1'b0};
                end
                if(byte_counter_r[5:0] == 6'd63) begin
                    for(i=0; i<4; i=i+1) begin
                        cen[6*i] = 0; // select the SRAM
                        wen[6*i] = 0; // write mode
                        addr[6*i] = byte_counter_r[12:6]; // word address
                        sram_in[6*i] = bitmask_buffer_w[i];
                    end
                end
                // data
                for(i=0; i<4; i=i+1) begin
                    if(i_data_r[i] > 8'd10) begin
                        data_buffer_w[i] = {data_buffer_r[i][55:0], i_data_r[i]};
                        data_counter_w[i] = data_counter_r[i] + 1;
                        if(data_counter_r[i][2:0] == 3'd7) begin
                            cen[6*i+(data_counter_r[i][12:10])+1'd1] = 0; // select the SRAM
                            wen[6*i+(data_counter_r[i][12:10])+1'd1] = 0; // write mode
                            addr[6*i+(data_counter_r[i][12:10])+1'd1] = data_counter_r[i][9:3]; // word address
                            sram_in[6*i+(data_counter_r[i][12:10])+1'd1] = data_buffer_w[i];
                        end else if(byte_counter_r == 13'd8191) begin
                            cen[6*i+(data_counter_r[i][12:10])+1'd1] = 0; // select the SRAM
                            wen[6*i+(data_counter_r[i][12:10])+1'd1] = 0; // write mode
                            addr[6*i+(data_counter_r[i][12:10])+1'd1] = data_counter_r[i][9:3]; // word address
                            sram_in[6*i+(data_counter_r[i][12:10])+1'd1] = data_buffer_w[i]<<((3'd7-(data_counter_r[i][2:0]))*8); // shift the remaining data to the correct position
                        end
                    end else if(byte_counter_r == 13'd8191) begin
                        cen[6*i+(data_counter_r[i][12:10])+1'd1] = 0; // select the SRAM
                        wen[6*i+(data_counter_r[i][12:10])+1'd1] = 0; // write mode
                        addr[6*i+(data_counter_r[i][12:10])+1'd1] = data_counter_r[i][9:3]; // word address
                        sram_in[6*i+(data_counter_r[i][12:10])+1'd1] = data_buffer_r[i]<<((4'd8-(data_counter_r[i][2:0]))*8); // shift the remaining data to the correct position
                    end
                end
            end
        end
        S_OUTPUT: begin
            sram_index = 6*channel_counter_r + byte_counter_r[12:10];
            cen[sram_index] = 0; // select the SRAM
            wen[sram_index] = 1; // read mode
            addr[sram_index] = byte_counter_r[9:3]; // word address

            // update counters
            byte_counter_w = byte_counter_r + 1;
            if(byte_counter_r == data_counter_r[channel_counter_r]+13'd1024) begin
                byte_counter_w = 0;
                channel_counter_w = channel_counter_r + 1;
                if(channel_counter_w == 2'd3) begin
                    state_w = S_LOAD;
                    channel_counter_w = 0;
                end
            end
            
            // output logic
            if(byte_counter_r==0 && channel_counter_r==0) begin
                o_valid_w = 0;
                o_data_w = 0;
            end else begin
                o_valid_w = 1;
                o_data_w = sram_out[sram_index][(3'd7-(byte_counter_minus1[2:0]))*8 +: 8];
            end
        end
    endcase
end
// ----------------------------------------------------
//                Sequential Logic
// ----------------------------------------------------
always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        state_r <= S_LOAD;
        byte_counter_r <= 0;
        channel_counter_r <= 0;
        o_valid_r <= 0;
        o_data_r <= 0;
        i_valid_r <= 0;
        for(i=0; i<4; i=i+1) begin
            i_data_r[i] <= 0;
            bitmask_buffer_r[i] <= 0;
            data_buffer_r[i] <= 0;
            data_counter_r[i] <= 0;
        end
    end else begin
        state_r <= state_w;
        byte_counter_r <= byte_counter_w;
        channel_counter_r <= channel_counter_w;
        o_valid_r <= o_valid_w;
        o_data_r <= o_data_w;
        for(i=0; i<4; i=i+1) begin
            bitmask_buffer_r[i] <= bitmask_buffer_w[i];
            data_buffer_r[i] <= data_buffer_w[i];
            data_counter_r[i] <= data_counter_w[i];
        end
        i_data_r[0] <= i_data_0;
        i_data_r[1] <= i_data_1;
        i_data_r[2] <= i_data_2;
        i_data_r[3] <= i_data_3;
        i_valid_r <= i_valid;
    end
end
endmodule
