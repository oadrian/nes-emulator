`default_nettype none

module apu (
  input logic clk, rst_l,
  input logic cpu_clk_en, apu_clk_en,
  input logic [4:0] reg_addr,
  input logic [7:0] reg_data,
  input logic reg_en, reg_we,

  output logic [3:0] triangle_wave);

  logic [23:0] reg_updates;
  logic [23:0][7:0] reg_array;

  logic [3:0] pulse0_out;

  mem_map_registers mm_reg (.*);

  
  triangle_t triangle_signals;
  pulse_t pulse0_sigs, pulse1_sigs;
  status_t status_signals;
  frame_counter_t fc_signals;

  always_comb begin
    triangle_signals = get_triangle_signals(reg_array);
    pulse0_sigs = get_pulse_signals(reg_array, 1);
    pulse1_sigs = get_pulse_signals(reg_array, 2);
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
  triangle_channel tc (
    .clk, .rst_l, .cpu_clk_en, .quarter_clk_en, .half_clk_en, 
    .disable_l(status_signals.triangle_en), 
    .length_halt(triangle_signals.length_halt), 
    .linear_load(reg_updates[8] | reg_updates[11]), 
    .length_load(reg_updates[11]), 
    .linear_load_data(triangle_signals.linear_load_data),
    .timer_load_data(triangle_signals.timer_load_data),
    .length_load_data(triangle_signals.length_load_data),
    .length_non_zero(lengths_non_zero[2]),
    .wave(triangle_wave));

  pulse_channel #(.PULSE_CHANNEL(0)) pulse0_channel (
    .clk, .rst_l, .cpu_clk_en, .apu_clk_en, .quarter_clk_en,
    .half_clk_en, .disable_l(status_signals.pulse0_en),
    .duty(pulse0_sigs.duty), .length_halt(pulse0_sigs.length_halt),
    .const_vol(pulse0_sigs.const_vol), .vol(pulse0_sigs.vol),
    .env_load(reg_updates[0]), .sweep_load(reg_updates[1]), 
    .length_load(reg_updates[3]),
    .sweep_sigs(pulse0_sigs.sweep_sigs),
    .timer_period_in(pulse0_sigs.timer_period_in),
    .length_load_data(pulse0_sigs.length_load_data),
    .length_non_zero(lengths_non_zero[0]),
    .out(pulse0_out));

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

function pulse_t get_pulse_signals (
  input [23:0][7:0] reg_array,
  input [1:0] channel);

  if (channel == 0)
    return reg_array[3:0];
  else if (channel == 1)
    return reg_array[7:4];
  return 32'b0;
endfunction

function status_t get_status_signals (
  input [23:0][7:0] reg_array);

  return reg_array[21][4:0];
endfunction

function frame_counter_t get_frame_counter_signals (
  input [23:0][7:0] reg_array);

  return reg_array[23][7:6];
endfunction
