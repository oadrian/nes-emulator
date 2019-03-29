`default_nettype none
`include "../../hw/ppu/ppu_defines.vh"

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
	
	// 21.477272 MHz  and 10.738636 MHz clock
	logic areset, CLOCK_21, CLOCK_10, locked;
	pll_mult pll_clk(.areset, .inclk0(CLOCK_50), .c0(CLOCK_21), .c1(CLOCK_10), .locked);
	
	// VGA signals
	logic blank;
	assign VGA_SYNC_N = 1'b0;
	assign VGA_BLANK_N = ~blank;
	assign VGA_CLK = CLOCK_10;
	
	// ppu
	logic vblank;

    logic cpu_clk_en;    
    reg_t reg_sel;      
    logic reg_en, reg_rw;       
    logic [7:0] reg_data_in, reg_data_out;

    logic cpu_cyc_par, cpu_sus;

    logic [15:0] cpu_addr;
    logic cpu_re;
    logic [7:0] cpu_rd_data;

    assign cpu_rd_data = 8'hff;

    always_comb begin
        reg_sel = PPUCTRL;
        case (SW[3:0])
            4'd0: reg_sel = PPUCTRL;
            4'd1: reg_sel = PPUMASK;
            4'd2: reg_sel = PPUSTATUS;
            4'd3: reg_sel = OAMADDR;
            4'd4: reg_sel = OAMDATA;
            4'd5: reg_sel = PPUSCROLL;
            4'd6: reg_sel = PPUADDR;
            4'd7: reg_sel = PPUDATA;
            4'd8: reg_sel = OAMDMA;
            default : /* default */;
        endcase
    end

    assign reg_en = ~KEY[3];
    assign reg_rw = SW [4];
    assign reg_data_in = SW[17:10];

    // CPU clock enable
    clock_div #(12) c_ck(.clk(CLOCK_21), .rst_n, .clk_en(cpu_clk_en));

	ppu ppu_device(.clk(CLOCK_21), .rst_n, .vblank, 
	               .vsync_n(VGA_VS), .hsync_n(VGA_HS), 
				   .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B), .blank,
                   .cpu_clk_en, .reg_sel, .reg_en, .reg_rw, .reg_data_in, .reg_data_out,
                   .cpu_cyc_par, .cpu_sus, .cpu_addr, .cpu_re, .cpu_rd_data); 

	
	


endmodule: ChipInterface