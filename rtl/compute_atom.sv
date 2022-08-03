module compute_atom # (
	parameter IDATAW = 8,
	parameter LANES = 40,
	parameter BATCH = 1,
	parameter RF_DEPTH = 512,
	parameter ODATAW = (2*IDATAW) + $clog2(LANES),
	parameter RF_ADDRW = $clog2(RF_DEPTH)
)(
	input clk,
	input rst,
	input [RF_ADDRW-1:0] i_raddr,
	input i_rvalid,
	input i_rload,
	input [RF_ADDRW-1:0] i_waddr,
	input signed [IDATAW-1:0] i_wdata [0:LANES-1],
	input i_wvalid,
	output signed [ODATAW-1:0] o_data [0:BATCH-1],
	output o_valid
);

logic signed [IDATAW-1:0] rf_rdata [0:LANES-1];
logic rf_rvalid, rf_rload;

register_file # (
	.DATAW(IDATAW),
	.LANES(LANES),
	.DEPTH(RF_DEPTH)
) rf (
	.clk(clk),
	.rst(rst),
	.i_raddr(i_raddr),
	.i_rvalid(i_rvalid),
	.i_rload(i_rload),
	.i_waddr(i_waddr),
	.i_wdata(i_wdata),
	.i_wvalid(i_wvalid),
	.o_rdata(rf_rdata),
	.o_rvalid(rf_rvalid),
	.o_rload(rf_rload)
);

dpe # (
	.IDATAW(IDATAW),
	.LANES(LANES),
	.BATCH(BATCH)
) dot (
	.clk(clk),
	.rst(rst),
	.i_data(rf_rdata),
	.i_valid(rf_rvalid),
	.i_load(rf_rload),
	.o_data(o_data),
	.o_valid(o_valid)
);

endmodule