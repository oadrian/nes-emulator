`default_nettype none

module sweep #(parameter CARRY=0)(
  input logic clk, rst_l,
  input logic cpu_clk_en, half_clk_en,
  input logic enable, negate, load,
  input logic [2:0] div_period,
  input logic [2:0] shift_count,
  input logic [10:0] timer_period_in,

  output logic mute,
  output logic change_timer_period,
  output logic [10:0] timer_period_out);

  logic reload;
  logic overflow;
  logic div_pulse;
  logic [10:0] change_amount;
  logic [11:0] target_period;

  assign mute = target_period > 12'h7ff || timer_period_in < 11'h8;

  always_comb begin
    change_amount = timer_period_in >> shift_count;
    change_amount = negate ? -change_amount - CARRY : change_amount;
    target_period = timer_period_in + change_amount;
  end

  divider #(.WIDTH(3), .RES_VAL(0)) div (
    .clk, .rst_l, .clk_en(half_clk_en), .load(reload), .load_data(div_period),
    .pulse(div_pulse));

  assign timer_period_out = target_period[10:0];
  assign change_timer_period = half_clk_en && div_pulse && enable && ~mute && 
                               shift_count > 0;


  always_ff @(posedge clk, negedge rst_l)
    if (~rst_l)
      reload <= 1'b0;
    else if (cpu_clk_en & load)
      reload <= 1'b1;
    else if (half_clk_en)
      reload <= 1'b0;
        


endmodule: sweep
