`default_nettype none

//TODO: ALLOW FOR READING OF THE STATUS apu_register
module mem_map_registers (
  input logic clk, rst_l,
  input logic cpu_clk_en,
  input logic [4:0] reg_addr,
  input logic [7:0] reg_data,
  input logic reg_en, reg_we,

  output logic [23:0] reg_updates,
  output logic [23:0][7:0] reg_array);

  logic [23:0][7:0] next_reg_array;
  logic [23:0] next_reg_updates;

  always_comb begin
    next_reg_array = reg_array;
    next_reg_array[reg_addr] = reg_data;

    next_reg_updates = 24'b0;
    next_reg_updates[reg_addr] = reg_en & reg_we;
  end

  apu_register #(.WIDTH($bits(reg_array)), .RES_VAL(0)) registers (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(reg_en & reg_we), 
    .d(next_reg_array), .q(reg_array));

  apu_register #(.WIDTH($bits(reg_updates)), .RES_VAL(0)) address_register (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_reg_updates), .q(reg_updates));

endmodule: mem_map_registers
