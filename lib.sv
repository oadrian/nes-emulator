`default_nettype none

module register #(parameter WIDTH=32, RES_VAL=0) (
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

module linear_down_counter #(parameter WIDTH=32, RES_VAL=0) (
  input logic clk, rst_l,
  input logic [WIDTH-1:0] load_val,
  input logic load,
  output logic pulse);

  logic [WIDTH-1:0] saved_val, cur_count, next_count;
  
  assign next_count = pulse ? saved_val : cur_count - 1'b1;
  assign pulse = !cur_count;

  register #(.WIDTH(WIDTH), .RES_VAL(RES_VAL)) load_val_reg (
    .clk, .rst_l, .en(load), .d(load_val), .q(saved_val));
  register #(.WIDTH(WIDTH), .RES_VAL(RES_VAL)) count_reg (
    .clk, .rst_l, .en(1'b1), .d(next_count), .q(cur_count));
  
endmodule: linear_down_counter

module length_counter (
  input logic clk, rst_l,
  input logic halt,
  input logic disable_l,
  input logic load,
  input logic [4:0] load_data,
  output logic non_zero);

  logic [7:0] next_count, count;

  register #(.WIDTH(8), .RES_VAL(0)) count_reg (
    .clk, .rst_l, .en(1'b1), .d(next_count), .q(count));

  assign non_zero = count > 5'b0;

  always_comb
    if (~disable_l) next_count = 5'b0;
    else if (halt) next_count = count;
    else if (load)
      case (load_data)
        5'h00: next_count = 8'd10;
        5'h01: next_count = 8'd254;
        5'h02: next_count = 8'd20;
        5'h03: next_count = 8'd2;
        5'h04: next_count = 8'd40;
        5'h05: next_count = 8'd4;
        5'h06: next_count = 8'd80;
        5'h07: next_count = 8'd6;
        5'h08: next_count = 8'd160;
        5'h09: next_count = 8'd8;
        5'h0A: next_count = 8'd60;
        5'h0B: next_count = 8'd10;
        5'h0C: next_count = 8'd14;
        5'h0D: next_count = 8'd12;
        5'h0E: next_count = 8'd26;
        5'h0F: next_count = 8'd14;
        5'h10: next_count = 8'd12;
        5'h11: next_count = 8'd16;
        5'h12: next_count = 8'd24;
        5'h13: next_count = 8'd18;
        5'h14: next_count = 8'd48;
        5'h15: next_count = 8'd20;
        5'h16: next_count = 8'd96;
        5'h17: next_count = 8'd22;
        5'h18: next_count = 8'd192;
        5'h19: next_count = 8'd24;
        5'h1A: next_count = 8'd72;
        5'h1B: next_count = 8'd26;
        5'h1C: next_count = 8'd16;
        5'h1D: next_count = 8'd28;
        5'h1E: next_count = 8'd32;
        5'h1F: next_count = 8'd30;
      endcase
    else
      next_count = count - 1'b1;
        
        
endmodule: length_counter
