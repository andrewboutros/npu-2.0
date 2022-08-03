module bram # (
	parameter DATAW = 32,
	parameter DEPTH = 512,
	parameter ADDRW = $clog2(DEPTH)
)(
	input clk,
	input [DATAW-1:0] data,
	input [ADDRW-1:0] rdaddress,
	input [ADDRW-1:0] wraddress,
	input wren,
	output [DATAW-1:0] q
);

logic [DATAW-1:0] sub_wire0;
assign q = sub_wire0[DATAW-1:0];

altera_syncram  altera_syncram_component (
	.address_a (wraddress),
	.address_b (rdaddress),
	.clock0 (clk),
	.data_a (data),
	.wren_a (wren),
	.q_b (sub_wire0),
	.aclr0 (1'b0),
	.aclr1 (1'b0),
	.address2_a (1'b1),
	.address2_b (1'b1),
	.addressstall_a (1'b0),
	.addressstall_b (1'b0),
	.byteena_a (1'b1),
	.byteena_b (1'b1),
	.clock1 (1'b1),
	.clocken0 (1'b1),
	.clocken1 (1'b1),
	.clocken2 (1'b1),
	.clocken3 (1'b1),
	.data_b ({32{1'b1}}),
	.eccencbypass (1'b0),
	.eccencparity (8'b0),
	.eccstatus (),
	.q_a (),
	.rden_a (1'b1),
	.rden_b (1'b1),
	.sclr (1'b0),
	.wren_b (1'b0)
);

defparam
	altera_syncram_component.address_aclr_b  = "NONE",
	altera_syncram_component.address_reg_b  = "CLOCK0",
	altera_syncram_component.clock_enable_input_a  = "BYPASS",
	altera_syncram_component.clock_enable_input_b  = "BYPASS",
	altera_syncram_component.clock_enable_output_b  = "BYPASS",
	altera_syncram_component.enable_ecc  = "FALSE",
	altera_syncram_component.enable_force_to_zero  = "TRUE",
	altera_syncram_component.optimization_option  = "HIGH_SPEED",
	altera_syncram_component.intended_device_family  = "Agilex",
	altera_syncram_component.lpm_type  = "altera_syncram",
	altera_syncram_component.numwords_a  = DEPTH,
	altera_syncram_component.numwords_b  = DEPTH,
	altera_syncram_component.operation_mode  = "DUAL_PORT",
	altera_syncram_component.outdata_aclr_b  = "NONE",
	altera_syncram_component.outdata_sclr_b  = "NONE",
	altera_syncram_component.outdata_reg_b  = "CLOCK0",
	altera_syncram_component.power_up_uninitialized  = "FALSE",
	altera_syncram_component.ram_block_type  = "M20K",
	altera_syncram_component.read_during_write_mode_mixed_ports  = "DONT_CARE",
	altera_syncram_component.widthad_a  = ADDRW,
	altera_syncram_component.widthad_b  = ADDRW,
	altera_syncram_component.width_a  = DATAW,
	altera_syncram_component.width_b  = DATAW,
	altera_syncram_component.width_byteena_a  = 1;

endmodule