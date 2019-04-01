`default_nettype none

module triangle_channel (
  input logic clk, rst_l,
  input logic halt,
  input logic load,
  input logic [6:0] linear_cnt_load,
  input logic [10:0] period,
  input logic [4:0] length_cnt_load,
  output logic [3:0] out);


  logic [3:0] seq_out;
  logic timer_pulse;
  logic [31:0][3:0] seq;
  logic [4:0] seq_i;

  assign seq = 128'hFEDCBA98765432100123456789ABCDEF;
  assign out = seq[seq_i];
  


  linear_down_counter #(.WIDTH(11), .RES_VAL(0)) timer (
    .clk, .rst_l, .load_val(period), .load, .pulse(timer_pulse));      

endmodule: triangle_channel

