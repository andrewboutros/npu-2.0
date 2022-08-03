module register_file # (
	parameter DATAW = 8,
	parameter LANES = 40,
	parameter DEPTH = 512,
	parameter ADDRW = $clog2(DEPTH)
)(
	input clk,
	input rst,
	input [ADDRW-1:0] i_raddr,
	input i_rvalid,
	input i_rload,
	input [ADDRW-1:0] i_waddr,
	input signed [DATAW-1:0] i_wdata [0:LANES-1],
	input i_wvalid,
	output signed [DATAW-1:0] o_rdata [0:LANES-1],
	output o_rvalid,
	output o_rload
);

localparam NUM_BRAMS = LANES / 4;
localparam VALID_PIPELINE = 2;

logic [(DATAW*4)-1:0] r_wdata_packed [0:NUM_BRAMS-1];
logic [(DATAW*4)-1:0] r_rdata_packed [0:NUM_BRAMS-1];

pipeline # (.DWIDTH(1), .DEPTH(VALID_PIPELINE)) r_valid (.clk(clk), .rst(rst), .en(1'b1), .i_data(i_rvalid), .o_data(o_rvalid));
pipeline # (.DWIDTH(1), .DEPTH(VALID_PIPELINE)) r_load (.clk(clk), .rst(rst), .en(1'b1), .i_data(i_rload), .o_data(o_rload));

genvar bram_id, element_id;
generate
for (bram_id = 0; bram_id < NUM_BRAMS; bram_id = bram_id + 1) begin: gen_rf_bram
	for (element_id = 0; element_id < 4; element_id = element_id + 1) begin: pack_bram_words
		assign r_wdata_packed[bram_id][(element_id * DATAW)+:DATAW] = i_wdata[(bram_id*4)+element_id];
		assign o_rdata[(bram_id*4)+element_id] = r_rdata_packed[bram_id][(element_id * DATAW)+:DATAW];
	end
	
	bram # (
		.DATAW(DATAW * 4),
		.DEPTH(DEPTH)
	) bram_inst (
		.clk(clk),
		.data(r_wdata_packed[bram_id]),
		.rdaddress(i_raddr),
		.wraddress(i_waddr),
		.wren(i_wvalid),
		.q(r_rdata_packed[bram_id])
	);
end
endgenerate

endmodule