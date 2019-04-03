`default_nettype none

module frame_counter (
  input logic clk, rst_l,
  input logic cpu_clk_en, 
  input logic mode,
  input logic load,
  input logic inhibit_interrupt,
  
  output logic interrupt,
  output logic quarter_clk_en, half_clk_en);

  logic reload;
  logic [15:0] num_cycles;

  up_counter #(.WIDTH(16), .RES_VAL(0)) cycle_counter (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), .load(reload),
    .load_data(16'b0), .count(num_cycles));


  always_comb begin
    quarter_clk_en = 1'b0;
    half_clk_en = 1'b0;
    interrupt = 1'b0;
    reload = 1'b0;

    if (num_cycles == 16'd7457)
      quarter_clk_en = 1'b1;
    else if (num_cycles == 16'd14913)
      {quarter_clk_en, half_clk_en} = 2'b11;
    else if (num_cycles == 16'd22371)
      quarter_clk_en = 1'b1;
    else if (~mode && num_cycles == 16'd29829) begin
      {quarter_clk_en, half_clk_en} = 2'b11;
      interrupt = ~inhibit_interrupt;
      reload = 1'b1;
    end else if (mode && num_cycles == 16'd37281) begin
      {quarter_clk_en, half_clk_en} = 2'b11;
      reload = 1'b1;
    end

    reload = load ? 1'b1 : reload;
      
    if (load & mode)
      {quarter_clk_en, half_clk_en} = 2'b11;
  end

endmodule: frame_counter
