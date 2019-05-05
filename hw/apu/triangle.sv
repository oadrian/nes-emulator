`default_nettype none

module triangle_channel (
  input logic clk, rst_l,
  input logic cpu_clk_en, quarter_clk_en, half_clk_en,

  input logic [15:0] addr,
  input logic [7:0] data_in,
  input logic we,

  input logic disable_l,

  output logic length_non_zero,
  output logic [3:0] out);

  logic next_linear_load, linear_load;
  logic next_length_load, length_load;
  logic next_length_halt, length_halt;
  logic [6:0] next_linear_load_data, linear_load_data;
  logic [4:0] next_length_load_data, length_load_data;
  logic [10:0] next_timer_period, timer_period;

  always_comb begin
    next_length_halt = length_halt;
    next_linear_load_data = linear_load_data;
    next_length_load_data = length_load_data;
    next_timer_period = timer_period;
    next_linear_load = 1'b0;
    next_length_load = 1'b0;
    if (we)
      if (addr == 16'h4008) begin
        next_length_halt = data_in[7];
        next_linear_load_data = data_in[6:0];
      end else if (addr == 16'h400A)
        next_timer_period = {timer_period[10:8], data_in};
      else if (addr == 16'h400B) begin
        next_timer_period = {data_in[2:0], timer_period[7:0]};
        next_length_load_data = data_in[7:3];
        next_length_load = 1'b1;
        next_linear_load = 1'b1;
      end
  end


  apu_register #(.WIDTH(1), .RES_VAL(0)) halt_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_length_halt), .q(length_halt));

  apu_register #(.WIDTH(1), .RES_VAL(0)) linear_load_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_linear_load), .q(linear_load));

  apu_register #(.WIDTH(1), .RES_VAL(0)) length_load_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_length_load), .q(length_load));

  apu_register #(.WIDTH(7), .RES_VAL(0)) linear_data_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_linear_load_data), .q(linear_load_data));

  apu_register #(.WIDTH(5), .RES_VAL(0)) length_data_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_length_load_data), .q(length_load_data));

  apu_register #(.WIDTH(11), .RES_VAL(0)) timer_data_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_timer_period), .q(timer_period));

  logic timer_pulse;
  logic linear_non_zero;
  logic gate1_out, gate2_out;
  logic [31:0][3:0] seq;
  logic [4:0] next_seq_i, seq_i;

  assign seq = 128'hFEDCBA98765432100123456789ABCDEF;
  assign next_seq_i = seq_i + 5'b1;
  assign out = seq[seq_i];

  assign gate1_out = linear_non_zero ? timer_pulse : 1'b0;
  assign gate2_out = length_non_zero ? gate1_out : 1'b0;

  apu_register #(.WIDTH(5), .RES_VAL(0)) seq_i_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(gate2_out), .d(next_seq_i), 
    .q(seq_i));
  
  divider #(.WIDTH(11), .RES_VAL(0)) triangle_timer (
    .clk, .rst_l, .clk_en(cpu_clk_en), .load(1'b0), 
    .load_data(timer_period), .pulse(timer_pulse));
  
  linear_counter triangle_linear_counter (
    .clk, .rst_l, .cpu_clk_en, .quarter_clk_en, .clear_reload_l(length_halt),
    .load(linear_load), .load_data(linear_load_data), 
    .non_zero(linear_non_zero));

  length_counter triangle_length_counter (
    .clk, .rst_l, .cpu_clk_en, .half_clk_en, .halt(length_halt), .disable_l,
    .load(length_load), .load_data(length_load_data), 
    .non_zero(length_non_zero));

      

endmodule: triangle_channel

