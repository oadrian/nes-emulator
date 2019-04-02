`default_nettype none

module triangle_channel (
  input logic clk,
  input logic cpu_clk_en, counter_clk_en,
  input logic rst_l,
  input logic disable_l,
  input logic control_flag,
  input logic linear_load, timer_load, length_load,
  input logic [6:0] linear_load_data,
  input logic [10:0] timer_load_data,
  input logic [4:0] length_load_data,

  output logic linear_non_zero, length_non_zero,
  output logic [3:0] wave);


  logic timer_pulse;

  logic gate1_out, gate2_out;
  logic [31:0][3:0] seq;
  logic [4:0] next_seq_i, seq_i;

  assign seq = 128'hFEDCBA98765432100123456789ABCDEF;
  assign next_seq_i = seq_i + 5'b1;
  assign wave = seq[seq_i];

  assign gate1_out = linear_non_zero ? timer_pulse : 1'b0;
  assign gate2_out = length_non_zero ? gate1_out : 1'b0;

  register #(.WIDTH(5), .RES_VAL(0)) seq_i_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(timer_pulse), .d(next_seq_i), 
    .q(seq_i));
  
  divider #(.WIDTH(11), .RES_VAL(0)) triangle_timer (
    .clk, .rst_l, .clk_en(cpu_clk_en), .load(timer_load), 
    .load_data(timer_load_data), .pulse(timer_pulse));
  
  linear_counter triangle_linear_counter (
    .clk, .rst_l, .counter_clk_en, .clear_reload_l(control_flag), 
    .load(linear_load), .load_data(linear_load_data), 
    .non_zero(linear_non_zero));

  length_counter triangle_length_counter (
    .clk, .rst_l, .counter_clk_en, .halt(control_flag), .disable_l, 
    .load(length_load), .load_data(length_load_data), 
    .non_zero(length_non_zero));

      

endmodule: triangle_channel

