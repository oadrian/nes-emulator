`default_nettype none

module pulse_channel #(parameter PULSE_CARRY=0) (
  input logic clk, rst_l,

  input logic cpu_clk_en, apu_clk_en,
  input logic quarter_clk_en, half_clk_en,

  input logic [15:0] addr,
  input logic [7:0] data_in,
  input logic we,

  input logic disable_l,

  output logic length_non_zero,
  output logic [3:0] out);


  logic mute;
  logic update_timer_period;
  logic [10:0] next_timer_period, timer_period;
  logic [10:0] sweep_timer_period;

  logic timer_pulse;

  logic loop_flag;
  logic [3:0] env_vol_out;

  logic [3:0][7:0] seqs;
  logic [7:0] seq;
  logic [2:0] seq_i;
  logic seq_out;

  logic [3:0] gate1_out, gate2_out;

  always_comb begin
    gate1_out = mute ? 4'b0 : env_vol_out;
    gate2_out = seq_out ? gate1_out : 4'b0;
    out = length_non_zero ? gate2_out : 4'b0;
  end
  
  always_comb begin
    seqs = {8'b1111_1001, 8'b0001_1110, 8'b0000_0110, 8'b0000_0010};
    seq = seqs[duty];
    seq_out = seq[seq_i];
  end

  logic choose_sweep;

  assign loop_flag = length_halt;

  logic next_env_load, env_load;
  logic next_sweep_load, sweep_load;
  sweep_t next_sweep_sigs, sweep_sigs;
  logic [1:0] next_duty, duty;
  logic next_length_halt, length_halt;
  logic next_const_volume, const_volume;
  logic [3:0] next_volume, volume;
  logic next_length_load, length_load;
  logic [4:0] next_length_load_data, length_load_data;

  generate
    if (PULSE_CARRY == 1) // Pulse Channel 0
      always_comb begin
        next_env_load = env_load;
        next_sweep_load = sweep_load;
        next_sweep_sigs = sweep_sigs;
        next_duty = duty;
        next_length_halt = length_halt;
        next_const_volume = const_volume;
        next_volume = volume;
        next_length_load = length_load;
        next_length_load_data = length_load_data;
        next_timer_period = timer_period;

        if (we)
          if (addr == 16'h4000) begin
            next_duty = data_in[7:6];
            next_length_halt = data_in[5];
            next_const_volume = data_in[4];
            next_volume = data_in[3:0];
            next_env_load = 1'b1;
          end else if (addr == 16'h4001) begin
            next_sweep_sigs = data_in;
            next_sweep_load = 1'b1;
          end else if (addr == 16'h4002)
            next_timer_period = {timer_period[10:8], data_in};
          else if (addr == 16'h4003) begin
            next_timer_period = {data_in[2:0], timer_period[7:0]};
            next_length_load_data = data_in[7:3];
            next_length_load = 1'b1;
          end else if (update_timer_period)
            next_timer_period = sweep_timer_period;

      end
    else // PULSE_CARRY == 0 => Pulse channel 1
      always_comb begin
        next_env_load = env_load;
        next_sweep_load = sweep_load;
        next_sweep_sigs = sweep_sigs;
        next_duty = duty;
        next_length_halt = length_halt;
        next_const_volume = const_volume;
        next_volume = volume;
        next_length_load = length_load;
        next_length_load_data = length_load_data;
        next_timer_period = timer_period;

        if (we)
          if (addr == 16'h4004) begin
            next_duty = data_in[7:6];
            next_length_halt = data_in[5];
            next_const_volume = data_in[4];
            next_volume = data_in[3:0];
            next_env_load = 1'b1;
          end else if (addr == 16'h4005) begin
            next_sweep_sigs = data_in;
            next_sweep_load = 1'b1;
          end else if (addr == 16'h4006)
            next_timer_period = {timer_period[10:8], data_in};
          else if (addr == 16'h4007) begin
            next_timer_period = {data_in[2:0], timer_period[7:0]};
            next_length_load_data = data_in[7:3];
            next_length_load = 1'b1;
          end else if (update_timer_period)
            next_timer_period = sweep_timer_period;

      end

  endgenerate

  apu_register #(.WIDTH(1), .RES_VAL(0)) env_load_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_env_load), .q(env_load));

  apu_register #(.WIDTH(1), .RES_VAL(0)) sweep_load_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_sweep_load), .q(sweep_load));

  apu_register #(.WIDTH(8), .RES_VAL(0)) sweep_sigs_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_sweep_sigs), .q(sweep_sigs));

  apu_register #(.WIDTH(2), .RES_VAL(0)) duty_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_duty), .q(duty));

  apu_register #(.WIDTH(1), .RES_VAL(0)) length_halt_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_length_halt), .q(length_halt));

  apu_register #(.WIDTH(1), .RES_VAL(0)) const_volume_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_const_volume), .q(const_volume));

  apu_register #(.WIDTH(4), .RES_VAL(0)) volume_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_volume), .q(volume));

  apu_register #(.WIDTH(11), .RES_VAL(0)) timer_period_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_timer_period), .q(timer_period));

  apu_register #(.WIDTH(1), .RES_VAL(0)) length_load_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_length_load), .q(length_load));

  apu_register #(.WIDTH(5), .RES_VAL(0)) length_data_reg (
    .clk, .rst_l, .clk_en(cpu_clk_en), .en(1'b1), 
    .d(next_length_load_data), .q(length_load_data));

  up_counter #(.WIDTH(3), .RES_VAL(0)) seq_i_counter (
    .clk, .rst_l, .clk_en(apu_clk_en), .en(timer_pulse), .load(length_load),
    .load_data(3'b0), .count(seq_i));

  divider #(.WIDTH(11), .RES_VAL(0)) timer (
    .clk, .rst_l, .clk_en(apu_clk_en), .load(1'b0), 
    .load_data(timer_period), .pulse(timer_pulse));

  sweep #(.CARRY(PULSE_CARRY)) sweep_unit (
    .clk, .rst_l, .cpu_clk_en, .half_clk_en, .enable(sweep_sigs.enable),
    .negate(sweep_sigs.negate), .load(sweep_load), 
    .div_period(sweep_sigs.period), 
    .shift_count(sweep_sigs.shift_count),
    .timer_period_in(timer_period), .mute, .change_timer_period(update_timer_period),
    .timer_period_out(sweep_timer_period));

  envelope env_unit (
    .clk, .rst_l, .cpu_clk_en, .quarter_clk_en, .load(env_load),
    .loop_flag, .const_vol(const_volume), .vol_in(volume), 
    .vol_out(env_vol_out));

  length_counter len_counter (
    .clk, .rst_l, .cpu_clk_en, .half_clk_en, .halt(length_halt), .disable_l,
    .load(length_load), .load_data(length_load_data), 
    .non_zero(length_non_zero));
    


endmodule: pulse_channel
