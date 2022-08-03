module chain_dpe # (
	parameter IDATAW = 8,
	parameter LANES = 40,
	parameter ODATAW = (2*IDATAW) + $clog2(LANES),
	parameter BATCH = 1,
	parameter NUM_DSPS = LANES / 4
)(
	input clk,
	input rst,
	input signed [IDATAW-1:0] i_data [0:NUM_DSPS-1][0:3],
	input i_valid,
	input i_load,
	output signed [ODATAW-1:0] o_data [0:BATCH-1],
	output o_valid
);

localparam DSP_PIPELINE = 4;
localparam VALID_PIPELINE = DSP_PIPELINE + NUM_DSPS;

logic signed [IDATAW-1:0] r_data_load [0:NUM_DSPS-1][0:BATCH-1][0:3];
logic signed [IDATAW-1:0] r_data_comp [0:LANES-1];

pipeline # (.DWIDTH(1), .DEPTH(VALID_PIPELINE)) r_valid (.clk(clk), .rst(rst), .en(1'b1), .i_data(i_valid && !i_load), .o_data(o_valid));

logic r_load [0:0];
logic r_load_ctrl [0:NUM_DSPS-1][0:0];
assign r_load[0] = i_load && i_valid;
chain # (.DWIDTH(1), .LANES(1), .DEPTH(NUM_DSPS)) r_load_chain (.clk(clk), .rst(rst), .en(1'b1), .i_data(r_load), .o_data(r_load_ctrl));

genvar chain_id;
generate
for (chain_id = 0; chain_id < NUM_DSPS; chain_id = chain_id + 1) begin: gen_chains
	if (chain_id == 0) begin
		chain # (.DWIDTH(IDATAW), .LANES(4), .DEPTH(BATCH)) 
			r_reg_banks (.clk(clk), .rst(rst), .en(r_load[0]), .i_data(i_data[chain_id]), .o_data(r_data_load[chain_id]));
	end else begin
		chain # (.DWIDTH(IDATAW), .LANES(4), .DEPTH(BATCH)) 
			r_reg_banks (.clk(clk), .rst(rst), .en(r_load_ctrl[chain_id-1][0]), .i_data(i_data[chain_id]), .o_data(r_data_load[chain_id]));
	end
end
endgenerate

integer lane_id, batch_id, stage_id;

// Register streamed input vector if i_valid is high and i_load is low
always @ (posedge clk) begin
	if (rst) begin
		for (lane_id = 0; lane_id < LANES; lane_id = lane_id + 1) begin
			r_data_comp[lane_id] <= 0;
		end
	end else begin
		if (i_valid && !i_load) begin
			for (lane_id = 0; lane_id < LANES; lane_id = lane_id + 1) begin
				r_data_comp[lane_id] <= i_data[lane_id/4][lane_id%4];
			end
		end	
	end
end

// Signals for chainning DSP blocks and delaying inputs for the cascade structure
logic [63:0] r_dsp_chain [0:BATCH-1][0:NUM_DSPS-1];
logic [ODATAW-1:0] r_dsp_result [0:BATCH-1][0:NUM_DSPS-1];
logic [IDATAW-1:0] r_dsp_load_delay [0:BATCH-1][0:LANES-1];
logic [IDATAW-1:0] r_dsp_comp_delay [0:LANES-1];

// Instantiate and connect the DSP blocks
genvar dsp_id, dsp_batch_id;
generate
for (dsp_id = 0; dsp_id < NUM_DSPS; dsp_id = dsp_id + 1) begin: gen_dsp
	if (dsp_id == 0) begin
		for (dsp_batch_id = 0; dsp_batch_id < BATCH; dsp_batch_id = dsp_batch_id + 1) begin: gen_batch_dsp
			dsp_block_int8 # (
				.USE_CHAINADDER("false")
			) first_dsp_inst (
				.clk(clk),
				.rst(rst),
				.ax(r_data_comp[(dsp_id * 4)]),
				.ay(r_data_load[dsp_id][dsp_batch_id][0]),
				.bx(r_data_comp[(dsp_id * 4) + 1]),
				.by(r_data_load[dsp_id][dsp_batch_id][1]),
				.cx(r_data_comp[(dsp_id * 4) + 2]),
				.cy(r_data_load[dsp_id][dsp_batch_id][2]),
				.dx(r_data_comp[(dsp_id * 4) + 3]),
				.dy(r_data_load[dsp_id][dsp_batch_id][3]),
				.chainout(r_dsp_chain[dsp_batch_id][dsp_id]),
				.resulta(r_dsp_result[dsp_batch_id][dsp_id])
			);
		end
	end else begin
		for (dsp_batch_id = 0; dsp_batch_id < BATCH; dsp_batch_id = dsp_batch_id + 1) begin: gen_batch_dsp
			dsp_block_int8 chain_dsp_inst (
				.clk(clk),
				.rst(rst),
				.ax(r_data_comp[(dsp_id*4)]),
				.ay(r_data_load[dsp_id][dsp_batch_id][0]),
				.bx(r_data_comp[(dsp_id * 4)+1]),
				.by(r_data_load[dsp_id][dsp_batch_id][1]),
				.cx(r_data_comp[(dsp_id * 4)+2]),
				.cy(r_data_load[dsp_id][dsp_batch_id][2]),
				.dx(r_data_comp[(dsp_id * 4)+3]),
				.dy(r_data_load[dsp_id][dsp_batch_id][3]),
				.chainin(r_dsp_chain[dsp_batch_id][dsp_id-1]),
				.chainout(r_dsp_chain[dsp_batch_id][dsp_id]),
				.resulta(r_dsp_result[dsp_batch_id][dsp_id])
			);
		end
	end
end

for (dsp_batch_id = 0; dsp_batch_id < BATCH; dsp_batch_id = dsp_batch_id + 1) begin: gen_batch_dsp
	assign o_data[dsp_batch_id] = r_dsp_result[dsp_batch_id][NUM_DSPS-1];
end
endgenerate

endmodule