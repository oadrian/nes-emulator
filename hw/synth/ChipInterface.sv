`default_nettype none
`include "../include/ucode_ctrl.vh"
`include "../include/cpu_types.vh"
`include "../include/ppu_defines.vh"

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
   // GPIO PINS
   inout logic [35:0] GPIO
   ); 

	logic reset_n;
    assign reset_n = SW[17];
	
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

  // save states

  logic [15:0] svst_state_read_data;
  logic [15:0] svst_mem_read_data;
  logic svst_begin_save_state, svst_begin_load_state;
  logic svst_state_write_en, svst_state_read_en;
  logic [`SAVE_STATE_BITS-1:0] svst_state_addr;
  logic [15:0] svst_state_write_data;
  logic svst_mem_write_en, svst_mem_read_en;
  logic [`SAVE_STATE_BITS-1:0] svst_mem_addr;
  logic [15:0] svst_mem_write_data;
  logic [15:0] mem_state_read_data;
  logic [15:0] cpu_state_read_data;

  save_state_module svst_module(
      .clock, .reset_n, 
      .state_read_data(svst_state_read_data),
      .mem_read_data(svst_mem_read_data),
      .begin_save_state(svst_begin_save_state),
      .begin_load_state(svst_begin_load_state),
      .stall(svst_stall),
      .state_write_en(svst_state_write_en),
      .state_read_en(svst_state_read_en),
      .state_addr(svst_state_addr),
      .state_write_data(svst_state_write_data),
      .mem_write_en(svst_mem_write_en),
      .mem_read_en(svst_mem_read_en),
      .mem_addr(svst_mem_addr),
      .mem_write_data(svst_mem_write_data));

  save_data_router svst_data_router(.clock, .reset_n, 
      .save_data(svst_state_read_data),
      .cpu_save_data(cpu_state_read_data), .mem_save_data(mem_state_read_data), 
      .state_addr(svst_state_addr));
	
	// ppu
      logic ppu_clk_en;  // Master / 4
    clock_div #(4) ppu_clk(.clk(clock), .rst_n(reset_n), .clk_en(ppu_clk_en), .stall(svst_stall));

    logic cpu_clk_en;  // Master / 12
    clock_div #(12) cpu_clk(.clk(clock), .rst_n(reset_n), .clk_en(cpu_clk_en), .stall(svst_stall));
//	 Stepper step(.clock, .reset_n, .key_n(KEY[3]), .clk_en(cpu_clk_en));

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
    logic [7:0] ppuctrl, ppumask, ppuscrollX, ppuscrollY;

    mirror_t mirroring;

    logic [7:0] header [15:0];
    logic [7:0] flag6, prgsz, chrsz;

    always_ff @(posedge clock or negedge reset_n) begin
      if(~reset_n) begin
        $readmemh("../init/header_init.txt", header);
      end
    end

    assign prgsz = header[4];
    assign chrsz = header[5];
    assign flag6 = header[6];

    always_comb begin
        case ({flag6[3], flag6[0]})
            2'b00: mirroring = HOR_MIRROR;
            2'b01: mirroring = VER_MIRROR;
            2'b10: mirroring = FOUR_SCR_MIRROR;   // ONE_SCR_MIRROR?
            2'b11: mirroring = FOUR_SCR_MIRROR;
            default : mirroring = VER_MIRROR;
        endcase
    end

    ppu peep(.clk(clock), .rst_n(reset_n), .ppu_clk_en, .vblank_nmi, 
            .vsync_n(VGA_VS), .hsync_n(VGA_HS), 
            .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B), .blank, 
            .cpu_clk_en, .reg_sel, .reg_en, .reg_rw, .reg_data_in(reg_data_wr), .reg_data_out(reg_data_rd),
            .cpu_cyc_par, .cpu_sus, 
            .cpu_addr(mem_addr_p), .cpu_re(mem_re_p), .cpu_rd_data(mem_rd_data_p), 
            .ppuctrl, .ppumask, .ppuscrollX, .ppuscrollY,
            .mirroring);

    // CPU stuff
    logic [15:0] mem_addr_c;
    logic mem_re_c;
    logic [7:0] mem_wr_data_c;
    logic [7:0] mem_rd_data_c;
    logic [15:0] PC;
    logic irq_n;

    assign irq_n = 1'b1;

    core cpu(.addr(mem_addr_c), .mem_r_en(mem_re_c), .w_data(mem_wr_data_c),
             .r_data(mem_rd_data_c), .clock_en(cpu_clk_en && !cpu_sus), .clock, .reset_n,
             .nmi(vblank_nmi), .PC_debug(PC), .irq_n,
             .save_state_load_en(svst_state_write_en),
             .save_state_addr(svst_state_addr),
             .save_state_load_data(svst_state_write_data),
             .save_state_save_data(cpu_state_read_data));

    // CPU Memory Interface
    logic [15:0] mem_addr;
    logic mem_re;
    logic [7:0] mem_wr_data, mem_rd_data, read_prom;
    logic ctlr_latch;

    assign mem_addr = (cpu_sus) ? mem_addr_p : mem_addr_c;
    assign mem_re = (cpu_sus) ? mem_re_p : mem_re_c;

    assign mem_wr_data = mem_wr_data_c;

    assign mem_rd_data_c = mem_rd_data;
    assign mem_rd_data_p = mem_rd_data;
	 

    cpu_memory mem(.addr(mem_addr), .r_en(mem_re), .w_data(mem_wr_data), 
                   .clock, .clock_en(cpu_clk_en), .reset_n, .r_data(mem_rd_data), 
                   .reg_sel, .reg_en, .reg_rw, .reg_data_wr, .reg_data_rd,
                   .read_prom,
                   .ctlr_pulse_p1(GPIO[26]), .ctlr_pulse_p2(GPIO[11]),
                   .ctlr_latch, 
                   .ctlr_data_p1(GPIO[30]), .ctlr_data_p2(GPIO[15]),
                   .svst_state_read_data(mem_state_read_data),
                   .svst_mem_read_data,
                   .svst_state_write_en, .svst_state_read_en,
                   .svst_state_addr, .svst_state_write_data,
                   .svst_mem_write_en, .svst_mem_read_en,
                   .svst_mem_addr, .svst_mem_write_data);

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

    SevenSegmentDigit ppu_mask_hi(.bcd(ppumask[7:4]), .segment(HEX5), .blank(1'b0));
    SevenSegmentDigit ppu_mask_lo(.bcd(ppumask[3:0]), .segment(HEX4), .blank(1'b0));

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