module chain # (
	parameter DWIDTH = 1,
	parameter LANES = 1,
	parameter DEPTH = 1
)(
	input clk,
	input rst,
	input en,
	input [DWIDTH-1:0] i_data [0:LANES-1],
	output [DWIDTH-1:0] o_data [0:DEPTH-1][0:LANES-1]
);

logic [DWIDTH-1:0] r_data [0:DEPTH-1][0:LANES-1];

integer stage_id, lane_id;
always @ (posedge clk) begin
	if (rst) begin
		for (stage_id = 0; stage_id < DEPTH; stage_id = stage_id + 1) begin
			for (lane_id = 0; lane_id < LANES; lane_id = lane_id + 1) begin
				r_data[stage_id][lane_id] <= 0;
			end
		end
	end else begin
		if (en) begin
			for (lane_id = 0; lane_id < LANES; lane_id = lane_id + 1) begin
				r_data[0][lane_id] <= i_data[lane_id];
				for (stage_id = 1; stage_id < DEPTH; stage_id = stage_id + 1) begin
					r_data[stage_id][lane_id] <= r_data[stage_id-1][lane_id];
				end
			end
		end
	end
end

genvar reg_id;
generate
	for (reg_id = 0; reg_id < DEPTH; reg_id = reg_id + 1) begin: gen_chain_stages
		assign o_data[reg_id] = r_data[reg_id];
	end
endgenerate

endmodule