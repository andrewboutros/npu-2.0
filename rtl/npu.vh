`ifndef _NPU_VH_
`define _NPU_VH_

`define NUM_SLICES 40
`define NUM_ATOMS 16
`define IDATAW 8
`define LANES 40
`define BATCH 1
`define INST_FIFO_DEPTH 64
`define DATA_FIFO_DEPTH 512
`define ACCUM_DEPTH 512
`define ACCUM_DATAW 32
`define ACCUM_ADDRW $clog2(ACCUM_DEPTH)

`define MV_RF_DEPTH 512
`define MV_RF_ADDRW $clog2(MV_RF_DEPTH)

`define TAGW 10
`define MVSLICE_UIW MV_RF_ADDRW + 1 + TAGW + ACCUM_ADDRW + 2

`define mvslice_uinst_rf_addr(uinst) \
			``uinst``[0 +: MV_RF_ADDRW]
`define mvslice_uinst_load(uinst) \
			``uinst``[MV_RF_ADDRW +: 1]
`define mvslice_uinst_tag(uinst) \
			``uinst``[MV_RF_ADDRW+1 +: TAGW]
`define mvslice_uinst_accum_addr(uinst) \
			``uinst``[MV_RF_ADDRW+1+TAGW +: ACCUM_ADDRW]
`define mvslice_uinst_accum_op(uinst) \
			``uinst``[MV_RF_ADDRW+1+TAGW+ACCUM_ADDRW +: 2]
			
`endif