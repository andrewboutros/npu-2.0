module reduction_tree # (
	parameter DATAW = 18,
	parameter LANES = 1,
	parameter REDUCTION_SIZE = 40,
	parameter NEXT_LVL_REDUCTION_SIZE = ((REDUCTION_SIZE % 2) == 0)? REDUCTION_SIZE/2 : REDUCTION_SIZE/2 + 1
)(
	input clk,
	input rst,
	input signed [DATAW-1:0] i_data [0:REDUCTION_SIZE-1][0:LANES-1],
	input i_valid,
	output logic signed [DATAW+$clog2(REDUCTION_SIZE)-1:0] o_data [0:LANES-1],
	output logic o_valid
);

logic signed [DATAW:0] r_sum [0:NEXT_LVL_REDUCTION_SIZE-1][0:LANES-1];
logic r_valid;

genvar reduction_id, lane_id;
generate
	if (REDUCTION_SIZE == 1) begin
		always @ (posedge clk) begin
			o_data <= i_data[0];
			if (rst) o_valid <= 1'b0;
			else o_valid <= i_valid;
		end
	end else if (REDUCTION_SIZE == 2) begin
		for (lane_id = 0; lane_id < LANES; lane_id = lane_id + 1) begin: gen_reduce_two
			always @ (posedge clk) begin
				o_data[lane_id] <= i_data[0][lane_id] + i_data[1][lane_id];
			end
		end
		always @ (posedge clk) begin
			if (rst) o_valid <= 1'b0;
			else o_valid <= i_valid;
		end
	end else begin
		for (reduction_id = 0; reduction_id < REDUCTION_SIZE/2; reduction_id = reduction_id + 1) begin: gen_reduce_n
			for (lane_id = 0; lane_id < LANES; lane_id = lane_id + 1) begin: gen_reduce_n_even
				always @ (posedge clk) begin
					r_sum[reduction_id][lane_id] <= i_data[(2*reduction_id)][lane_id] + i_data[(2*reduction_id)+1][lane_id];
				end
			end
		end
		if ((REDUCTION_SIZE % 2) == 1) begin
			for (lane_id = 0; lane_id < LANES; lane_id = lane_id + 1) begin: gen_reduce_n_odd
				always @ (posedge clk) begin
					r_sum[NEXT_LVL_REDUCTION_SIZE-1][lane_id] <= i_data[REDUCTION_SIZE-1][lane_id];
				end
			end
		end
		always @ (posedge clk) begin
			if (rst) r_valid <= 1'b0;
			else r_valid <= i_valid;
		end
		reduction_tree # (
			.DATAW(DATAW+1),
			.LANES(LANES),
			.REDUCTION_SIZE(NEXT_LVL_REDUCTION_SIZE)
		) next_level (
			.clk(clk),
			.rst(rst),
			.i_data(r_sum),
			.i_valid(r_valid),
			.o_data(o_data),
			.o_valid(o_valid)
		);
	end
endgenerate

endmodule