`default_nettype none
`include "../include/ucode_ctrl.vh"
`include "../include/cpu_types.vh"
`include "../include/ppu_defines.vh"
`include "../apu/apu_defines.vh"

module ChipInterface
  (input  logic CLOCK_50, 
   input  logic [3:0] KEY, 
   input  logic [17:0] SW, 
   // HEX displays
   output logic [6:0] HEX0, HEX1, HEX2, HEX3,  
                      HEX4, HEX5, HEX6, HEX7, 
   // VGA
   output logic [7:0]  VGA_R, VGA_G, VGA_B, 
   output logic        VGA_BLANK_N, VGA_CLK, VGA_SYNC_N, 
   output logic        VGA_VS, VGA_HS,

   // AUDIO DAC
  input  AUD_ADCDAT,
  inout  AUD_ADCLRCK,
  inout  AUD_BCLK,
  output AUD_DACDAT,
  inout  AUD_DACLRCK,
  output AUD_XCK,

  output I2C_SCLK,
  inout I2C_SDAT,
   // GPIO PINS
   inout logic [35:0] GPIO,

  //////////// SRAM //////////
  output [19:0] SRAM_ADDR,
  output SRAM_CE_N,
  inout  [15:0] SRAM_DQ,
  output SRAM_LB_N,
  output SRAM_OE_N,
  output SRAM_UB_N,
  output SRAM_WE_N
   ); 

	logic reset_n;
  logic rst_n;
  assign reset_n = SW[17];
  assign rst_n = reset_n;
	
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

  /// SRAM LOADER /////

  logic [4:0] game_select;
  logic start_load, done_load;
  logic no_load;

  // PRG RAM SRAM WRITE
  logic [14:0] prg_rom_addr_sram;
  logic prg_rom_we_sram;
  logic [7:0] prg_rom_wr_data_sram;
  // CHR RAM SRAM WRITE
  logic [12:0] chr_rom_addr_sram;
  logic chr_rom_we_sram;
  logic [7:0] chr_rom_wr_data_sram;
  // HEADER RAM
  logic [4:0] header_addr_sram;
  logic header_we_sram;
  logic [7:0] header_wr_data_sram;
  
  assign no_load = SW[15];
  assign game_select = SW[4:0];
  assign start_load = ~KEY[0] && ~no_load;

  sram_loader sram_ld(
    .clk(clock), .rst_n(reset_n), 
    .game_select(game_select), .start_load(start_load), .done_load(done_load),
    
    .SRAM_DQ(SRAM_DQ), .SRAM_ADDR(SRAM_ADDR), .SRAM_LB_N(SRAM_LB_N), 
    .SRAM_UB_N(SRAM_UB_N), .SRAM_CE_N(SRAM_CE_N), .SRAM_OE_N(SRAM_OE_N), 
    .SRAM_WE_N(SRAM_WE_N),
    
    .prg_rom_addr(prg_rom_addr_sram), .prg_rom_we(prg_rom_we_sram),
    .prg_rom_wr_data(prg_rom_wr_data_sram),

    .chr_rom_addr(chr_rom_addr_sram), .chr_rom_we(chr_rom_we_sram),
    .chr_rom_wr_data(chr_rom_wr_data_sram),

    .header_addr(header_addr_sram), .header_we(header_we_sram),
    .header_wr_data(header_wr_data_sram)
    );
	
	// ppu
      logic ppu_clk_en_t, ppu_clk_en;  // Master / 4
    clock_div #(4) ppu_clk(.clk(clock), .rst_n(reset_n), .clk_en(ppu_clk_en_t));

    logic cpu_clk_en_t, cpu_clk_en;  // Master / 12
    clock_div #(12) cpu_clk(.clk(clock), .rst_n(reset_n), .clk_en(cpu_clk_en_t));

    logic apu_clk_en_t, apu_clk_en;
    clock_div #(24) apu_clk(.clk(clock), .rst_n(reset_n), .clk_en(apu_clk_en_t));

    logic vga_clk_en_t, vga_clk_en;  // Master / 2
    clock_div #(2) v_ck(.clk(clock), .rst_n(reset_n), .clk_en(vga_clk_en_t));

    assign ppu_clk_en = ppu_clk_en_t && (done_load || no_load);
    assign cpu_clk_en = cpu_clk_en_t && (done_load || no_load);
    assign apu_clk_en = apu_clk_en_t && (done_load || no_load);
    assign vga_clk_en = vga_clk_en_t && (done_load || no_load);


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
    logic [7:0] ppuctrl, ppumask;

    mirror_t mirroring;

    // header 
    logic [7:0] flag6;
    logic [4:0] header_addr;
    logic [7:0] header_wr_data, header_rd_data;
    logic header_wr_en;

    assign header_addr = (~done_load && ~no_load) ? header_addr_sram : 5'd6; // flag 6 addr
    assign header_wr_data = header_wr_data_sram;
    assign header_wr_en = header_we_sram;

    header_ram hd_ram(.address(header_addr), .clock(clock), 
                      .data(header_wr_data), .wren(header_wr_en),
                      .q(header_rd_data));

    assign flag6 = header_rd_data;

    always_comb begin
        case ({flag6[3], flag6[0]})
            2'b00: mirroring = HOR_MIRROR;
            2'b01: mirroring = VER_MIRROR;
            2'b10: mirroring = FOUR_SCR_MIRROR;   // ONE_SCR_MIRROR?
            2'b11: mirroring = FOUR_SCR_MIRROR;
            default : mirroring = VER_MIRROR;
        endcase
    end

    logic retro_look;
    assign retro_look = SW[16];

    ppu peep(.clk(clock), .rst_n(reset_n), .ppu_clk_en, .vga_clk_en, .vblank_nmi, 
            .vsync_n(VGA_VS), .hsync_n(VGA_HS), 
            .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B), .blank, 
            .cpu_clk_en, .reg_sel, .reg_en, .reg_rw, .reg_data_in(reg_data_wr), .reg_data_out(reg_data_rd),
            .cpu_cyc_par, .cpu_sus, 
            .cpu_addr(mem_addr_p), .cpu_re(mem_re_p), .cpu_rd_data(mem_rd_data_p), 
            .ppuctrl, .ppumask,
            .mirroring,
            .retro_look,
            .chr_rom_addr_sram, .chr_rom_we_sram, .chr_rom_wr_data_sram);

    // APU
    logic [4:0] reg_addr;
    logic [7:0] reg_write_data;
    logic [7:0] reg_read_data;
    logic data_valid, reg_we;

    logic [15:0] direct_addr;
    logic [7:0] direct_data_in;
    logic direct_we;

    logic [15:0] audio_out;

    apu apooh (
      .clk(clock), .rst_l(reset_n), .cpu_clk_en, .apu_clk_en, .reg_addr,
      .reg_data_in(reg_write_data), .reg_en(data_valid), .reg_we, 
		.reg_data_out(reg_read_data), 
      .irq_l(irq_n), .audio_out,
      .direct_data_in, .direct_addr, .direct_we);
    
    logic VGA_CTRL_CLK, AUD_CTRL_CLK;    //  For Audio Controller
    assign AUD_DACLRCK = 1'bz;                         
    assign AUD_DACDAT = 1'bz;                         
    assign AUD_BCLK = 1'bz;                          
    assign AUD_XCK = 1'bz;     
    assign AUD_XCK = AUD_CTRL_CLK;

    // IPs to drive audio from Quartus
    VGA_Audio_PLL audio_pll (
      .areset(~reset_n), .inclk0(CLOCK_50), .c0(VGA_CTRL_CLK), 
      .c1(AUD_CTRL_CLK), .c2());

    //  Audio CODEC and video decoder setting
    I2C_AV_Config audio_config (
      .iCLK(CLOCK_50), .iRST_N(reset_n), .I2C_SCLK(I2C_SCLK), 
      .I2C_SDAT(I2C_SDAT));

    audio_dac dac (
      .clk(AUD_CTRL_CLK), .rst_l(reset_n), .audio(audio_out), .*);
      
    // CPU stuff
    logic [15:0] mem_addr_c;
    logic mem_re_c;
    logic [7:0] mem_wr_data_c;
    logic [7:0] mem_rd_data_c;
    logic [15:0] PC;
    logic irq_n;

    core cpu(.addr(mem_addr_c), .mem_r_en(mem_re_c), .w_data(mem_wr_data_c),
             .r_data(mem_rd_data_c), .clock_en(cpu_clk_en && !cpu_sus), .clock, .reset_n,
             .nmi(vblank_nmi), .PC_debug(PC), .irq_n);

    // CPU Memory Interface
    logic [15:0] mem_addr;
    logic mem_re;
    logic [7:0] mem_wr_data, mem_rd_data, read_prom;
    logic ctlr_latch;

    logic dmc_re;
    logic [14:0] dmc_addr;
    logic [7:0] dmc_read_data;

    assign mem_addr = (cpu_sus) ? mem_addr_p : mem_addr_c;
    assign mem_re = (cpu_sus) ? mem_re_p : mem_re_c;

    assign mem_wr_data = mem_wr_data_c;

    assign mem_rd_data_c = mem_rd_data;
    assign mem_rd_data_p = mem_rd_data;

    cpu_memory mem(.addr(mem_addr), .r_en(mem_re), .w_data(mem_wr_data), 
                   .clock, .clock_en(cpu_clk_en), .reset_n, .r_data(mem_rd_data), 
                   .reg_sel, .reg_en, .reg_rw, .reg_data_wr, .reg_data_rd,
                   .reg_addr, .reg_write_data, .reg_read_data, .data_valid, .reg_we,
                   .read_prom,
                   .ctlr_pulse_p1(GPIO[26]), .ctlr_pulse_p2(GPIO[11]),
                   .ctlr_latch, 
                   .ctlr_data_p1(GPIO[30]), .ctlr_data_p2(GPIO[15]),
                   .direct_data_in, .direct_addr, .direct_we,
                   .prom_wr_addr(prg_rom_addr_sram), .prom_we(prg_rom_we_sram),
                   .prom_wr_data(prg_rom_wr_data_sram));

    // controller pins:
    // P1: Power: 3.3V, pulse: 26, latch: 28, data: 30
    // P2: Power:    9, pules: 11, latch: 13, data: 15

    // powering p2's controller
    assign GPIO[9] = 1'b1;

    assign GPIO[28] = ctlr_latch;
    assign GPIO[13] = ctlr_latch;


    // see ppu status registers
    SevenSegmentDigit ppu_ctrl_hi(.bcd(ppuctrl[7:4]), .segment(HEX7), .blank(1'b0));
    SevenSegmentDigit ppu_ctrl_lo(.bcd(ppuctrl[3:0]), .segment(HEX6), .blank(1'b0));

    SevenSegmentDigit ppu_mask_hi(.bcd(flag6[7:4]), .segment(HEX5), .blank(1'b0));
    SevenSegmentDigit ppu_mask_lo(.bcd(flag6[3:0]), .segment(HEX4), .blank(1'b0));

    SevenSegmentDigit pc_3(.bcd(mem_addr_c[15:12]), .segment(HEX3), .blank(1'b0));
    SevenSegmentDigit pc_2(.bcd(mem_addr_c[11:8]), .segment(HEX2), .blank(1'b0));

    SevenSegmentDigit pc_1(.bcd(mem_addr_c[7:4]), .segment(HEX1), .blank(1'b0));
    SevenSegmentDigit pc_0(.bcd(mem_addr_c[3:0]), .segment(HEX0), .blank(1'b0));


endmodule: ChipInterface

module Stepper(
	input logic clock,
	input logic reset_n,
	
	input logic key_n,
	output logic clk_en);
	
	enum logic [1:0] {IDLE, CLK_EN, PRESSED} curr, next;
	
	always_ff @(posedge clock or negedge reset_n) begin
		if(~reset_n) begin
			curr<=IDLE;
			clk_en <= 1'b0;
		end
		else begin
			curr<=next;
			clk_en <= curr == CLK_EN;
		end
	end
	
	
	always_comb begin
		next = IDLE;
		case(curr)
			IDLE: begin
				next = (~key_n) ? CLK_EN : IDLE;
			end
			CLK_EN: begin
				next = (~key_n) ? PRESSED : IDLE;
			end
			PRESSED: begin
				next = (~key_n) ? PRESSED : IDLE;
			end
			default: ;
		endcase
	end
	
endmodule: Stepper
