`include "npu.vh"

module mv_slice # (
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
	input i_tag_update,
	
	input [MVSLICE_UIW-1:0] i_inst_data,
	input i_inst_valid,
	output o_inst_ready,
	
	input [MV_RF_ADDRW-1:0] i_waddr,
	input [ATOM_IDW-1:0] i_wid,
	input signed [IDATAW-1:0] i_wdata [0:LANES-1],
	input i_wvalid,
	
	output signed [ACCUM_DATAW-1:0] o_ofifo_data [0:BATCH-1],
	input i_ofifo_ren,
	output o_ofifo_ready
);

localparam RF_LATENCY = 2;
localparam DP_LATENCY = 4 + $clog2(LANES);
localparam ATOM_REDUCE_LATENCY = $clog2(NUM_ATOMS) - 1;
localparam ACCUM_LATENCY = 3;
localparam ACCUM_CTRL_PIPELINE = RF_LATENCY + DP_LATENCY + ATOM_REDUCE_LATENCY;
localparam SLICE_LATENCY = RF_LATENCY + DP_LATENCY + ATOM_REDUCE_LATENCY + ACCUM_LATENCY;

logic signed [ATOM_ODATAW-1:0] r_atom_odata [0:NUM_ATOMS-1][0:BATCH-1];
logic r_atom_ovalid [0:NUM_ATOMS-1];
logic signed [SLICE_ODATAW-1:0] r_slice_odata [0:BATCH-1];
logic r_slice_ovalid;
logic [ACCUM_DATAW-1:0] r_accum_odata [0:BATCH-1];
logic [BATCH-1:0] r_accum_ovalid;
logic [BATCH-1:0] r_ofifo_almost_full, r_ofifo_full, r_ofifo_empty;

logic [TAGW-1:0] r_tag;
always @ (posedge clk) begin
	if (rst) begin
		r_tag <= 0;
	end else begin
		if (i_tag_update) begin
			r_tag <= r_tag + 1'b1;
		end
	end
end

logic [MVSLICE_UIW-1:0] r_inst;
logic r_inst_fifo_almost_full, r_inst_fifo_full, r_inst_fifo_empty, r_inst_fifo_rdreq;
logic [MV_RF_ADDRW-1:0] r_inst_raddr;
logic r_inst_rvalid, r_inst_rload;
logic [TAGW-1:0] r_inst_tag;
logic [ACCUM_ADDRW-1:0] r_inst_accum_addr, rr_inst_accum_addr;
logic [1:0] r_inst_accum_op, rr_inst_accum_op;

mlab_fifo # (
	.WIDTH(MVSLICE_UIW),
	.DEPTH(INST_FIFO_DEPTH),
	.ALMOST_FULL_VALUE(INST_FIFO_DEPTH-4)
) instruction_fifo (
	.clk(clk),
	.rst(rst),
	.i_data(i_inst_data),
	.i_rdreq(r_inst_fifo_rdreq),
	.i_wrreq(i_inst_valid),
	.o_almost_full(r_inst_fifo_almost_full),
	.o_empty(r_inst_fifo_empty),
	.o_full(r_inst_fifo_full),
	.o_data(r_inst)
);
assign o_inst_ready = ~r_inst_fifo_almost_full;
assign r_inst_tag = `mvslice_uinst_tag(r_inst);
assign r_inst_fifo_rdreq = ~r_inst_fifo_empty && (r_tag >= `mvslice_uinst_tag(r_inst)) && ~r_ofifo_almost_full[0];

always @ (posedge clk) begin
	if (rst) begin
		r_inst_rvalid <= 0;
		r_inst_raddr <= 0;
		r_inst_rload <= 0;
		r_inst_accum_addr <= 0;
		r_inst_accum_op <= 0;
	end else begin
		r_inst_rvalid <= ~r_inst_fifo_empty && (`mvslice_uinst_tag(r_inst) >= r_tag) && ~r_ofifo_almost_full[0];
		r_inst_raddr <= `mvslice_uinst_rf_addr(r_inst);
		r_inst_rload <= `mvslice_uinst_load(r_inst);
		r_inst_accum_addr <= `mvslice_uinst_accum_addr(r_inst);
		r_inst_accum_op <= `mvslice_uinst_accum_op(r_inst);
	end
end

pipeline # (.DWIDTH(ACCUM_ADDRW+2), .DEPTH(ACCUM_CTRL_PIPELINE)) 
r_raddr (.clk(clk), .rst(rst), .en(1'b1), .i_data({r_inst_accum_addr, r_inst_accum_op}), .o_data({rr_inst_accum_addr, rr_inst_accum_op}));

genvar atom_id;
generate
for (atom_id = 0; atom_id < NUM_ATOMS; atom_id = atom_id + 1) begin: gen_compute_atoms
	compute_atom # (
		.IDATAW(IDATAW),
		.LANES(LANES),
		.BATCH(BATCH),
		.RF_DEPTH(MV_RF_DEPTH)
	) atom_inst (
		.clk(clk),
		.rst(rst),
		.i_raddr(r_inst_raddr),
		.i_rvalid(r_inst_rvalid),
		.i_rload(r_inst_rload),
		.i_waddr(i_waddr),
		.i_wdata(i_wdata),
		.i_wvalid(i_wvalid && (i_wid == atom_id)),
		.o_data(r_atom_odata[atom_id]),
		.o_valid(r_atom_ovalid[atom_id])
	);
end
endgenerate

reduction_tree # (
	.DATAW(ATOM_ODATAW),
	.LANES(BATCH),
	.REDUCTION_SIZE(NUM_ATOMS)
) atom_reduce (
	.clk(clk),
	.rst(rst),
	.i_data(r_atom_odata),
	.i_valid(r_atom_ovalid[0]),
	.o_data(r_slice_odata),
	.o_valid(r_slice_ovalid)
);

genvar batch_id;
generate
for (batch_id = 0; batch_id < BATCH; batch_id = batch_id + 1) begin: gen_odata_fifos
	accumulator # (
		.SLICE_ODATAW(SLICE_ODATAW),
		.ACCUM_DATAW(ACCUM_DATAW),
		.ACCUM_DEPTH(ACCUM_DEPTH)
	) accum_inst (
		.clk(clk),
		.rst(rst),
		.i_accum_addr(rr_inst_accum_addr),
		.i_accum_op(rr_inst_accum_op),
		.i_valid(r_slice_ovalid),
		.i_accum_data(r_slice_odata[batch_id]),
		.o_valid(r_accum_ovalid[batch_id]),
		.o_accum_data(r_accum_odata[batch_id])
	);

	bram_fifo # (
		.WIDTH(ACCUM_DATAW),
		.DEPTH(DATA_FIFO_DEPTH),
		.ALMOST_FULL_VALUE(DATA_FIFO_DEPTH-SLICE_LATENCY)
	) odata_fifo (
		.clk(clk),
		.rst(rst),
		.i_data(r_accum_odata[batch_id]),
		.i_rdreq(i_ofifo_ren),
		.i_wrreq(r_accum_ovalid),
		.o_almost_full(r_ofifo_almost_full[batch_id]),
		.o_empty(r_ofifo_empty[batch_id]),
		.o_full(r_ofifo_full[batch_id]),
		.o_data(o_ofifo_data[batch_id])
	);
end
endgenerate
assign o_ofifo_ready = ~r_ofifo_empty[0];

endmodule