`default_nettype none

module register #(parameter WIDTH=32, RES_VAL=0) (
  input logic clk, rst_l,
  input logic clk_en, en,
  input logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, negedge rst_l)
    if (~rst_l)
      q <= RES_VAL;
    else if (clk_en & en)
      q <= d;

endmodule: register

module divider #(parameter WIDTH=32, RES_VAL=0) (
  input logic clk, rst_l,
  input logic clk_en,
  input logic load,
  input logic [WIDTH-1:0] load_data,
  output logic pulse);

  logic [WIDTH-1:0] saved_data, next_count, count;
  
  assign next_count = (load | pulse) ? saved_data : count - 1'b1;
  assign pulse = !count;

  register #(.WIDTH(WIDTH), .RES_VAL(RES_VAL)) data_reg (
    .clk, .rst_l, .clk_en, .en(load), .d(load_data), .q(saved_data));
  register #(.WIDTH(WIDTH), .RES_VAL(RES_VAL)) count_reg (
    .clk, .rst_l, .clk_en, .en(1'b1), .d(next_count), .q(count));
  
endmodule: divider

module up_counter #(parameter WIDTH=32, RES_VAL=0) (
  input logic clk, rst_l,
  input logic clk_en, en,
  input logic load,
  input logic [WIDTH-1:0] load_data,
  output [WIDTH-1:0] count);

  logic [WIDTH-1:0] next_count;

  assign next_count = load ? load_data : count + 'b1;

  register #(.WIDTH(WIDTH), .RES_VAL(RES_VAL)) count_reg (
    .clk, .rst_l, .clk_en, .en(load | en), .d(next_count), .q(count));

endmodule: up_counter

module linear_counter (
  input logic clk, rst_l,
  input logic counter_clk_en,
  input logic clear_reload_l,
  input logic load,
  input logic [6:0] load_data,
  output logic non_zero);

  logic next_reload_flag, reload_flag;
  logic [6:0] next_count, count;

  assign non_zero = count > 7'b0;

  // Determine the next count
  always_comb
    if (reload_flag)
      next_count = load_data;
    else if (non_zero)
      next_count = count - 7'b1;
    else
      next_count = count;

  // Determine the next reload flag
  always_comb
    if (~clear_reload_l)
      next_reload_flag = 1'b0;
    else if (load | non_zero)
      next_reload_flag = 1'b1;
    else
      next_reload_flag = reload_flag;

  register #(.WIDTH(7), .RES_VAL(0)) count_reg (
    .clk, .rst_l, .clk_en(counter_clk_en), .en(1'b1), .d(next_count), 
    .q(count));

  register #(.WIDTH(1), .RES_VAL(0)) reload_flag__reg (
    .clk, .rst_l, .clk_en(counter_clk_en), .en(1'b1), .d(next_reload_flag), 
    .q(reload_flag));

endmodule: linear_counter

module length_counter (
  input logic clk, rst_l,
  input logic counter_clk_en,
  input logic halt,
  input logic disable_l,
  input logic load,
  input logic [4:0] load_data,
  output logic non_zero);

  logic [7:0] next_count, count;

  register #(.WIDTH(8), .RES_VAL(0)) count_reg (
    .clk, .rst_l, .clk_en(counter_clk_en), .en(1'b1), .d(next_count), .q(count));

  assign non_zero = count > 5'b0;

  always_comb
    if (~disable_l) next_count = 5'b0;
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
    else if (halt) next_count = count;
    else if (!count)
      next_count = 8'b0;
    else
      next_count = count - 1'b1;
        
        
endmodule: length_counter
