// SRAM
`include "../01_RTL/SRAM/spsram512x45m4.v"
`include "../01_RTL/SRAM/spsram128x64m4.v"
`include "../01_RTL/SRAM/spsram16x96m2.v"
`include "../01_RTL/SRAM/spsram16x88m2.v"
`include "../01_RTL/SRAM/dprf128x64m4.v"
`include "../01_RTL/SRAM/dprf128x32m4.v"
`include "../01_RTL/SRAM/dprf32x32m2.v"
`include "../01_RTL/SRAM/dprf16x120m2.v"
`include "../01_RTL/SRAM/dprf16x72m2.v"
`include "../01_RTL/SRAM/dprf16x32m2.v"

// Design files
`include "../01_RTL/top.sv"
`include "../01_RTL/SIMD_Core.sv"
`include "../01_RTL/GEMM_Core.sv"
`include "../01_RTL/Shared_Memory.sv"
`include "../01_RTL/Interconnect.sv"
