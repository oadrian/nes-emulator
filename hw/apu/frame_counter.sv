`default_nettype none

module frame_counter (
  input logic clk, rst_l,
  input logic cpu_clk_en, 
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

/*
  always_ff @(posedge clk or negedge rst_l) begin : proc_
    if(~rst_l) begin
      quarter_clk_en <= 1'b0;
      half_clk_en <= 1'b0;
      interrupt <= 1'b0;
    end else begin
      quarter_clk_en <= 1'b0;
      half_clk_en <= 1'b0;
      interrupt <= 1'b0;

      if (cpu_clk_en) begin

        if (num_cycles == 16'd7457)
            quarter_clk_en <= 1'b1;
        else if (num_cycles == 16'd14913)
          {quarter_clk_en, half_clk_en} <= 2'b11;
        else if (num_cycles == 16'd22371)
          quarter_clk_en <= 1'b1;
        else if (~mode && num_cycles == 16'd29829) begin
          {quarter_clk_en, half_clk_en} <= 2'b11;
          interrupt <= ~inhibit_interrupt;
          num_cycles <= 16'b0;          
        end else if (num_cycles == 16'd37281) begin
          {quarter_clk_en, half_clk_en} <= 2'b11;
          num_cycles <= 16'b0;
        end       
        if (load)
          num_cycles <= 16'd37281;
        else
          num_cycles <= num_cycles + 1'b1;

      end
    end
  end
*/

  always_comb begin
    quarter_clk_en = 1'b0;
    half_clk_en = 1'b0;
    interrupt = 1'b0;
    next_num_cycles = num_cycles + 1'b1;

    if (num_cycles == 16'd7457)
      quarter_clk_en = 1'b1;
    else if (num_cycles == 16'd14913)
      {quarter_clk_en, half_clk_en} = 2'b11;
    else if (num_cycles == 16'd22371)
      quarter_clk_en = 1'b1;
    else if (~mode && num_cycles == 16'd29829) begin
      {quarter_clk_en, half_clk_en} = 2'b11;
      interrupt = ~inhibit_interrupt;
      next_num_cycles = 16'b0;
    end else if (num_cycles == 16'd37281) begin
      {quarter_clk_en, half_clk_en} = 2'b11;
      next_num_cycles = 16'b0;
    end
      
    if (load)
      next_num_cycles = 16'd37281;
  end

endmodule: frame_counter
