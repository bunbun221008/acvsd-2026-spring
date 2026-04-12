`timescale 1ns/1ps
module LBP # (
    parameter DATA_WIDTH = 8,              // AXI4 data width
    parameter ADDR_WIDTH = 15,             // AXI4 address width
    parameter STRB_WIDTH = (DATA_WIDTH/8)  // AXI4 strobe width
)
(
    // Clock and synchronous high reset
    input                   clk_A,
    input                   clk_B,
    input                   rst,

    input                   start,
    output                  finish,

    // Data AXI4 master interface
    output [ADDR_WIDTH-1:0] data_awaddr,
    output [           7:0] data_awlen,
    output [           2:0] data_awsize,
    output [           1:0] data_awburst,
    output                  data_awvalid,
    input                   data_awready,
    output [DATA_WIDTH-1:0] data_wdata,
    output [STRB_WIDTH-1:0] data_wstrb,
    output                  data_wlast,
    output                  data_wvalid,
    input                   data_wready,
    // input  [           1:0] data_bresp,
    // input                   data_bvalid,
    // output                  data_bready,
    output [ADDR_WIDTH-1:0] data_araddr,
    output [           7:0] data_arlen,
    output [           2:0] data_arsize,
    output [           1:0] data_arburst,
    output                  data_arvalid,
    input                   data_arready,
    input  [DATA_WIDTH-1:0] data_rdata,
    input  [           1:0] data_rresp,
    input                   data_rlast,
    input                   data_rvalid,
    output                  data_rready
);
    // /////////////////////////// parameter //////////////////////////
    parameter PARALLEL = 2;
    parameter CYCLE_RATIO = 100;
    /////////////////////////// reg and wire///////////////////////////////
    reg start_a_r, start_b_r;
    reg finish_a_r, finish_b_r, finish_b_w;
    reg [6:0]cycle_counter_w, cycle_counter_r;

    wire lbp_read, lbp_write;
    wire [ADDR_WIDTH-1:0] lbp_addr;
    wire [7:0] lbp_len;
    wire [PARALLEL*DATA_WIDTH-1:0] lbp_wdata;
    wire lbp_finish;
    wire [DATA_WIDTH-1:0] lbp_rdata;
    wire lbp_rvalid;
    wire axi_ready;
    wire axi_finish;
    /////////////////////////////assignment ////////////////////////////
    assign finish = finish_a_r;
    /////////////////////////////combinational logic ////////////////////////////
    always @(*) begin
        cycle_counter_w = cycle_counter_r;
        finish_b_w = finish_b_r;
        if(axi_finish) begin
            cycle_counter_w = cycle_counter_r-1'b1;
            if(cycle_counter_r == 0) begin // wait for 2 cycles to make sure the finish signal is stable, then we can assert the finish signal of the whole module
                cycle_counter_w = CYCLE_RATIO;
                finish_b_w = !finish_b_r; // toggle the finish signal to indicate the finish of the whole module
            end
        end 
    end
    
    ///////////////////////////// module//////////////////////////////////
    lbp_core # (
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .STRB_WIDTH(STRB_WIDTH),
        .PARALLEL(PARALLEL)
    ) u_lbp_core (
        .clk(clk_B),
        .rst(rst),
        .start(start_b_r),
        .data_rlast(data_rlast),
        .data_wlast(data_wlast),
        .lbp_read(lbp_read),
        .lbp_write(lbp_write),
        .lbp_addr(lbp_addr),
        .lbp_len(lbp_len),
        .lbp_wdata(lbp_wdata),
        .lbp_finish(lbp_finish),
        .lbp_rdata(lbp_rdata),
        .lbp_rvalid(lbp_rvalid),
        .axi_ready(axi_ready)
    );

    axi_control # (
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .STRB_WIDTH(STRB_WIDTH),
        .PARALLEL(PARALLEL)
    ) u_axi_control (
        .clk(clk_B),
        .rst(rst),
        .finish(axi_finish),
        .data_awaddr(data_awaddr),
        .data_awlen(data_awlen),
        .data_awsize(data_awsize),
        .data_awburst(data_awburst),
        .data_awvalid(data_awvalid),
        .data_awready(data_awready),
        .data_wdata(data_wdata),
        .data_wstrb(data_wstrb),
        .data_wlast(data_wlast),
        .data_wvalid(data_wvalid),
        .data_wready(data_wready),
        // .data_bresp(data_bresp),
        // .data_bvalid(data_bvalid),
        // .data_bready(data_bready),
        .data_araddr(data_araddr),
        .data_arlen(data_arlen),
        .data_arsize(data_arsize),
        .data_arburst(data_arburst),
        .data_arvalid(data_arvalid),
        .data_arready(data_arready),
        .data_rdata(data_rdata),
        .data_rresp(data_rresp),
        .data_rlast(data_rlast),
        .data_rvalid(data_rvalid),
        .data_rready(data_rready),

        .lbp_read(lbp_read),
        .lbp_write(lbp_write),
        .lbp_addr(lbp_addr),
        .lbp_len(lbp_len),
        .lbp_wdata(lbp_wdata),
        .lbp_finish(lbp_finish),

        .lbp_rdata(lbp_rdata),    
        .lbp_rvalid(lbp_rvalid), 
        .axi_ready(axi_ready)
    );


    ////////////////////////// sequential logic ///////////////////////////////

    always @(posedge clk_A or posedge rst) begin
        if (rst) begin
            start_a_r <= 1'b0;
            finish_a_r <= 1'b0;
        end else begin
            start_a_r <= start;
            finish_a_r <= finish_b_r;
        end
    end

    always @(posedge clk_B or posedge rst) begin
        if (rst) begin
            start_b_r <= 1'b0;
            finish_b_r <= 1'b0;
            cycle_counter_r <= 0;
        end else begin
            start_b_r <= start_a_r;
            finish_b_r <= finish_b_w;
            cycle_counter_r <= cycle_counter_w;
        end
    end

endmodule

module lbp_core # (
    parameter DATA_WIDTH = 8,              // AXI4 data width
    parameter ADDR_WIDTH = 15,             // AXI4 address width
    parameter STRB_WIDTH = (DATA_WIDTH/8),  // AXI4 strobe width
    parameter PARALLEL = 2                 // how many pixels are processed in parallel
)
(
    input                   clk,
    input                   rst,

    input                   start,

    // some useful axi signals
    input                   data_rlast,
    input                   data_wlast,
    
    // axi control interface
    output                  lbp_read,
    output                  lbp_write,
    output [ADDR_WIDTH-1:0] lbp_addr,
    output [           7:0] lbp_len,
    output [PARALLEL*DATA_WIDTH-1:0] lbp_wdata,
    output                  lbp_finish,
    input  [DATA_WIDTH-1:0] lbp_rdata,
    input                   lbp_rvalid,
    input                   axi_ready
);
    ////////////////////////// parameter //////////////////////////
    parameter S_IDLE = 2'd0;
    parameter S_READ = 2'd1;
    parameter S_CALCULATE = 2'd2;
    parameter S_WRITE = 2'd3;

    ////////////////////////// reg and wire ////////////////////////////
    reg [1:0] state_w, state_r;
    reg  cycle_counter_w, cycle_counter_r; // count the cycles for calculating one batch of pixels, used to control the state transition from CALCULATE to WRITE

    // axi control interface
    reg read_w, read_r, write_w, write_r;
    reg [ADDR_WIDTH-1:0] addr_w, addr_r;
    reg [7:0] len_w, len_r;
    reg finish_w, finish_r;
    // data buffer and pixel coordinates counter
    reg [DATA_WIDTH-1:0] data_buffer_w[0:2][0:PARALLEL+1], data_buffer_r[0:2][0:PARALLEL+1]; // 3 rows of data buffer, each row can store PARALLEL+2 pixels (including the neighboring pixels for LBP calculation)
    reg [6:0] coor_w[0:1], coor_r[0:1]; // coordinates of the current left-most pixel being processed
    reg read_once_flag_w, read_once_flag_r; // flag to indicate whether the first row of pixel of the new row has been read, used to control the reading of the next row
    integer i,j;
    genvar gi;

    // answer buffer
    reg  [DATA_WIDTH-1:0] lbp_value_w[0:PARALLEL-1], lbp_value_r[0:PARALLEL-1];
    wire [DATA_WIDTH-1:0] lbp_cmp_0[0:PARALLEL-1], lbp_cmp_1[0:PARALLEL-1];


    /////////////////////////// assignment ////////////////////////////
    assign lbp_read = read_r;
    assign lbp_write = write_r;
    assign lbp_addr = addr_r;
    assign lbp_len = len_r;
    assign lbp_finish = finish_r;
    generate
        for(gi=0;gi<PARALLEL; gi=gi+1) begin 
            assign lbp_wdata[gi*DATA_WIDTH +: DATA_WIDTH] = lbp_value_r[gi];
            assign lbp_cmp_0[gi] = (lbp_value_r[gi]<= {lbp_value_r[gi][5:0], lbp_value_r[gi][7:6]}) ? lbp_value_r[gi] : {lbp_value_r[gi][5:0], lbp_value_r[gi][7:6]};
            assign lbp_cmp_1[gi] = ({lbp_value_r[gi][3:0], lbp_value_r[gi][7:4]} <= {lbp_value_r[gi][1:0], lbp_value_r[gi][7:2]}) ? {lbp_value_r[gi][3:0], lbp_value_r[gi][7:4]} : {lbp_value_r[gi][1:0], lbp_value_r[gi][7:2]};
        end
    endgenerate

    ////////////////////////// combinational logic ////////////////////////////
    always @(*) begin
        state_w = state_r;
        read_w = 1'b0;
        write_w = 1'b0;
        addr_w = addr_r;
        len_w = len_r;
        finish_w = finish_r;


        read_once_flag_w = read_once_flag_r;
        cycle_counter_w = cycle_counter_r;
        coor_w[0] = coor_r[0];
        coor_w[1] = coor_r[1];

        for(i = 0; i < PARALLEL; i = i + 1) begin
            lbp_value_w[i] = lbp_value_r[i];
        end
        for(i = 0; i < 3; i = i + 1) begin
            for(j = 0; j < PARALLEL+2; j = j + 1) begin
                data_buffer_w[i][j] = data_buffer_r[i][j];
            end
        end
        
        case (state_r)
            S_IDLE: begin
                if (start) begin
                    state_w = S_READ;
                    read_w = 1'b1;
                    addr_w = 0; // start address of the input image
                    len_w = PARALLEL + 1; // number of pixels in the input image
                end
            end
            S_READ: begin
                if (lbp_rvalid) begin
                    // shift the data buffer to make room for new data
                    if(coor_r[1] == 8'd128-PARALLEL) begin // right-most column
                        for(j = 0; j < PARALLEL; j = j + 1) begin
                            data_buffer_w[2][j] = data_buffer_r[2][j+1];
                        end
                        data_buffer_w[2][PARALLEL] = lbp_rdata;
                    end else begin
                        for(j = 0; j < PARALLEL+1; j = j + 1) begin
                            data_buffer_w[2][j] = data_buffer_r[2][j+1];
                        end
                        data_buffer_w[2][PARALLEL+1] = lbp_rdata;
                    end
                    

                    // read end logic
                    if (data_rlast) begin
                        if (coor_r[0] != 0 || read_once_flag_r) begin // only first needs 2 rounds of reading, the rest needs 1 round of reading
                            state_w = S_CALCULATE;
                            read_once_flag_w = 1'b0;
                        end else begin
                            read_w = 1'b1;
                            addr_w[13:7] = addr_r[13:7] + 1'd1; // move to the next row
                            len_w = (coor_r[1] == 8'd128-PARALLEL || coor_r[1] == 0) ? PARALLEL+1 : PARALLEL+2; // if it's the right-most/left-most column, we only need to read PARALLEL+1 pixels, otherwise we need to read PARALLEL+2 pixels
                            read_once_flag_w = 1'b1;
                            for(i = 0; i < 3; i = i + 1) begin
                                for(j = 0; j < PARALLEL+2; j = j + 1) begin
                                    if(i==2) begin
                                        data_buffer_w[i][j] = 0;
                                    end else begin
                                        data_buffer_w[i][j] = data_buffer_w[i+1][j];
                                    end
                                end
                            end
                        end
                    end
                end
            end
            S_CALCULATE: begin
                if(cycle_counter_r == 0) begin
                    for(i=0;i<PARALLEL;i=i+1) begin
                        // calculate the LBP value for the current pixel using the data in the data buffer
                        lbp_value_w[i][0] = (data_buffer_r[0][i] >= data_buffer_r[1][i+1]) ? 1'b1 : 1'b0; // top left
                        lbp_value_w[i][1] = (data_buffer_r[0][i+1] >= data_buffer_r[1][i+1]) ? 1'b1 : 1'b0; // top
                        lbp_value_w[i][2] = (data_buffer_r[0][i+2] >= data_buffer_r[1][i+1]) ? 1'b1 : 1'b0; // top right
                        lbp_value_w[i][3] = (data_buffer_r[1][i+2] >= data_buffer_r[1][i+1]) ? 1'b1 : 1'b0; // right
                        lbp_value_w[i][4] = (data_buffer_r[2][i+2] >= data_buffer_r[1][i+1]) ? 1'b1 : 1'b0; // bottom right
                        lbp_value_w[i][5] = (data_buffer_r[2][i+1] >= data_buffer_r[1][i+1]) ? 1'b1 : 1'b0; // bottom
                        lbp_value_w[i][6] = (data_buffer_r[2][i] >= data_buffer_r[1][i+1]) ? 1'b1 : 1'b0; // bottom left
                        lbp_value_w[i][7] = (data_buffer_r[1][i] >= data_buffer_r[1][i+1]) ? 1'b1 : 1'b0; // left

                        // write the LBP value to the answer buffer
                    end
                end else begin
                    // compare the four rotations of the LBP value and find the minimum one
                    // by comparing the four shifts of the LBP value with the original one, we can find the minimum one without actually calculating all four rotations
                    for(i=0;i<PARALLEL;i=i+1) begin
                        lbp_value_w[i] = (lbp_cmp_0[i] <= lbp_cmp_1[i]) ? lbp_cmp_0[i] : lbp_cmp_1[i];
                    end
                end


                cycle_counter_w = cycle_counter_r + 1'd1;
                if (cycle_counter_r == 1'd1) begin // assuming it takes 4 cycles to calculate one LBP value
                    state_w = S_WRITE;
                    cycle_counter_w = 0;
                end
            end
            S_WRITE: begin
                
                if (axi_ready) begin
                    // write
                    write_w = 1'b1;
                    addr_w = {1'b1, coor_r[0], coor_r[1]}; // the address is determined by the coordinates of the current pixel
                    len_w = PARALLEL; // write PARALLEL pixels each time
                    if(coor_r[0] == 7'd127 && coor_r[1] == 8'd128-PARALLEL) begin // if it's the last batch of pixels, we need to finish after writing
                        finish_w = 1'b1;
                    end
                end
                if(data_wlast) begin
                    // after writing one batch of pixels, update the coordinates and move the data buffer
                    if (coor_r[0] == 7'd127) begin // bottom row
                        coor_w[0] = 0;
                        coor_w[1] = coor_r[1] + PARALLEL; // move to the next batch of columns
                        for(i = 0; i < 3; i = i + 1) 
                            for(j = 0; j < PARALLEL+2; j = j + 1) begin
                                data_buffer_w[i][j] = 0;
                        end
                    end else begin
                        coor_w[0] = coor_r[0] + 1; // move to the next row
                        for(i = 0; i < 3; i = i + 1) begin
                            for(j = 0; j < PARALLEL+2; j = j + 1) begin
                                if(i==2) begin
                                    data_buffer_w[i][j] = 0;
                                end else begin
                                    data_buffer_w[i][j] = data_buffer_r[i+1][j];
                                end
                            end
                        end
                    end

                    // read logic
                    state_w = S_READ;
                    read_w = 1'b1;
                    if(coor_r[0] == 7'd126) begin
                        state_w = S_CALCULATE; // if it's the second last row, we can calculate the LBP value of the last row without reading the next row of pixels, because the last row of pixels will not be used for the LBP calculation of any other pixels
                        read_w = 1'b0;
                    end 
                    // addr logic
                    addr_w[14] = 0;
                    if(coor_r[0] == 7'd127) begin
                        addr_w[13:7] = 0;
                    end else begin
                        addr_w[13:7] = coor_r[0] + 2'd2; // move to the next row, we need to read the next row of pixels for the LBP calculation of the next batch of pixels
                    end
                    if(coor_w[1] == 0) begin
                        addr_w[6:0] = 0; // the address is determined by the coordinates of the current pixel
                    end else begin
                        addr_w[6:0] = coor_w[1]-1'd1; 
                    end

                    if (coor_w[1] == 0 || coor_w[1] == 8'd128-PARALLEL) begin // right-most column
                        len_w = PARALLEL + 1'd1; // read PARALLEL+1 pixels for the right-most column
                    end else begin
                        len_w = PARALLEL + 2'd2; // read PARALLEL+2 pixels for other columns
                    end
                end
            end
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state_r <= S_IDLE;
            cycle_counter_r <= 0;
            read_r <= 1'b0;
            write_r <= 1'b0;
            addr_r <= 0;
            len_r <= 0;
            finish_r <= 1'b0;
            read_once_flag_r <= 1'b0;
            coor_r[0] <= 0;
            coor_r[1] <= 0;
            cycle_counter_r <= 0;
            for(i = 0; i < PARALLEL; i = i + 1) begin
                lbp_value_r[i] <= 0;
            end
            for(i = 0; i < 3; i = i + 1) begin
                for(j = 0; j < PARALLEL+2; j = j + 1) begin
                    data_buffer_r[i][j] <= 0;
                end
            end
        end else begin
            state_r <= state_w;
            cycle_counter_r <= cycle_counter_w;
            read_r <= read_w;
            write_r <= write_w;
            addr_r <= addr_w;
            len_r <= len_w;
            finish_r <= finish_w;
            read_once_flag_r <= read_once_flag_w;
            coor_r[0] <= coor_w[0];
            coor_r[1] <= coor_w[1];
            cycle_counter_r <= cycle_counter_w;
            for(i = 0; i < PARALLEL; i = i + 1) begin
                lbp_value_r[i] <= lbp_value_w[i];
            end
            for(i = 0; i < 3; i = i + 1) begin
                for(j = 0; j < PARALLEL+2; j = j + 1) begin
                    data_buffer_r[i][j] <= data_buffer_w[i][j];
                end
            end
        end
    end

endmodule

module axi_control # (
    parameter DATA_WIDTH = 8,              // AXI4 data width
    parameter ADDR_WIDTH = 15,             // AXI4 address width
    parameter STRB_WIDTH = (DATA_WIDTH/8),  // AXI4 strobe width
    parameter PARALLEL = 2                 // how many pixels are processed in parallel
)
(
    input                   clk,
    input                   rst,

    output reg              finish,

    // Data AXI4 master interface
    output [ADDR_WIDTH-1:0] data_awaddr,
    output [           7:0] data_awlen,
    output [           2:0] data_awsize,
    output [           1:0] data_awburst,
    output                  data_awvalid,
    input                   data_awready,
    output [DATA_WIDTH-1:0] data_wdata,
    output [STRB_WIDTH-1:0] data_wstrb,
    output                  data_wlast,
    output                  data_wvalid,
    input                   data_wready,
    // input  [           1:0] data_bresp,
    // input                   data_bvalid,
    // output                  data_bready,
    output [ADDR_WIDTH-1:0] data_araddr,
    output [           7:0] data_arlen,
    output [           2:0] data_arsize,
    output [           1:0] data_arburst,
    output                  data_arvalid,
    input                   data_arready,
    input  [DATA_WIDTH-1:0] data_rdata,
    input  [           1:0] data_rresp,
    input                   data_rlast,
    input                   data_rvalid,
    output                  data_rready,

    // lbp core interface
    input                   lbp_read,
    input                   lbp_write,
    input  [ADDR_WIDTH-1:0] lbp_addr,
    input  [           7:0] lbp_len,
    input  [PARALLEL*DATA_WIDTH-1:0] lbp_wdata,
    input                   lbp_finish,

    output [DATA_WIDTH-1:0] lbp_rdata,
    output reg              lbp_rvalid,
    output reg              axi_ready // signal to indicate that axi_control is ready to accept new commands from lbp_core
);
    ////////////////////////////// parameter//////////////////////////////
    parameter S_IDLE = 2'd0;
    parameter S_READ = 2'd1;
    parameter S_WRITE = 2'd2;
    parameter S_FINISH = 2'd3;

    /////////////////////////// reg and wire///////////////////////////
    reg [1:0] state_w, state_r;
    reg counter_w, counter_r; // count how many pixels have been read/written in current burst

    // lbp core interface
    reg lbp_read_w, lbp_read_r, lbp_write_w, lbp_write_r; // registered version of lbp_read and lbp_write to detect rising edge
    
    // axi interface
    reg awvalid, wvalid, arvalid;
    reg [DATA_WIDTH-1:0] wdata;
    reg wlast;

    
    ///////////////////////////// assignment///////////////////////////
    // axi interface
    assign data_awaddr = lbp_addr;
    assign data_awlen = lbp_len - 1'b1; // burst length is len, but AXI4 uses len-1
    assign data_awsize = 3'b000; // 1 byte
    assign data_awburst = 2'b01; // INCR
    assign data_awvalid = awvalid;

    assign data_wvalid = wvalid;
    assign data_wdata = wdata;
    assign data_wstrb = {STRB_WIDTH{1'b1}}; // all bytes are valid
    assign data_wlast = wlast;

    assign data_arvalid = arvalid;   
    assign data_araddr = lbp_addr;
    assign data_arlen = lbp_len - 1'b1; // burst length is len, but AXI4 uses len-1
    assign data_arsize = 3'b000; // 1 byte
    assign data_arburst = 2'b01; // INCR

    assign data_rready = 1'b1; // always ready to accept data from AXI4

    // lbp core interface
    assign lbp_rdata = data_rdata;    
    ///////////////////////////////// combinational logic/////////////////////////////////
    always @(*) begin
        state_w = state_r;
        counter_w = counter_r;
        finish = 1'b0;

        awvalid = 1'b0;
        wvalid = 1'b0;
        arvalid = 1'b0;
        wlast = 1'b0;
        
        lbp_rvalid = 1'b0;
        lbp_read_w = 1'b0;
        lbp_write_w = 1'b0;
        axi_ready = 1'b0;

        wdata = lbp_wdata[counter_r * DATA_WIDTH +: DATA_WIDTH]; // only write one pixel each time

        case (state_r)
            S_IDLE: begin
                counter_w = 1'b0;
                if(lbp_read || lbp_read_r) begin
                    arvalid = 1'b1;
                    lbp_read_w = 1'b1; // hold the read signal until the burst is accepted
                    if(data_arready) begin
                        state_w = S_READ;
                    end
                end else if (lbp_write || lbp_write_r) begin
                    awvalid = 1'b1;
                    lbp_write_w = 1'b1; // hold the write signal until the burst is accepted
                    if (data_awready) begin
                        state_w = S_WRITE;
                    end
                end else begin
                    axi_ready = 1'b1;
                end
            end
            S_READ: begin
                if (data_rvalid) begin
                    lbp_rvalid = 1'b1; 
                    if (data_rlast) begin
                        state_w = S_IDLE;
                    end
                end
            end
            S_WRITE: begin
                wvalid = 1'b1;
                
                if (data_wready) begin
                    counter_w = counter_r + 1'b1;
                    if (counter_r == PARALLEL - 1'b1) begin
                        state_w = (lbp_finish) ? S_FINISH : S_IDLE;
                    end
                end
                if (counter_r == PARALLEL - 1'b1) begin
                    wlast = 1'b1;
                end
            end
            S_FINISH: begin
                finish = 1'b1;
            end 
        endcase
    end


    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state_r <= S_IDLE;
            counter_r <= 1'b0;
            lbp_read_r <= 1'b0;
            lbp_write_r <= 1'b0;
        end else begin
            state_r <= state_w;
            counter_r <= counter_w;
            lbp_read_r <= lbp_read_w;
            lbp_write_r <= lbp_write_w;
        end
    end
endmodule
