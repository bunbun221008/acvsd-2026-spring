module spsram128x64m4 (
    input   SLP,    // Active high
    input   DSLP,   // Active high
    input   SD,     // Active high
    input   CLK,
    input   CEB,    // Active low
    input   WEB,    // Active low
    input   [6:0] A,
    input   [63:0] D,
    input   [63:0] BWEB,    // Active low
    output  [63:0] Q,
    // input   [1:0] RTSEL,
    // input   [1:0] WTSEL,
    output  PUDELAY
);
    
    TS1N16ADFPCLLLVTA128X64M4SWSHOD mem (
        .SLP(SLP),
        .DSLP(DSLP),
        .SD(SD),
        .CLK(CLK),
        .CEB(CEB),
        .WEB(WEB),
        .A(A),
        .D(D),
        .BWEB(BWEB),
        .Q(Q),
        .RTSEL(2'b01),
        .WTSEL(2'b01),
        .PUDELAY(PUDELAY)
    );

endmodule