module pipeline # (
	parameter DWIDTH = 1,
	parameter DEPTH = 1
)(
	input clk,
	input rst,
	input en,
	input [DWIDTH-1:0] i_data,
	output [DWIDTH-1:0] o_data
);

logic [DWIDTH-1:0] r_data [0:DEPTH-1];

integer stage_id;
always @ (posedge clk) begin
	if (rst) begin
		for (stage_id = 0; stage_id < DEPTH; stage_id = stage_id + 1) begin
			r_data[stage_id] <= 0;
		end
	end else begin
		if (en) begin
			r_data[0] <= i_data;
			for (stage_id = 1; stage_id < DEPTH; stage_id = stage_id + 1) begin
				r_data[stage_id] <= r_data[stage_id-1];
			end
		end
	end
end

assign o_data = r_data[DEPTH-1];

endmodule