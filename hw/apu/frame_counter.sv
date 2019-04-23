`default_nettype none

module frame_counter (
  input logic clk, rst_l,
  input logic cpu_clk_en, apu_clk_en,
  input logic mode,
  input logic load,
  input logic inhibit_interrupt,
  
  output logic interrupt,
  output logic quarter_clk_en, half_clk_en);

  logic [15:0] next_num_cycles, num_cycles;
//TODO: The interrupt should be turned off sometimes

  apu_register #(.WIDTH(16), .RES_VAL(0)) cycles_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1),
    .d(next_num_cycles), .q(num_cycles));


always_comb
  begin
    next_num_cycles = num_cycles;
    quarter_clk_en = 1'b0;
    half_clk_en = 1'b0;
    interrupt = 1'b0;
    
    if (apu_clk_en) begin
      next_num_cycles = num_cycles + 16'b1;

      if (num_cycles == 16'd3728)
        quarter_clk_en = 1'b1;
      else if (num_cycles == 16'd7456)
        {quarter_clk_en, half_clk_en} = 2'b11;
      else if (num_cycles == 16'd11185)
          quarter_clk_en = 1'b1;
      else if (~mode & (num_cycles == 16'd14914)) begin
          {quarter_clk_en, half_clk_en} = 2'b11;
          interrupt = ~inhibit_interrupt;

          next_num_cycles = 16'b0;
      end else if (num_cycles == 16'd18640) begin
          {quarter_clk_en, half_clk_en} = mode ? 2'b11 : 2'b00;

          next_num_cycles = 16'b0;
      end
    end

    if (cpu_clk_en & load)
      next_num_cycles = 16'd18640;
  end

endmodule: frame_counter
