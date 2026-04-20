// Testbench
../00_TB/tb.sv

// DesignWare
// -y /path/to/dw/
// +libext+<file extension>
// +incdir++/path/to/dw/

// UPF
// -power
// -upf ../01_RTL/top.upf

// SRAM
// -v /path/to/sram/SRAM.v
-y ../01_RTL/SRAM/
+libext+.v+.sv

// Design files
../01_RTL/top.sv
../01_RTL/SIMD_Core.sv
../01_RTL/GEMM_Core.sv
../01_RTL/Shared_Memory.sv
../01_RTL/Interconnect.sv
