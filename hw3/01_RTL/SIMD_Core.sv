module SIMD_Core #(
    parameter   DATA_WIDTH = 16
) (
    input   logic   i_clk,
    input   logic   i_rst_n
);

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
