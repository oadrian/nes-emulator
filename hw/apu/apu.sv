`default_nettype none

module apu (
  input logic clk, rst_l,
  input logic cpu_clk_en, apu_clk_en,
  input logic [4:0] reg_addr,
  input logic [7:0] reg_data,
  input logic reg_en, reg_we,

  output logic irq_l,
  output logic [15:0] audio_out);

  logic [23:0] reg_updates;
  logic [23:0][7:0] reg_array;

  logic [3:0] pulse0_out, pulse1_out, triangle_out, noise_out;
  logic [6:0] dmc_out;

  logic [4:0] lengths_non_zero;


  mem_map_registers mm_reg (.*);

  triangle_t triangle_sigs;
  pulse_t pulse0_sigs, pulse1_sigs;
  noise_t noise_sigs;
  status_t status_signals;
  frame_counter_t fc_signals;

  logic quarter_clk_en, half_clk_en;
  logic frame_interrupt;

  assign irq_l = ~frame_interrupt;

  always_comb begin
    triangle_sigs = get_triangle_signals(reg_array);
    pulse0_sigs = get_pulse_signals(reg_array, 1'b0);
    pulse1_sigs = get_pulse_signals(reg_array, 1'b1);
    noise_sigs = get_noise_signals(reg_array);
    status_signals = get_status_signals(reg_array);
    fc_signals = get_frame_counter_signals(reg_array);
  end

  frame_counter fc (
  .clk, .rst_l, .cpu_clk_en, .apu_clk_en, .mode(fc_signals.mode), 
  .load(reg_updates[23]),
  .inhibit_interrupt(fc_signals.inhibit_interrupt), 
  .interrupt(frame_interrupt),
  .quarter_clk_en, .half_clk_en);
  
  triangle_channel tc (
    .clk, .rst_l, .cpu_clk_en, .quarter_clk_en, .half_clk_en, 
    .disable_l(status_signals.triangle_en), 
    .length_halt(triangle_sigs.length_halt), 
    .linear_load(reg_updates[11]), 
    .length_load(reg_updates[11]), 
    .linear_load_data(triangle_sigs.linear_load_data),
    .timer_load_data(triangle_sigs.timer_load_data),
    .length_load_data(triangle_sigs.length_load_data),
    .length_non_zero(lengths_non_zero[2]),
    .out(triangle_out));

  pulse_channel #(.PULSE_CARRY(1)) pulse0_channel (
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

  pulse_channel #(.PULSE_CARRY(0)) pulse1_channel (
    .clk, .rst_l, .cpu_clk_en, .apu_clk_en, .quarter_clk_en,
    .half_clk_en, .disable_l(status_signals.pulse1_en),
    .duty(pulse1_sigs.duty), .length_halt(pulse1_sigs.length_halt),
    .const_vol(pulse1_sigs.const_vol), .vol(pulse1_sigs.vol),
    .env_load(reg_updates[4]), .sweep_load(reg_updates[5]), 
    .length_load(reg_updates[7]),
    .sweep_sigs(pulse1_sigs.sweep_sigs),
    .timer_period_in(pulse1_sigs.timer_period_in),
    .length_load_data(pulse1_sigs.length_load_data),
    .length_non_zero(lengths_non_zero[1]),
    .out(pulse1_out));

  noise_channel noise_channel (
    .clk, .rst_l, .cpu_clk_en, .apu_clk_en, .quarter_clk_en,
    .half_clk_en, .disable_l(status_signals.noise_en),
    .vol(noise_sigs.vol), .const_vol(noise_sigs.const_vol),
    .length_halt(noise_sigs.length_halt), 
    .timer_period_in(noise_sigs.timer_period_in),
    .mode(noise_sigs.mode), .length_load_data(noise_sigs.length_load_data),
    .length_load(reg_updates[15]), .env_load(reg_updates[12]),
    .length_non_zero(lengths_non_zero[3]),
    .out(noise_out));

  // TODO: Instantiate the dmc channel
  assign dmc_out = 7'b0;

  mixer non_linear_mixer (
    .pulse0(pulse0_out), .pulse1(pulse1_out), .triangle(triangle_out),
    .noise(noise_out), .dmc(dmc_out), .out(audio_out));

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
  input channel);

  if (channel == 0)
    return reg_array[3:0];
  else
    return reg_array[7:4];
endfunction

function noise_t get_noise_signals (
  input [23:0][7:0] reg_array);

  noise_t result;

  result.vol = reg_array[12][3:0];
  result.const_vol = reg_array[12][4];
  result.length_halt = reg_array[12][5];
  result.timer_period_in = reg_array[14][3:0];
  result.mode = reg_array[14][7];
  result.length_load_data = reg_array[15][7:3];
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
