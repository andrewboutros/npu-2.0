/*
This module implements an INT8 dot product engine (DPE) using a chain of Agilex DSP blocks.
It has a single data input that is used to load B{0}, ..., B{BATCH-1} input vectors into a set of register banks, then
stream different A input vectors to compute a batched dot-product: RES{0} = A . B{0}, ..., RES{BATCH-1} = A . B{BATCH-1}
Module Parameters:
- IDATAW & ODATAW ==> Input and output bitwidth
- LANES ==> Length of the dot-product operation (# elements per input vector)
- BATCH ==> Batch size of the dot-product operation
Module Ports:
- clk, rst ==> Clock and active high reset signals
- i_data ==> Input vector (LANES x IDATAW bits)
- i_valid ==> Bit indicating that input vector has valid data
- i_load ==> Input vector is pushed into chained register banks if set to 1, or streamed to the DSP block ports if 0
- o_data ==> Dot product results (BATCH x ODATAW bits)
- o_valid ==> Bit indicating that output results are valid
*/

module dpe_chain # (
	parameter IDATAW = 8,
	parameter ODATAW = 32,
	parameter LANES = 164,
	parameter BATCH = 1
)(
	input clk,
	input rst,
	input signed [IDATAW-1:0] i_data [0:LANES-1],
	input i_valid,
	input i_load,
	output signed [ODATAW-1:0] o_data [0:BATCH-1],
	output o_valid
);

// Local parameter declaration
localparam DSP_PIPELINE = 4; // Agilex DSP block pipeline stages 
localparam NUM_DSPS = LANES / 4; // No. of DSP blocks used in the DPE (each DSP block packs 4x INT8 multiplies)
localparam VALID_PIPELINE = DSP_PIPELINE + NUM_DSPS; // No. of pipeline stages from i_valid to o_valid

// Module signals
logic signed [IDATAW-1:0] r_data_load [0:BATCH-1][0:LANES-1]; // Holds loaded input vectors
logic signed [IDATAW-1:0] r_data_comp [0:LANES-1]; // Holds streamed input vectors

// Valid signal pipeline
pipeline # (.DWIDTH(1), .DEPTH(VALID_PIPELINE)) r_valid (.clk(clk), .rst(rst), .en(1'b1), .i_data(i_valid && !i_load), .o_data(o_valid));
// Chain for loaded input vectors (push a new vector to the chain if i_valid and i_load are both high)
chain # (.DWIDTH(IDATAW), .LANES(LANES), .DEPTH(BATCH)) r_reg_banks (.clk(clk), .rst(rst), .en(i_valid && i_load), .i_data(i_data), .o_data(r_data_load));

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
				r_data_comp[lane_id] <= i_data[lane_id];
			end
		end	
	end
end

// Signals for chainning DSP blocks and delaying inputs for the cascade structure
logic [63:0] r_dsp_chain [0:BATCH-1][0:NUM_DSPS-1];
logic [17:0] r_dsp_result [0:BATCH-1][0:NUM_DSPS-1];
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
				.ay(r_data_load[dsp_batch_id][(dsp_id * 4)]),
				.bx(r_data_comp[(dsp_id * 4) + 1]),
				.by(r_data_load[dsp_batch_id][(dsp_id * 4) + 1]),
				.cx(r_data_comp[(dsp_id * 4) + 2]),
				.cy(r_data_load[dsp_batch_id][(dsp_id * 4) + 2]),
				.dx(r_data_comp[(dsp_id * 4) + 3]),
				.dy(r_data_load[dsp_batch_id][(dsp_id * 4) + 3]),
				.chainout(r_dsp_chain[dsp_batch_id][dsp_id]),
				.resulta(r_dsp_result[dsp_batch_id][dsp_id])
			);
		end
	end else begin
		pipeline # (.DWIDTH(IDATAW), .DEPTH(dsp_id)) r_ax (.clk(clk), .rst(rst), .en(1'b1), .i_data(r_data_comp[(dsp_id*4)]), .o_data(r_dsp_comp_delay[(dsp_id*4)]));
		pipeline # (.DWIDTH(IDATAW), .DEPTH(dsp_id)) r_bx (.clk(clk), .rst(rst), .en(1'b1), .i_data(r_data_comp[(dsp_id*4)+1]), .o_data(r_dsp_comp_delay[(dsp_id*4)+1]));
		pipeline # (.DWIDTH(IDATAW), .DEPTH(dsp_id)) r_cx (.clk(clk), .rst(rst), .en(1'b1), .i_data(r_data_comp[(dsp_id*4)+2]), .o_data(r_dsp_comp_delay[(dsp_id*4)+2]));
		pipeline # (.DWIDTH(IDATAW), .DEPTH(dsp_id)) r_dx (.clk(clk), .rst(rst), .en(1'b1), .i_data(r_data_comp[(dsp_id*4)+3]), .o_data(r_dsp_comp_delay[(dsp_id*4)+3]));
		
		for (dsp_batch_id = 0; dsp_batch_id < BATCH; dsp_batch_id = dsp_batch_id + 1) begin: gen_batch_dsp
			pipeline # (.DWIDTH(IDATAW), .DEPTH(dsp_id)) r_ay (.clk(clk), .rst(rst), .en(1'b1), .i_data(r_data_load[dsp_batch_id][(dsp_id*4)]), .o_data(r_dsp_load_delay[dsp_batch_id][(dsp_id*4)]));
			pipeline # (.DWIDTH(IDATAW), .DEPTH(dsp_id)) r_by (.clk(clk), .rst(rst), .en(1'b1), .i_data(r_data_load[dsp_batch_id][(dsp_id*4)+1]), .o_data(r_dsp_load_delay[dsp_batch_id][(dsp_id*4)+1]));
			pipeline # (.DWIDTH(IDATAW), .DEPTH(dsp_id)) r_cy (.clk(clk), .rst(rst), .en(1'b1), .i_data(r_data_load[dsp_batch_id][(dsp_id*4)+2]), .o_data(r_dsp_load_delay[dsp_batch_id][(dsp_id*4)+2]));
			pipeline # (.DWIDTH(IDATAW), .DEPTH(dsp_id)) r_dy (.clk(clk), .rst(rst), .en(1'b1), .i_data(r_data_load[dsp_batch_id][(dsp_id*4)+3]), .o_data(r_dsp_load_delay[dsp_batch_id][(dsp_id*4)+3]));

			dsp_block_int8 chain_dsp_inst (
				.clk(clk),
				.rst(rst),
				.ax(r_dsp_comp_delay[(dsp_id*4)]),
				.ay(r_dsp_load_delay[dsp_batch_id][(dsp_id*4)]),
				.bx(r_dsp_comp_delay[(dsp_id * 4)+1]),
				.by(r_dsp_load_delay[dsp_batch_id][(dsp_id*4)+1]),
				.cx(r_dsp_comp_delay[(dsp_id * 4)+2]),
				.cy(r_dsp_load_delay[dsp_batch_id][(dsp_id*4)+2]),
				.dx(r_dsp_comp_delay[(dsp_id * 4)+3]),
				.dy(r_dsp_load_delay[dsp_batch_id][(dsp_id*4)+3]),
				.chainin(r_dsp_chain[dsp_batch_id][dsp_id-1]),
				.chainout(r_dsp_chain[dsp_batch_id][dsp_id]),
				.resulta(r_dsp_result[dsp_batch_id][dsp_id])
			);
		end
	end
end

for (dsp_batch_id = 0; dsp_batch_id < BATCH; dsp_batch_id = dsp_batch_id + 1) begin: gen_batch_dsp
	assign o_data[dsp_batch_id] = {{(ODATAW-18){r_dsp_result[dsp_batch_id][NUM_DSPS-1][17]}}, r_dsp_result[dsp_batch_id][NUM_DSPS-1]};
end
endgenerate

endmodule