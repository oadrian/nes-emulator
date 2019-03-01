`default_nettype none

module clock_div 
  #(parameter DIV=2)
  (input logic clk,   // Clock
  input logic rst_n,  // Asynchronous reset active low

  output logic clk_en
);

  logic [$clog2(DIV) : 0] counter;

  assign clk_en = (counter == 1'b0);

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      counter <= DIV - 1;
    end else if(counter == 1'b0) begin
      counter <= DIV - 1; 
    end else begin
      counter <= counter - 1;
    end
  end

endmodule

module MagComp
  #(parameter WIDTH = 8)
  (input logic [WIDTH-1:0] A, B,
   output logic AltB, AeqB, AgtB);
  
  always_comb begin
    AltB = (A < B);
    AeqB = (A == B);
    AgtB = (A > B);
  end

endmodule: MagComp

module Adder
  #(parameter WIDTH = 8)
  (input logic [WIDTH - 1:0] A, B,
   input logic Cin,
   output logic [WIDTH-1:0] S,
   output logic Cout);
 
  assign {Cout, S} = A + B + Cin;

endmodule: Adder

module multiplexer
  #(parameter WIDTH = 8)
  (input logic [WIDTH-1:0] in,
   input logic [$clog2(WIDTH)-1:0] sel,
   output logic out);

  always_comb begin
    out = 1'b0;
    if(sel <= WIDTH-1)
      out = in[sel];
  end

endmodule: multiplexer

module mux2to1
  #(parameter WIDTH = 8)
  (input logic [WIDTH-1:0] in0, in1,
   input logic sel,
   output logic [WIDTH-1:0] out);

  assign out = (sel) ? in1 : in0;

endmodule: mux2to1

module decoder
  #(parameter WIDTH = 8)
  (input logic [$clog2(WIDTH)-1:0] i,
   input logic en,
   output logic [WIDTH-1:0] d);

  always_comb begin
    d = 0;
    if(i <= WIDTH -1)
      d[i] = en;
  end

endmodule: decoder

module register
  #(parameter WIDTH = 6, DEFAULT = 0)
  (input logic [WIDTH-1:0] D,
   input logic clock, reset_n, en, clear,
   output logic [WIDTH-1:0] Q);

  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
        Q <= DEFAULT;
    end
    else if(en) begin 
        if(clear)
            Q<= DEFAULT;
        else
            Q<=D;
    end
  end

endmodule: register

module counter
  #(parameter WIDTH = 8, DEFAULT = 0)
  (input logic [WIDTH-1:0] D,
   input logic en, clr, load, clk, up, reset_n,
   output logic [WIDTH-1:0] Q);

 always_ff @(posedge clk, negedge reset_n) begin
   if(~reset_n)
    Q <= 0;
   else if(en) begin
     if(clr)
       Q <= 0;
     else if(load)
       Q <= D;
     else if(up)
       Q <= Q + 1;
     else if(~up)
       Q <= Q - 1;
   end
 end


endmodule: counter


module shift_register
  #(parameter WIDTH = 8, DEFAULT = 0)
  (input logic [WIDTH-1:0] D, 
   input logic clock, reset_n, en, load, clear, s_in, left,
   output logic [WIDTH-1:0] Q);

  always_ff @(posedge clock, negedge reset_n) begin
    if(~reset_n) begin
        Q <= DEFAULT;
    end
   else if(en) begin
    if(load)
      Q <= D;
    else if(clear)
      Q <= DEFAULT;
    else if(left)
      Q <= {Q[WIDTH-2:0], s_in};
    else
      Q <= {s_in, Q[WIDTH-1:1]};
   end
  end

endmodule: shift_register





module BCDtoSevenSegment
  (input logic [3:0] bcd,
   output logic [6:0] segment);
  
  always_comb begin
    unique case(bcd)
      4'b0000: segment = 7'b1000000;
     4'b0001: segment = 7'b1111001;
     4'b0010: segment = 7'b0100100;
     4'b0011: segment = 7'b0110000;
     4'b0100: segment = 7'b0011001;
     4'b0101: segment = 7'b0010010;
     4'b0110: segment = 7'b0000010;
     4'b0111: segment = 7'b1111000;
     4'b1000: segment = 7'b0000000;
     4'b1001: segment = 7'b0010000;
     4'b1010: segment = 7'b0001000;
     4'b1011: segment = 7'b0000011;
     4'b1100: segment = 7'b1000110;
     4'b1101: segment = 7'b0100001;
     4'b1110: segment = 7'b0000110;
     4'b1111: segment = 7'b0001110;
    endcase
  end

//   logic a,b,c,d;
//
//   assign a = bcd[3];
//   assign b = bcd[2];
//   assign c = bcd[1];
//   assign d = bcd[0];
//
//   assign segment[0] = (~a & ~b & ~c & d) | (~a & ~c & b & ~d);
//   assign segment[1] = (~a & b & ~c & d) | (~a & b & c & ~d);
//   assign segment[2] = (~a & ~b & c & ~d);
//   assign segment[3] = (~a & ~b & ~c & d) | (~a & b & ~c & ~d) | (~a & b & c & d);
//   assign segment[4] = (~a & ~b & ~c & d) | (~a & ~b & c & d) | (~a & b & ~c) | (~a & b & c & d) | (a & ~c & ~b & d);
//   assign segment[5] = (~a & ~b & c) | (~a & ~b & ~c & d) | (~a & b & c & d);
//   assign segment[6] = (~a & ~b & ~c) | (~a & b & c & d);

endmodule: BCDtoSevenSegment

module SevenSegmentDigit
  (input logic [3:0] bcd,
   output logic [6:0] segment,
   input logic    blank);

   logic [6:0] decoded;

   BCDtoSevenSegment b2ss(bcd, decoded);

   always_comb begin
     if(blank) segment = 7'b1111111;
     else segment = decoded;
   end

endmodule: SevenSegmentDigit

module SevenSegmentControl
  (output logic [6:0] HEX7, HEX6, HEX5, HEX4,
   output logic [6:0] HEX3, HEX2, HEX1, HEX0,
   input  logic [3:0] BCD7, BCD6, BCD5, BCD4,
   input  logic [3:0] BCD3, BCD2, BCD1, BCD0,
   input  logic [7:0] turn_on);


   SevenSegmentDigit ss0(BCD0, HEX0, turn_on[7]);
   SevenSegmentDigit ss1(BCD1, HEX1, turn_on[6]);
   SevenSegmentDigit ss2(BCD2, HEX2, turn_on[5]);
   SevenSegmentDigit ss3(BCD3, HEX3, turn_on[4]);
   SevenSegmentDigit ss4(BCD4, HEX4, turn_on[3]);
   SevenSegmentDigit ss5(BCD5, HEX5, turn_on[2]);
   SevenSegmentDigit ss6(BCD6, HEX6, turn_on[1]);
   SevenSegmentDigit ss7(BCD7, HEX7, turn_on[0]);

endmodule: SevenSegmentControl

module FourSegmentControl
  (output logic [6:0] HEX3, HEX2, HEX1, HEX0,
   input  logic [3:0] BCD3, BCD2, BCD1, BCD0,
   input  logic [3:0] turn_on);
  
  SevenSegmentDigit ss0(BCD0, HEX0, turn_on[0]);
   SevenSegmentDigit ss1(BCD1, HEX1, turn_on[1]);
   SevenSegmentDigit ss2(BCD2, HEX2, turn_on[2]);
   SevenSegmentDigit ss3(BCD3, HEX3, turn_on[3]);

endmodule: FourSegmentControl