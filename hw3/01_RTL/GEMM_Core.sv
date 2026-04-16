module GEMM_Core #(
    parameter   DATA_WIDTH = 16
) (
    input   logic   i_clk,
    input   logic   i_rst_n
);

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
