module dprf128x32m4 (
    input   SLP,    // Active high
    input   DSLP,   // Active high
    input   SD,     // Active high
    input   CLKW,
    input   WEB,    // Active low
    input   [6:0] AA,
    input   [31:0] D,
    input   [31:0] BWEB,    // Active low
    input   CLKR,
    input   REB,    // Active low
    input   [6:0] AB,
    output  [31:0] Q,
    // input   [1:0] RCT,
    // input   [1:0] WCT,
    // input   [2:0] KP,
    output  PUDELAY
);
    
    TS6N16ADFPCLLLVTA128X32M4FWSHOD mem (
        .SLP(SLP),
        .DSLP(DSLP),
        .SD(SD),
        .CLKW(CLKW),
        .WEB(WEB),
        .AA(AA),
        .D(D),
        .BWEB(BWEB),
        .CLKR(CLKR),
        .REB(REB),
        .AB(AB),
        .Q(Q),
        .RCT(2'b01),
        .WCT(2'b01),
        .KP(3'b011),
        .PUDELAY(PUDELAY)
    );

endmodule