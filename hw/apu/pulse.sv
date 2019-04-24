`default_nettype none

module pulse_channel #(parameter PULSE_CARRY=0) (
  input logic clk, rst_l,

  input logic cpu_clk_en, apu_clk_en,
  input logic quarter_clk_en, half_clk_en,

  input logic disable_l,

  input logic [1:0] duty,
  input logic length_halt, // Also envelope's loop flag
  input logic const_vol,
  input logic [3:0] vol, // Also the period for envelope divider

  input logic env_load, sweep_load, length_load, timer_load,

  input sweep_t sweep_sigs,
  input logic [10:0] timer_period_in,
  input logic [4:0] length_load_data,

  output logic length_non_zero,
  output logic [3:0] out);


  logic mute;
  logic update_timer_period;
  logic [10:0] timer_period, sweep_timer_period;

  logic timer_pulse;

  logic loop_flag;
  logic [3:0] env_vol_out;

  logic [3:0][7:0] seqs;
  logic [7:0] seq;
  logic [2:0] seq_i;
  logic seq_out;

  logic [3:0] gate1_out, gate2_out;

  always_comb begin
    gate1_out = mute ? 4'b0 : env_vol_out;
    gate2_out = seq_out ? gate1_out : 4'b0;
    out = length_non_zero ? gate2_out : 4'b0;
  end
  
  always_comb begin
    seqs = {8'b1111_1001, 8'b0001_1110, 8'b0000_0110, 8'b0000_0010};
    seq = seqs[duty];
    seq_out = seq[seq_i];
  end

  logic choose_sweep;

  assign loop_flag = length_halt;
  assign timer_period = choose_sweep ? sweep_timer_period : 
                                              timer_period_in;

  always_ff @(posedge clk or negedge rst_l)
    if(~rst_l)
      choose_sweep <= 1'b0;
    else if (update_timer_period)
      choose_sweep <= 1'b1;
    else if (timer_load)
      choose_sweep <= 1'b0;

  up_counter #(.WIDTH(3), .RES_VAL(0)) seq_i_counter (
    .clk, .rst_l, .clk_en(apu_clk_en), .en(timer_pulse), .load(length_load),
    .load_data(3'b0), .count(seq_i));

  divider #(.WIDTH(11), .RES_VAL(0)) timer (
    .clk, .rst_l, .clk_en(apu_clk_en), .load(1'b0), 
    .load_data(timer_period), .pulse(timer_pulse));

  sweep #(.CARRY(PULSE_CARRY)) sweep_unit (
    .clk, .rst_l, .cpu_clk_en, .half_clk_en, .enable(sweep_sigs.enable),
    .negate(sweep_sigs.negate), .load(sweep_load), 
    .div_period(sweep_sigs.period), 
    .shift_count(sweep_sigs.shift_count),
    .timer_period_in, .mute, .change_timer_period(update_timer_period),
    .timer_period_out(sweep_timer_period));

  envelope env_unit (
    .clk, .rst_l, .cpu_clk_en, .quarter_clk_en, .load(env_load),
    .loop_flag, .const_vol, .vol_in(vol), .vol_out(env_vol_out));

  length_counter len_counter (
    .clk, .rst_l, .cpu_clk_en, .half_clk_en, .halt(length_halt), .disable_l,
    .load(length_load), .load_data(length_load_data), 
    .non_zero(length_non_zero));
    


endmodule: pulse_channel
