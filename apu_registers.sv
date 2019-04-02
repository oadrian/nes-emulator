`default_nettype none

module apu_registers (
  input logic clk, rst_l,
  input logic cpu_clk_en,
  input logic [15:0] reg_addr,
  input logic [7:0] reg_data_in,
  input logic reg_en, reg_we,

  output logic [23:0] reg_updates,
  output logic [23:0][7:0] reg_array);

  logic [23:0][7:0] next_reg_array;
  logic [23:0] next_reg_updates;
  logic [4:0] reg_array_i;

  assign reg_array_i = reg_addr[4:0];

  always_comb begin
    next_reg_array = reg_array;
    next_reg_array[reg_array_i] = reg_data_in;

    next_reg_updates = reg_updates;
    next_reg_updates[reg_array_i] = 1'b1;
  end

  register #(.WIDTH($bits(reg_array)), .RES_VAL(0)) registers (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(reg_en & reg_we), 
    .d(next_reg_array), .q(reg_array));

  register #(.WIDTH($bits(reg_updates)), .RES_VAL(0)) address_register (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(reg_en & reg_we), 
    .d(next_reg_updates), .q(reg_updates));

endmodule: apu_registers
