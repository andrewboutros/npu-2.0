module bram_fifo # (
	parameter WIDTH = 32,
	parameter DEPTH = 64,
	parameter ALMOST_FULL_VALUE = 1
)(
	input clk,
	input rst,
	input [WIDTH-1:0] i_data,
	input i_rdreq,
	input i_wrreq,
	output o_almost_full,
	output o_empty,
	output o_full,
	output [WIDTH-1:0] o_data
);

scfifo scfifo_component (
	.clock(clk),
	.data(i_data),
	.rdreq(i_rdreq),
	.sclr(rst),
	.wrreq(i_wrreq),
	.almost_full(o_almost_full),
	.empty(o_empty),
	.full(o_full),
	.q(o_data),
	.aclr(1'b0),
	.almost_empty(),
	.eccstatus(),
	.usedw()
);

defparam
	scfifo_component.add_ram_output_register  = "ON",
	scfifo_component.almost_full_value  = ALMOST_FULL_VALUE,
	scfifo_component.enable_ecc  = "FALSE",
	scfifo_component.intended_device_family  = "Agilex",
	scfifo_component.lpm_hint  = "RAM_BLOCK_TYPE=M20K,MAXIMUM_DEPTH=512",
	scfifo_component.lpm_numwords  = DEPTH,
	scfifo_component.lpm_showahead  = "ON",
	scfifo_component.lpm_type  = "scfifo",
	scfifo_component.lpm_width  = WIDTH,
	scfifo_component.lpm_widthu  = $clog2(DEPTH),
	scfifo_component.overflow_checking  = "OFF",
	scfifo_component.underflow_checking  = "OFF",
	scfifo_component.use_eab  = "ON";

endmodule