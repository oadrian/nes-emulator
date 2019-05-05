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

  input logic [7:0] dmc_read_data,
  output logic dmc_re,
  output logic [14:0] dmc_addr,

  output logic [7:0] reg_data_out,
  output logic irq_l,
  output logic [15:0] audio_out);

  logic [23:0] reg_updates;
  logic [23:0][7:0] reg_array;

  logic [3:0] pulse0_out, pulse1_out, triangle_out, noise_out;
  logic [6:0] dmc_out;

  logic [4:0] lengths_non_zero;

  logic status_read;

//TODO: HOOK THIS UP
  logic clear_irq_l;

  assign status_read = ~reg_we & reg_en & (reg_addr == 5'h15); 
  mem_map_registers mm_reg (.*);

  triangle_t triangle_sigs;
  pulse_t pulse0_sigs, pulse1_sigs;
  noise_t noise_sigs;
  dmc_t dmc_sigs;
  status_t status_signals;
  frame_counter_t fc_signals;

  logic quarter_clk_en, half_clk_en;
  logic frame_interrupt;
  logic dmc_irq_l;

  assign irq_l = ~frame_interrupt & dmc_irq_l;
  //TODO: DMC does not seem to have non_zero signal

  always_ff @(posedge clk, negedge rst_l)
    if (~rst_l)
      reg_data_out <= 8'b0;
    else if (cpu_clk_en)
      reg_data_out <= {~dmc_irq_l, frame_interrupt, 1'b0, lengths_non_zero};


  always_comb begin
    triangle_sigs = get_triangle_signals(reg_array);
    pulse0_sigs = get_pulse_signals(reg_array, 1'b0);
    pulse1_sigs = get_pulse_signals(reg_array, 1'b1);
    noise_sigs = get_noise_signals(reg_array);
    dmc_sigs = get_dmc_signals(reg_array);
    status_signals = get_status_signals(reg_array);
    fc_signals = get_frame_counter_signals(reg_array);
  end

  frame_counter fc (
  .clk, .rst_l, .cpu_clk_en, .apu_clk_en,
  .addr(direct_addr), .data_in(direct_data_in), .we(direct_we),
  .interrupt(frame_interrupt),
  .quarter_clk_en, .half_clk_en);

  pulse_channel #(.PULSE_CARRY(1)) pulse0_channel (
    .clk, .rst_l, .cpu_clk_en, .apu_clk_en, .quarter_clk_en,
    .half_clk_en, .disable_l(status_signals.pulse0_en),
    .duty(pulse0_sigs.duty), .length_halt(pulse0_sigs.length_halt),
    .const_vol(pulse0_sigs.const_vol), .vol(pulse0_sigs.vol),
    .env_load(reg_updates[0]), .sweep_load(reg_updates[1]), 
    .length_load(reg_updates[3]),
    .timer_load_lo(reg_updates[2]),
    .timer_load_hi(reg_updates[3]),
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
    .timer_load_lo(reg_updates[6]),
    .timer_load_hi(reg_updates[7]),
    .sweep_sigs(pulse1_sigs.sweep_sigs),
    .timer_period_in(pulse1_sigs.timer_period_in),
    .length_load_data(pulse1_sigs.length_load_data),
    .length_non_zero(lengths_non_zero[1]),
    .out(pulse1_out));

  logic [4:0] next_status, status;

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

//TODO: VERIFY THAT MEMDATA IS CONNECTED AND ITS SYNCHRONOUS OR COMBINATIONAL
//TODO: DRIVE IRQ_L WITH DMC IRQ_L. NOT JUST FRAM COUNTER
  dmc dm_channel (
    .loop(dmc_sigs.loop), .disable_l(status_signals.dmc_en),
    .rate_index(dmc_sigs.rate_index), .addr_load(reg_updates[18]),
    .length_load(reg_updates[19]), .addr_in(dmc_sigs.addr),
    .length_in(dmc_sigs.length), .mem_data(dmc_read_data), 
    .irq_l(dmc_irq_l), .mem_re(dmc_re), .addr_out(dmc_addr), 
    .direct_load(reg_updates[17]),
    .direct_load_data(dmc_sigs.direct_load_data),
    .out(dmc_out), 
    .clear_irq_l(reg_updates[21] | (reg_updates[16] & ~reg_array[16][7])),
    .non_zero(lengths_non_zero[4]),
    .*);

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

function dmc_t get_dmc_signals (
  input [23:0][7:0] reg_array);

  dmc_t result;
  result.rate_index = reg_array[16][3:0];
  result.loop = reg_array[16][6];
  result.irq_en = reg_array[16][7];
  result.direct_load_data = reg_array[17][6:0];
  result.addr = reg_array[18];
  result.length = reg_array[19];
  return result;
endfunction
