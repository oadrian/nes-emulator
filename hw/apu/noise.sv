`default_nettype none

module noise_channel (
  input logic clk, rst_l,
  input logic cpu_clk_en, apu_clk_en, half_clk_en, quarter_clk_en,
  input logic disable_l,

  input logic [3:0] vol,
  input logic const_vol,
  input logic length_halt,

  input logic [3:0] timer_period_in,
  input logic mode,
  input logic [4:0] length_load_data,
  input logic length_load, env_load,

  output logic length_non_zero,
  output logic [3:0] out);


  logic timer_pulse;
  logic loop_flag;
  logic feedback;
  logic [3:0] env_out, gate1_out;
  logic [11:0] timer_period;
  logic [0:15][11:0] lut;
  logic [14:0] next_shift_data, shift_data;


  assign loop_flag = length_halt;

  always_comb begin
    gate1_out = shift_data[0] ? 4'b0 : env_out;
    out = length_non_zero ? gate1_out : 4'b0;
  end

  always_comb begin
    lut = {12'd4, 12'd8, 12'd16, 12'd32,
           12'd64, 12'd96, 12'd128, 12'd160,
           12'd202, 12'd254, 12'd380, 12'd508,
           12'd762, 12'd1016, 12'd2034, 12'd4068};

    timer_period = lut[timer_period_in];
  end

  always_comb begin
    feedback = shift_data[0] ^ (mode ? shift_data[6] : shift_data[1]);
    next_shift_data = {feedback, shift_data[14:1]};
  end

  envelope env_unit (
    .clk, .rst_l, .cpu_clk_en, .quarter_clk_en, .load(env_load), .loop_flag,
    .const_vol, .vol_in(vol), .vol_out(env_out));

  apu_register #(.WIDTH(15), .RES_VAL(1)) shift_reg (
    .clk, .rst_l, .clk_en(apu_clk_en), .en(timer_pulse), 
    .d(next_shift_data), .q(shift_data));

  divider #(.WIDTH(4), .RES_VAL(0)) timer (
    .clk, .rst_l, .clk_en(apu_clk_en), .load(1'b0), 
    .load_data(timer_period), .pulse(timer_pulse));

  length_counter len_counter (
    .clk, .rst_l, .cpu_clk_en, .half_clk_en, .halt(length_halt), .disable_l,
    .load(length_load), .load_data(length_load_data), 
    .non_zero(length_non_zero));

endmodule: noise_channel
