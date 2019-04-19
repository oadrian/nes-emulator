`default_nettype none

module envelope (
  input logic clk, rst_l,
  input logic cpu_clk_en, quarter_clk_en,
  input logic load,
  input logic loop_flag,
  input logic const_vol,
  input logic [3:0] vol_in,
  
  output logic [3:0] vol_out);
  
  logic start_flag;
  logic div_reload, div_clk_en;

  logic [3:0] decay_vol;


  assign vol_out = const_vol ? vol_in : decay_vol; 

  divider #(.WIDTH(4), .RES_VAL(0)) div (
    .clk, .rst_l, .clk_en(quarter_clk_en), .load(start_flag), 
    .load_data(vol_in), .pulse(div_clk_en));

  always_ff @(posedge clk, negedge rst_l) begin : decay_counter
    if (~rst_l)
      decay_vol <= 4'b0;
    else if (quarter_clk_en)
      if (start_flag)
        decay_vol <= 4'd15;
      else if (div_clk_en)
        if (decay_vol > 0)
          decay_vol <= decay_vol - 4'b1;
        else if (loop_flag)
          decay_vol <= 4'd15;
  end

  always_ff @(posedge clk, negedge rst_l)
    if (~rst_l) begin
      start_flag <= 1'b0;
    end else begin
      if (cpu_clk_en & load)
        start_flag <= 1'b1;

      if (quarter_clk_en)
        start_flag <= 1'b0;
    end

endmodule: envelope
