module ChipInterface
  (input  logic CLOCK_50, 
   input  logic [3:0] KEY, 
   input  logic [17:0] SW, 
   output logic [6:0] HEX0, HEX1, HEX2, HEX3,  
                      HEX4, HEX5, HEX6, HEX7, 
   output logic [7:0]  VGA_R, VGA_G, VGA_B, 
   output logic        VGA_BLANK_N, VGA_CLK, VGA_SYNC_N, 
   output logic        VGA_VS, VGA_HS); 

	logic rst_n;
	assign rst_n = KEY[0];
	
	// 21.477272 MHz clock
	logic areset, clk, locked;
	pll pll_clk(.areset, .inclk0(CLOCK_50), .c0(clk), .locked);
	
	logic [7:0] counter;
	
	always_ff @(posedge clk) begin
		if(rst_n)
			counter <= 8'd0;
		else 
			counter <= counter + 8'd1;
	end
	

endmodule: ChipInterface