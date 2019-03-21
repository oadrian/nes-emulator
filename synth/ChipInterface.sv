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
	
	// ppu
	logic vblank;
	logic [2:0] R, G;
	logic [1:0] B;
	ppu ppu_device(.clk, .rst_n, .vblank, 
	               .vsync_n(VGA_VS), .hsync_n(VGA_HS), 
						.vga_r(R), .vga_g(G), .vga_b(B)); 
						
	// VGA signals
	assign VGA_SYNC_N = 1'b1;
	assign VGA_BLANK_N = 1'b1;
	assign VGA_CLK = clk;
	
	assign VGA_R = 8'd0;
	assign VGA_G = 8'd255;
	assign VGA_B = 8'd255;


endmodule: ChipInterface