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
  
  assign next_count = (load | pulse) ? load_data : count - 1'b1;
  assign pulse = !count;

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
  input logic cpu_clk_en, quarter_clk_en,
  input logic clear_reload_l,
  input logic load,
  input logic [6:0] load_data,
  output logic non_zero);

  logic [6:0] count;
  logic reload;

  assign non_zero = count > 7'b0;

  always_ff @(posedge clk, negedge rst_l)
    if (~rst_l) begin
      count <= 7'b0;
      reload <= 1'b0;
    end else if (cpu_clk_en) begin
      if (load)
        reload <= 1'b1;

      if (quarter_clk_en) begin
        if (reload)
          count <= load_data;
        else if (non_zero)
          count <= count - 7'b1;

        if (~clear_reload_l)
          reload <= 1'b0;
      end
    end
endmodule: linear_counter

module length_counter (
  input logic clk, rst_l,
  input logic cpu_clk_en, half_clk_en,
  input logic halt,
  input logic disable_l,
  input logic load,
  input logic [4:0] load_data,
  output logic non_zero);


  logic [7:0] count;
  logic reload;

  assign non_zero = count > 8'b0;

  always_ff @(posedge clk, negedge rst_l)
    if (~rst_l) begin
      count <= 8'b0;
      reload <= 1'b0;
    end else if (cpu_clk_en) begin
      if (load)
        reload <= 1'b1;

      if (half_clk_en)
        if (~disable_l) 
          count <= 8'b0;
        else if (reload) begin
          reload <= 1'b0;
          case (load_data)
            5'h00: count <= 8'd10;
            5'h01: count <= 8'd254;
            5'h02: count <= 8'd20;
            5'h03: count <= 8'd2;
            5'h04: count <= 8'd40;
            5'h05: count <= 8'd4;
            5'h06: count <= 8'd80;
            5'h07: count <= 8'd6;
            5'h08: count <= 8'd160;
            5'h09: count <= 8'd8;
            5'h0A: count <= 8'd60;
            5'h0B: count <= 8'd10;
            5'h0C: count <= 8'd14;
            5'h0D: count <= 8'd12;
            5'h0E: count <= 8'd26;
            5'h0F: count <= 8'd14;
            5'h10: count <= 8'd12;
            5'h11: count <= 8'd16;
            5'h12: count <= 8'd24;
            5'h13: count <= 8'd18;
            5'h14: count <= 8'd48;
            5'h15: count <= 8'd20;
            5'h16: count <= 8'd96;
            5'h17: count <= 8'd22;
            5'h18: count <= 8'd192;
            5'h19: count <= 8'd24;
            5'h1A: count <= 8'd72;
            5'h1B: count <= 8'd26;
            5'h1C: count <= 8'd16;
            5'h1D: count <= 8'd28;
            5'h1E: count <= 8'd32;
            5'h1F: count <= 8'd30;
          endcase
        end else if (~halt & non_zero)
          count <= count - 8'b1;
    end

endmodule: length_counter


