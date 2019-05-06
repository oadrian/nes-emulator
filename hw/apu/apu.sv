`default_nettype none

module apu (
  input logic clk, rst_l,
  input logic cpu_clk_en, apu_clk_en,

  input logic [15:0] direct_addr,
  input logic [7:0] direct_data_in,
  input logic direct_we,

  input logic [4:0] reg_addr,
  input logic [7:0] reg_data_in,
  input logic reg_en, reg_we,

  output logic [7:0] reg_data_out,
  output logic irq_l,
  output logic [15:0] audio_out);

  logic [23:0] reg_updates;
  logic [23:0][7:0] reg_array;

  logic [3:0] pulse0_out, pulse1_out, triangle_out, noise_out;
  logic [6:0] dmc_out;

  logic [4:0] next_status, status;
  logic [4:0] lengths_non_zero;

  logic status_read;

  assign status_read = ~reg_we & reg_en & (reg_addr == 5'h15); 
  mem_map_registers mm_reg (.*);


  noise_t noise_sigs;
  status_t status_signals;
  frame_counter_t fc_signals;

  logic quarter_clk_en, half_clk_en;
  logic frame_interrupt;

  assign irq_l = ~frame_interrupt;

  always_ff @(posedge clk, negedge rst_l)
    if (~rst_l)
      reg_data_out <= 8'b0;
    else if (cpu_clk_en)
      reg_data_out <= {1'b1, frame_interrupt, 1'b0, lengths_non_zero};


  always_comb begin
    noise_sigs = get_noise_signals(reg_array);
    status_signals = get_status_signals(reg_array);
  end

  frame_counter fc (
  .clk, .rst_l, .cpu_clk_en, .apu_clk_en,
  .addr(direct_addr), .data_in(direct_data_in), .we(direct_we),
  .interrupt(frame_interrupt),
  .quarter_clk_en, .half_clk_en);

  pulse_channel #(.PULSE_CARRY(1)) pulse0_channel (
    .clk, .rst_l, .cpu_clk_en, .apu_clk_en, .quarter_clk_en,
    .half_clk_en, .disable_l(status[0]),
    .addr(direct_addr), .data_in(direct_data_in), .we(direct_we),
    .length_non_zero(lengths_non_zero[0]),
    .out(pulse0_out));

  pulse_channel #(.PULSE_CARRY(0)) pulse1_channel (
    .clk, .rst_l, .cpu_clk_en, .apu_clk_en, .quarter_clk_en,
    .half_clk_en, .disable_l(status[1]),
    .addr(direct_addr), .data_in(direct_data_in), .we(direct_we),
    .length_non_zero(lengths_non_zero[1]),
    .out(pulse1_out));


  always_comb
    if (direct_we & (direct_addr == 16'h4015))
      next_status = direct_data_in[4:0];
    else
      next_status = status;

  apu_register #(.WIDTH(5), .RES_VAL(0)) status_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_status), .q(status));

  triangle_channel tc (
    .clk, .rst_l, .cpu_clk_en, .quarter_clk_en, .half_clk_en,
    .addr(direct_addr), .data_in(direct_data_in), .we(direct_we),
    .disable_l(status[2]), 
    .length_non_zero(lengths_non_zero[2]),
    .out(triangle_out));

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

  mixer non_linear_mixer (
    .pulse0(pulse0_out), .pulse1(pulse1_out), .triangle(triangle_out),
    .noise(noise_out), .dmc(7'b0), .out(audio_out));

endmodule: apu


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

