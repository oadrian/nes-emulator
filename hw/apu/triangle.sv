`default_nettype none

module triangle_channel (
  input logic clk, rst_l,
  input logic cpu_clk_en, quarter_clk_en, half_clk_en,
  input logic disable_l,
  input logic length_halt,
  input logic linear_load, length_load,
  input logic [6:0] linear_load_data,
  input logic [10:0] timer_load_data,
  input logic [4:0] length_load_data,

  output logic length_non_zero,
  output logic [3:0] out);


  logic timer_pulse;
  logic linear_non_zero;
  logic gate1_out, gate2_out;
  logic [31:0][3:0] seq;
  logic [4:0] next_seq_i, seq_i;

  assign seq = 128'hFEDCBA98765432100123456789ABCDEF;
  assign next_seq_i = seq_i + 5'b1;
  assign out = seq[seq_i];

  assign gate1_out = linear_non_zero ? timer_pulse : 1'b0;
  assign gate2_out = length_non_zero ? gate1_out : 1'b0;

  apu_register #(.WIDTH(5), .RES_VAL(0)) seq_i_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(gate2_out), .d(next_seq_i), 
    .q(seq_i));
  
  divider #(.WIDTH(11), .RES_VAL(0)) triangle_timer (
    .clk, .rst_l, .clk_en(cpu_clk_en), .load(1'b0), 
    .load_data(timer_load_data), .pulse(timer_pulse));
  
  linear_counter triangle_linear_counter (
    .clk, .rst_l, .cpu_clk_en, .quarter_clk_en, .clear_reload_l(length_halt),
    .load(linear_load), .load_data(linear_load_data), 
    .non_zero(linear_non_zero));

  length_counter triangle_length_counter (
    .clk, .rst_l, .cpu_clk_en, .half_clk_en, .halt(length_halt), .disable_l,
    .load(length_load), .load_data(length_load_data), 
    .non_zero(length_non_zero));

      

endmodule: triangle_channel

