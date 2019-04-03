`default_nettype none

module apu (
  input logic clk, rst_l,
  input logic cpu_clk_en,
  input logic [15:0] reg_addr,
  input logic [7:0] reg_data_in,
  input logic reg_en, reg_we);

  logic [23:0] reg_updates;
  logic [23:0][7:0] reg_array;

  mem_map_registers mm_reg (.*);
  
  triangle_t triangle_signals;
  status_t status_signals;
  frame_counter_t fc_signals;

  always_comb begin
    triangle_signals = get_triangle_signals(reg_array);
    status_signals = get_status_signals(reg_array);
    fc_signals = get_frame_counter_signals(reg_array);
  end

  logic quarter_clk_en, half_clk_en;
  logic frame_interrupt;

  frame_counter fc (
    .clk, .rst_l, .cpu_clk_en, .mode(fc_signals.mode), 
    .load(reg_updates[23]),
    .inhibit_interrupt(fc_signals.inhibit_interrupt), 
    .interrupt(frame_interrupt),
    .quarter_clk_en, .half_clk_en);

  logic [4:0] lengths_non_zero;
  logic [3:0] triangle_wave;
  triangle_channel tc (
    .clk, .rst_l, .cpu_clk_en, .quarter_clk_en, .half_clk_en, 
    .disable_l(status_signals.triangle_en), 
    .length_halt(triangle_signals.length_halt), 
    .linear_load(reg_updates[8] & reg_updates[11]), 
    .length_load(reg_updates[11]), 
    .linear_load_data(triangle_signals.linear_load_data),
    .timer_load_data(triangle_signals.timer_load_data),
    .length_load_data(triangle_signals.length_load_data),
    .length_non_zero(lengths_non_zero[2]),
    .wave(triangle_wave));

endmodule: apu

function triangle_t get_triangle_signals (
  input [23:0][7:0] reg_array);

  triangle_t result;

  result.linear_load_data = reg_array[8][6:0];
  result.length_halt = reg_array[8][7];
  result.timer_load_data = {reg_array[11][2:0], reg_array[10]};
  result.length_load_data = reg_array[11][7:3];
  return result;
endfunction

function status_t get_status_signals (
  input [23:0][7:0] reg_array);

  return reg_array[21][4:0];
endfunction

function frame_counter_t get_frame_counter_signals (
  input [23:0][7:0] reg_array);

  return reg_array[23][7:6];
endfunction
