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
	logic areset, CLOCK_21, CLOCK_10, locked;
	pll_mult pll_clk(.areset, .inclk0(CLOCK_50), .c0(CLOCK_21), .c1(CLOCK_10), .locked);
	
	// ppu
//	logic vblank;
//	logic [2:0] R, G;
//	logic [1:0] B;
//	ppu ppu_device(.clk, .rst_n, .vblank, 
//	               .vsync_n(VGA_VS), .hsync_n(VGA_HS), 
//						.vga_r(R), .vga_g(G), .vga_b(B)); 
						
	// VGA signals
	logic blank;
	assign VGA_SYNC_N = 1'b0;
	assign VGA_BLANK_N = ~blank;
	assign VGA_CLK = ~CLOCK_10;
	
	assign VGA_R = 8'h0;
	assign VGA_G = 8'hff;
	assign VGA_B = 8'h0;
	
	logic [2:0] vga_r, vga_g;
	logic [1:0] vga_b;
	logic [7:0] vga_buf_idx;
	logic [5:0] vga_buf_out;
	logic vsync_n, hsync_n;
	
	assign VGA_VS = vsync_n;
	assign VGA_HS = hsync_n;
	
	vga v(.clk(CLOCK_10), .clk_en(1'b1), .rst_n, .vsync_n, .hsync_n, .vga_r, .vga_g, .vga_b, .blank, .vga_buf_idx, .vga_buf_out);


endmodule: ChipInterface