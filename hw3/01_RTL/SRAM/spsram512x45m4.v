module spsram512x45m4 (
    input   SLP,    // Active high
    input   DSLP,   // Active high
    input   SD,     // Active high
    input   CLK,
    input   CEB,    // Active low
    input   WEB,    // Active low
    input   [8:0] A,
    input   [44:0] D,
    input   [44:0] BWEB,    // Active low
    output  [44:0] Q,
    // input   [1:0] RTSEL,
    // input   [1:0] WTSEL,
    output  PUDELAY
);
    
    TS1N16ADFPCLLLVTA512X45M4SWSHOD mem (
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