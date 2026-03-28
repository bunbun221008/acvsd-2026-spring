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
localparam S_LOAD = 2'd0;
localparam S_OUTPUT = 2'd1;
localparam S_DONE = 2'd2;
// ----------------------------------------------------
//               Signal Declarations
// ----------------------------------------------------
reg [1:0] state_w,state_r;
reg [12:0] byte_counter_w,byte_counter_r;
wire [12:0] byte_counter_minus1;
reg [1:0] channel_counter_w,channel_counter_r;
reg read_flag_w, read_flag_r;

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
reg slp_r[0:23], slp_w[0:23];
reg sd_r[0:23], sd_w[0:23];
reg dslp_r[0:23], dslp_w[0:23];
reg [4:0] sram_index;
reg [4:0] sram_index_last;
// internal buffers
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
            .SLP (slp_r[gi]),
            .DSLP (dslp_r[gi]),
            .SD (sd_r[gi]),
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
    read_flag_w = 0;
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
        slp_w[i] = 0; 
        dslp_w[i] = 0;
        sd_w[i] = 0; // default: keep the current state
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
            // sram sleep logic
            for(i=0; i<4; i=i+1) begin
                for(j=0; j<5; j=j+1) begin
                    if(data_counter_r[i][12:10] != j) begin
                        dslp_w[6*i+j+1] = 1; // put the SRAM to deep sleep
                    end else begin
                        if(byte_counter_r<13'd8188 && data_counter_r[i][2:0] < 3'd5) begin
                            dslp_w[6*i+j+1] = 1; // put the SRAM to sleep
                        end
                    end
                end
                if(byte_counter_r[5:0] < 6'd61) begin
                    dslp_w[6*i] = 1; // put the SRAM to deep sleep
                end
            end
            
        end
        S_OUTPUT: begin
            // sram read logic
            sram_index = 6*channel_counter_r + byte_counter_r[12:10];
            if(byte_counter_r[2:0] == 3'd0) begin
                cen[sram_index] = 0; // select the SRAM
                addr[sram_index] = byte_counter_r[9:3]; // word address
                read_flag_w=1;
            end
            if(read_flag_r) begin
                data_buffer_w[0] = sram_out[sram_index_last];
            end else begin
                data_buffer_w[0] = {data_buffer_r[0][55:0],8'd0};
            end

            // update counters
            byte_counter_w = byte_counter_r + 1;
            if(byte_counter_r == data_counter_r[channel_counter_r]+13'd1023) begin
                byte_counter_w = 0;
                channel_counter_w = channel_counter_r + 1;
                if(channel_counter_r == 2'd3) begin
                    state_w = S_DONE;
                    channel_counter_w = 0;
                end
            end
            
            // output logic
            if(byte_counter_r==0 && channel_counter_r==0) begin
                o_valid_w = 0;
                o_data_w = 0;
                
            end else begin
                o_valid_w = 1;
                o_data_w = data_buffer_w[0][63:56];
            end

            // sram sleep/shut down logic
            for(i=0;i<24;i=i+1) begin
                if(i < sram_index) begin
                    sd_w[i] = 1; // shut down the SRAM that has been read
                end
                if(i > sram_index+2) begin
                    dslp_w[i] = 1; // put the SRAM that is not being read to sleep
                end
                // if(i == sram_index+1 && byte_counter_r <= data_counter_r[channel_counter_r]+13'd1020) begin
                //     dslp_w[i] = 1; // put the next SRAM to sleep if we are sure that we won't read from it in the next 4 cycles (since each SRAM can store 1024 bytes, which is 128 words, and we read 1 word per cycle)
                // end
            end
        end
        S_DONE: begin
            o_valid_w = 0;
            o_data_w = 0;
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
        read_flag_r <= 0;
        sram_index_last <= 0;
        for(i=0; i<4; i=i+1) begin
            i_data_r[i] <= 0;
            bitmask_buffer_r[i] <= 0;
            data_buffer_r[i] <= 0;
            data_counter_r[i] <= 0;
        end
        for(i=0; i<24; i=i+1) begin
            slp_r[i] <= 0;
            sd_r[i] <= 0;
            dslp_r[i] <= 0;
        end
    end else begin
        state_r <= state_w;
        byte_counter_r <= byte_counter_w;
        channel_counter_r <= channel_counter_w;
        o_valid_r <= o_valid_w;
        o_data_r <= o_data_w;
        read_flag_r <= read_flag_w;
        sram_index_last <= sram_index;

        for(i=0; i<4; i=i+1) begin
            bitmask_buffer_r[i] <= bitmask_buffer_w[i];
            data_buffer_r[i] <= data_buffer_w[i];
            data_counter_r[i] <= data_counter_w[i];
        end
        for(i=0; i<24; i=i+1) begin
            slp_r[i] <= slp_w[i];
            sd_r[i] <= sd_w[i];
            dslp_r[i] <= dslp_w[i];
        end
        i_data_r[0] <= i_data_0;
        i_data_r[1] <= i_data_1;
        i_data_r[2] <= i_data_2;
        i_data_r[3] <= i_data_3;
        i_valid_r <= i_valid;
    end
end
endmodule
