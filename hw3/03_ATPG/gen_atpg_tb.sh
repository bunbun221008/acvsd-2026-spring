#!/bin/bash
export SYNOPSYS_TMAX="/usr/cad/synopsys/tmax/cur/"
DESIGN="top"
stil2verilog ${DESIGN}_atpg.stil ${DESIGN}_atpg_stildpv -replace
sed -i 's|#!/bin/sh|&\nSTILDPV_HOME="/usr/cad/synopsys/tmax/cur/linux64/stildpv"|' ${DESIGN}_atpg_vcs.sh
sed -i 's|LIB_FILES=.*|&\nLIB_FILES="$LIB_FILES -v /share1/tech/ADFP/Executable_Package/Collaterals/IP/sram/N16ADFP_SRAM/VERILOG/N16ADFP_SRAM_100a.v"|' ${DESIGN}_atpg_vcs.sh
sed -i 's|SIMULATOR=.*|SIMULATOR="vcs -full64"|' ${DESIGN}_atpg_vcs.sh
sed -i 's|+delay_mode_zero|& +define+TSMC_CM_NO_WARNING+TSMC_DISABLE_CONTENTION_MESSAGE|' ${DESIGN}_atpg_vcs.sh
chmod u+x ${DESIGN}_atpg_vcs.sh
