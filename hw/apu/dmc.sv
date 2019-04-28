`default_nettype none

module dmc (
  input logic clk, rst_l,
  input logic cpu_clk_en,

  input logic clear_irq_l,
  input logic loop,
  input logic disable_l,

  input logic rate_index,
  input logic addr_load, length_load,
  input logic [7:0] addr_in, length_in,

  input logic [7:0] mem_data,

  output logic irq_l,
  output logic mem_re,
  output logic [14:0] addr_out,

  input logic direct_load,
  input logic [6:0] direct_load_data,

  output logic [6:0] out);

  logic [0:15][8:0] lut;
  logic [8:0] timer_period;

  logic [7:0] buffer_data_in, buffer_data_out;
  logic buffer_empty, buffer_load, buffer_read;

  logic timer_clk_en;

  assign lut = {9'd428, 9'd380, 9'd340, 9'd320,
                9'd286, 9'd254, 9'd226, 9'd214,
                9'd190, 9'd160, 9'd142, 9'd128,
                9'd106, 9'd84,  9'd72,  9'd54};
  assign timer_period = lut[rate_index];

  memory_reader mem_reader (
    .buffer_data(buffer_data_in), .*);

  sample_buffer sample_buf (
    .load(buffer_load), .read(buffer_read), .data_in(buffer_data_in),
    .empty(buffer_empty), .data_out(buffer_data_out), .*);

  divider #(.WIDTH(9), .RES_VAL(0)) timer (
    .clk_en(cpu_clk_en), .load(1'b0), .load_data(timer_period), 
    .pulse(timer_clk_en), .*);

  output_unit out_unit (
    .buffer_data(buffer_data_out), .vol_out(out), .*);

endmodule: dmc

module memory_reader (
  input logic clk, rst_l,
  input logic cpu_clk_en,

  input logic clear_irq_l,
  input logic loop,
  input logic disable_l,

  input logic addr_load, length_load,
  input logic [7:0] addr_in, length_in,

  input logic [7:0] mem_data,
  input logic buffer_empty,

  output logic irq_l,
  output logic [15:0] addr_out,
  output logic buffer_load,
  output logic [7:0] buffer_data);

  logic [15:0] next_addr_out;
  logic [11:0] next_bytes_remaining, bytes_remaining;

  logic next_irq_l;

  logic [15:0] sample_address;
  logic [11:0] sample_length;

  assign sample_address = {2'b11, addr_in, 6'b0};
  assign sample_length = {length_in, 4'b1};

  assign buffer_data = mem_data;
  assign buffer_load = buffer_empty;

  always_comb
    if (addr_load)
      next_addr_out = sample_address;
    else if (!bytes_remaining & loop)
      next_addr_out = sample_address;
    else if (!bytes_remaining & ~loop)
      next_addr_out = addr_out;
    else if (addr_out == 16'hFFFF)
      next_addr_out = 16'h8000;
    else
      next_addr_out = addr_out + 16'b1;

  always_comb begin
    next_irq_l = irq_l;
    if (clear_irq_l)
      next_irq_l = 1'b1;
    if (disable_l)
      next_bytes_remaining = 12'b0;
    else if (length_load)
      next_bytes_remaining = sample_length;
    else if (!bytes_remaining & loop) 
      next_bytes_remaining = sample_length;
    else if (!bytes_remaining & ~loop) begin
      next_bytes_remaining = bytes_remaining;
      next_irq_l = 1'b0;
    end else 
      next_bytes_remaining = bytes_remaining - 1'b1;
  end
  
  apu_register #(.WIDTH(1), .RES_VAL(1)) irq_l_reg(
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1),
    .d(next_irq_l), .q(irq_l));

  apu_register #(.WIDTH(16), .RES_VAL(0)) addr_out_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1),
    .d(next_addr_out), .q(addr_out));

  apu_register #(.WIDTH(12), .RES_VAL(0)) bytes_remaining_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1),
    .d(next_bytes_remaining), .q(bytes_remaining));

endmodule: memory_reader

module sample_buffer (
  input logic clk, rst_l,
  input logic cpu_clk_en,
  input logic load, read,
  input logic [7:0] data_in,

  output logic empty,
  output logic [7:0] data_out);

  logic next_empty;

  always_comb
    if (load & empty)
      next_empty = 1'b0;
    else if (read & ~empty)
      next_empty = 1'b1;
    else
      next_empty = empty;

  apu_register #(.WIDTH(1), .RES_VAL(0)) empty_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(load),
    .d(next_empty), .q(empty));

  apu_register #(.WIDTH(8), .RES_VAL(0)) data_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(load),
    .d(data_in), .q(data_out));

endmodule: sample_buffer

module output_unit (
  input logic clk, rst_l,
  input logic cpu_clk_en, timer_clk_en,
  input logic buffer_empty,
  input logic direct_load,
  input logic [6:0] direct_load_data,
  input logic [7:0] buffer_data,

  output logic buffer_read,
  output logic [6:0] vol_out);

  logic new_cycle;
  logic next_silence, silence;
  logic [7:0] next_shift_data, shift_data;
  logic [6:0] next_vol_out;

  always_comb begin
    next_vol_out = vol_out;
    if (~silence) begin
      if (shift_data[0] & (vol_out <= 7'd125))
        next_vol_out = vol_out + 7'd2;
      if (~shift_data[0] & (vol_out >= 7'd2))
        next_vol_out = vol_out - 7'd2;
    end

    if (direct_load)
      next_vol_out = direct_load_data;
  end
  
  assign next_silence = buffer_empty;

  always_comb begin
    next_shift_data = shift_data;
    buffer_read = 1'b0;
    if (new_cycle & ~buffer_empty) begin
      next_shift_data = buffer_data;
      buffer_read = 1'b1;
    end else if (timer_clk_en)
      next_shift_data = shift_data >> 1'b1;
  end

  apu_register #(.WIDTH(1), .RES_VAL(0)) silence_reg (
    .clk, .rst_l, .clk_en(timer_clk_en), .en(new_cycle),
    .d(next_silence), .q(silence));

  apu_register #(.WIDTH(8), .RES_VAL(0)) shift_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1),
    .d(next_shift_data), .q(shift_data));

  divider #(.WIDTH(4), .RES_VAL(0)) bits_remaining_counter (
    .clk, .rst_l, .clk_en(timer_clk_en), .load(1'b0),
    .load_data(4'd8), .pulse(new_cycle));
   
  apu_register #(.WIDTH(7), .RES_VAL(0)) vol_out_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1),
    .d(next_vol_out), .q(vol_out));

endmodule: output_unit
