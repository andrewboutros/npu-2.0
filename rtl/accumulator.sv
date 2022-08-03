module accumulator # (
	parameter SLICE_ODATAW = 26,
	parameter ACCUM_DATAW = 32,
	parameter ACCUM_DEPTH = 512,
	parameter ACCUM_ADDRW = $clog2(ACCUM_DEPTH)
)(
	input clk,
	input rst,
	input [ACCUM_ADDRW-1:0] i_accum_addr,
	input [1:0] i_accum_op,
	input i_valid,
	input [SLICE_ODATAW-1:0] i_accum_data,
	output o_valid,
	output [ACCUM_DATAW-1:0] o_accum_data
);

localparam ACCUM_PIPELINE = 2;
localparam [1:0] SET = 0, ADD = 1, ADD_OUT = 2, SET_OUT = 3;

logic [ACCUM_ADDRW-1:0] r_accum_raddr, rr_accum_raddr;
logic [ACCUM_DATAW-1:0] r_accum_rdata, r_accum_wdata;
logic [SLICE_ODATAW-1:0] r_accum_idata;
logic [1:0] r_accum_op, rr_accum_op;
logic r_valid, rr_valid, r_wen;

pipeline # (.DWIDTH(ACCUM_ADDRW), .DEPTH(ACCUM_PIPELINE)) r_raddr (.clk(clk), .rst(rst), .en(1'b1), .i_data(i_accum_addr), .o_data(r_accum_raddr));
pipeline # (.DWIDTH(SLICE_ODATAW), .DEPTH(ACCUM_PIPELINE)) r_idata (.clk(clk), .rst(rst), .en(1'b1), .i_data(i_accum_data), .o_data(r_accum_idata));
pipeline # (.DWIDTH(3), .DEPTH(ACCUM_PIPELINE)) r_ctrl (.clk(clk), .rst(rst), .en(1'b1), .i_data({i_accum_op, i_valid}), .o_data({r_accum_op, r_valid}));

bram # (
	.DATAW(ACCUM_DATAW),
	.DEPTH(ACCUM_DEPTH)
) accum_bram (
	.clk(clk),
	.data(r_accum_wdata),
	.rdaddress(i_accum_addr),
	.wraddress(rr_accum_raddr),
	.wren(r_wen),
	.q(r_accum_rdata)
);

integer a, p;
always @ (posedge clk) begin
	if (rst) begin
		r_accum_wdata <= 0;
		rr_accum_op <= 0;
		rr_valid <= 0;
		r_wen <= 0;
		rr_accum_raddr <= 0;
	end else begin
		if ((r_accum_op == SET) || (r_accum_op == SET_OUT)) begin
			r_accum_wdata <= {{(ACCUM_DATAW-SLICE_ODATAW){r_accum_idata[SLICE_ODATAW-1]}}, r_accum_idata};
		end else begin
			r_accum_wdata <= {{(ACCUM_DATAW-SLICE_ODATAW){r_accum_idata[SLICE_ODATAW-1]}}, r_accum_idata} + r_accum_rdata;
		end
		rr_accum_raddr <= r_accum_raddr;
		rr_accum_op <= r_accum_op;
		rr_valid <= r_valid && ((r_accum_op == SET_OUT) || (r_accum_op == ADD_OUT));
		r_wen <= r_valid;
	end
end

assign o_valid = rr_valid;
assign o_accum_data = r_accum_wdata;

endmodule