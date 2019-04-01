`default_nettype none

module triangle_channel (
  input logic cpu_clk, counter_clk,
  input logic rst_l,
  input logic disable_l,
  input logic halt,
  input logic linear_load, timer_load, length_load,
  input logic [6:0] linear_load_data,
  input logic [10:0] timer_load_data,
  input logic [4:0] length_load_data,

  output logic linear_non_zero, length_non_zero,
  output logic [3:0] wave);


  logic [3:0] seq_out;
  logic timer_pulse;
  logic [31:0][3:0] seq;
  logic [4:0] seq_i;

  assign seq = 128'hFEDCBA98765432100123456789ABCDEF;
  assign wave = seq[seq_i];
  
  linear_down_counter #(.WIDTH(11), .RES_VAL(0)) timer (
    .clk, .rst_l, .load(timer_load), .load_data(timer_load_data),
    .pulse(timer_pulse));
  
  linear_down_counter #(.WIDTH(11), .RES_VAL(0)) linear_counter (
    .clk, .rst_l, .load(linear_load), .load_data(linear_load_data), 
    .pulse(linear_non_zero));

  length_counter #(.WIDTH(11), .RES_VAL(0)) length_counter (
    .clk, .rst_l, .load(length_load), .load_data(length_load_data), 
    .pulse(linear_non_zero));

      

endmodule: triangle_channel

