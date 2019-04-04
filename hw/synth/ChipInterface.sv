`default_nettype none
`include "../include/ucode_ctrl.vh"
`include "../include/cpu_types.vh"
`include "../include/ppu_defines.vh"

module ChipInterface
  (input  logic CLOCK_50, 
   input  logic [3:0] KEY, 
   input  logic [17:0] SW, 
   output logic [6:0] HEX0, HEX1, HEX2, HEX3,  
                      HEX4, HEX5, HEX6, HEX7, 
   output logic [7:0]  VGA_R, VGA_G, VGA_B, 
   output logic        VGA_BLANK_N, VGA_CLK, VGA_SYNC_N, 
   output logic        VGA_VS, VGA_HS); 

	logic reset_n;
	assign reset_n = KEY[0];
	
	// 21.477272 MHz  and 10.738636 MHz clock
	logic areset, CLOCK_21, CLOCK_10, locked;
  assign areset = ~reset_n;
	pll_mult pll_clk(.areset, .inclk0(CLOCK_50), .c0(CLOCK_21), .c1(CLOCK_10), .locked);
	
	// VGA signals
	logic blank;
	assign VGA_SYNC_N = 1'b0;
	assign VGA_BLANK_N = ~blank;
	assign VGA_CLK = CLOCK_10;

  logic clock;

  assign clock = CLOCK_21;
	
	// ppu
      logic ppu_clk_en;  // Master / 4
    clock_div #(4) ppu_clk(.clk(clock), .rst_n(reset_n), .clk_en(ppu_clk_en));

    logic cpu_clk_en;  // Master / 12
    clock_div #(12) cpu_clk(.clk(clock), .rst_n(reset_n), .clk_en(cpu_clk_en));

    // ppu cycle
    logic [63:0] ppu_cycle;
    always_ff @(posedge clock or negedge reset_n) begin
        if(~reset_n) begin
            ppu_cycle <= 64'd0;
        end else if(ppu_clk_en) begin
            ppu_cycle <= ppu_cycle + 64'd1;
        end
    end

    // cpu cycle
    logic [63:0] cpu_cycle;
    always_ff @(posedge clock or negedge reset_n) begin
        if(~reset_n) begin
            cpu_cycle <= 64'd0;
        end else if(cpu_clk_en) begin
            cpu_cycle <= cpu_cycle + 64'd1;
        end
    end

    // PPU stuff
    logic vblank_nmi;
    reg_t reg_sel;                  // register to write to
    logic reg_en;                   // 1 - write to register; 0 - do nothing
    logic reg_rw;                   // 1 - write mode; 0 - read mode
    logic [7:0] reg_data_wr;        // data to write
    logic [7:0] reg_data_rd;       // data read
    logic cpu_cyc_par;              // used for exact DMA timing
    logic cpu_sus;                  // suspend CPU when performing OAMDMA
    logic [15:0] mem_addr_p;
    logic mem_re_p;
    logic [7:0] mem_rd_data_p;

    assign cpu_cyc_par = cpu_cycle[0];

    ppu peep(.clk(clock), .rst_n(reset_n), .ppu_clk_en, .vblank_nmi, 
            .vsync_n(VGA_VS), .hsync_n(VGA_HS), 
            .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B), .blank, 
            .cpu_clk_en, .reg_sel, .reg_en, .reg_rw, .reg_data_in(reg_data_wr), .reg_data_out(reg_data_rd),
            .cpu_cyc_par, .cpu_sus, 
            .cpu_addr(mem_addr_p), .cpu_re(mem_re_p), .cpu_rd_data(mem_rd_data_p));

    // CPU stuff
    logic [15:0] mem_addr_c;
    logic mem_re_c;
    logic [7:0] mem_wr_data_c;
    logic [7:0] mem_rd_data_c;

    core cpu(.addr(mem_addr_c), .mem_r_en(mem_re_c), .w_data(mem_wr_data_c),
             .r_data(mem_rd_data_c), .clock_en(cpu_clk_en && !cpu_sus), .clock, .reset_n,
             .nmi(vblank_nmi));

    // CPU Memory Interface
    logic [15:0] mem_addr;
    logic mem_re;
    logic [7:0] mem_wr_data, mem_rd_data;

    assign mem_addr = (cpu_sus) ? mem_addr_p : mem_addr_c;
    assign mem_re = (cpu_sus) ? mem_re_p : mem_re_c;

    assign mem_wr_data = mem_wr_data_c;

    assign mem_rd_data_c = mem_rd_data;
    assign mem_rd_data_p = mem_rd_data;

    cpu_memory mem(.addr(mem_addr), .r_en(mem_re), .w_data(mem_wr_data), 
                   .clock, .clock_en(cpu_clk_en), .reset_n, .r_data(mem_rd_data), 
                   .reg_sel, .reg_en, .reg_rw, .reg_data_wr, .reg_data_rd);


endmodule: ChipInterface