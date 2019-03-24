`default_nettype none

module triangle_channel (
  input logic clk, rst_l,
  input logic halt,
  input logic [6:0] linear_cnt_load,
  input logic [10:0] timer,
  input logic [4:0] length_cnt_load,
  output logic [3:0] out);


  logic [3:0] seq_out;

  register #(.WIDTH(4'h4), .RES_VAL(4'hF)) seq_reg (
    .clk, .rst_l, .en(1'b1), .d(seq_out), .q(out));

  // Sequencer
  always_ff @(posedge length_gate_out, negedge rst_l)
    if (~rst_l)
      seq_out <= 15
      

endmodule: triangle_channel

module register #(parameter WIDTH=32, RES_VAL=0)(
  input logic clk, rst_l,
  input logic en,
  input logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, negedge rst_l)
    if (~rst_l)
      q <= RES_VAL;
    else if (en)
      q <= d;

endmodule: register
