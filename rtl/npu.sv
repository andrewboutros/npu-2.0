`include "npu.vh"

module npu # (
	parameter NUM_SLICES = `NUM_SLICES,
	parameter NUM_ATOMS = `NUM_ATOMS,
	parameter IDATAW = `IDATAW,
	parameter LANES = `LANES,
	parameter BATCH = `BATCH,
	parameter MV_RF_DEPTH = `MV_RF_DEPTH,
	parameter MV_RF_ADDRW = $clog2(MV_RF_DEPTH),
	parameter INST_FIFO_DEPTH = `INST_FIFO_DEPTH,
	parameter DATA_FIFO_DEPTH = `DATA_FIFO_DEPTH,
	parameter TAGW = `TAGW,
	parameter ACCUM_DEPTH = `ACCUM_DEPTH,
	parameter ACCUM_DATAW = `ACCUM_DATAW,
	parameter ACCUM_ADDRW = `ACCUM_ADDRW,
	parameter MVSLICE_UIW = `MVSLICE_UIW,
	parameter ATOM_IDW = $clog2(NUM_ATOMS),
	parameter ATOM_ODATAW = (2*IDATAW) + $clog2(LANES),
	parameter SLICE_ODATAW = (2*IDATAW) + $clog2(LANES) + $clog2(NUM_ATOMS)
)(
	input clk,
	input rst,
	input i_tag_update [0:NUM_SLICES-1],
	input [MVSLICE_UIW-1:0] i_inst_data [0:NUM_SLICES-1],
	input i_inst_valid [0:NUM_SLICES-1],
	output o_inst_ready [0:NUM_SLICES-1],
	input [MV_RF_ADDRW-1:0] i_waddr [0:NUM_SLICES-1],
	input [ATOM_IDW-1:0] i_wid [0:NUM_SLICES-1],
	input signed [IDATAW-1:0] i_wdata [0:NUM_SLICES-1][0:LANES-1],
	input i_wvalid [0:NUM_SLICES-1],
	output signed [ACCUM_DATAW-1:0] o_ofifo_data [0:NUM_SLICES-1][0:BATCH-1],
	input i_ofifo_ren [0:NUM_SLICES-1],
	output o_ofifo_ready [0:NUM_SLICES-1]
);

genvar slice_id;
generate
for (slice_id = 0; slice_id < NUM_SLICES; slice_id = slice_id + 1) begin: gen_mv_slices
	mv_slice slice_inst (
		.clk(clk),
		.rst(rst),
		.i_tag_update(i_tag_update[slice_id]),
		.i_inst_data(i_inst_data[slice_id]),
		.i_inst_valid(i_inst_valid[slice_id]),
		.o_inst_ready(o_inst_ready[slice_id]),
		.i_waddr(i_waddr[slice_id]),
		.i_wid(i_wid[slice_id]),
		.i_wdata(i_wdata[slice_id]),
		.i_wvalid(i_wvalid[slice_id]),
		.o_ofifo_data(o_ofifo_data[slice_id]),
		.i_ofifo_ren(i_ofifo_ren[slice_id]),
		.o_ofifo_ready(o_ofifo_ready[slice_id])
	);
end
endgenerate

endmodule