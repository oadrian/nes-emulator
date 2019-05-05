`default_nettype none

module frame_counter (
  input logic clk, rst_l,
  input logic cpu_clk_en, apu_clk_en,

  input logic [15:0] addr,
  input logic [7:0] data_in,
  input logic we,

  input logic clear_interrupt,
  
  output logic interrupt,
  output logic quarter_clk_en, half_clk_en);

  logic [15:0] next_num_cycles, num_cycles;
  logic load;
  logic next_mode, mode;
  logic next_inhibit, inhibit_interrupt;

  assign load = (addr == 16'h4017) & we;

  apu_register #(.WIDTH(16), .RES_VAL(0)) cycles_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1),
    .d(next_num_cycles), .q(num_cycles));

  always_comb begin
    if (load)
      next_mode = data_in[7];
    else
      next_mode = mode;
  end

  apu_register #(.WIDTH(1), .RES_VAL(0)) mode_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1),
    .d(next_mode), .q(mode));

  always_comb begin
    if (load)
      next_inhibit = data_in[6];
    else
      next_inhibit = inhibit_interrupt;
  end

  apu_register #(.WIDTH(1), .RES_VAL(0)) inhibit_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1),
    .d(next_inhibit), .q(inhibit_interrupt));


  always_ff @(posedge clk, negedge rst_l)
    if (~rst_l)
      interrupt <= 1'b0;
    else if (apu_clk_en & ~mode & (num_cycles == 16'd14914))
      interrupt <= ~inhibit_interrupt;
    else if (cpu_clk_en & clear_interrupt)
      interrupt <= 1'b0;

  always_comb
    begin
      next_num_cycles = num_cycles;
      quarter_clk_en = 1'b0;
      half_clk_en = 1'b0;
      
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
