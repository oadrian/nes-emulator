`default_nettype none
`include "ppu_defines.vh"

module ppu (
    input clk,    // Master Clock
    input rst_n,  // Asynchronous reset active low

    // NMI VBlank
    output logic vblank, // IRQ signal to cpu

    // VGA 
    output logic vsync_n,     // vga vsync enable low
    output logic hsync_n,     // vga hsync enable low
    output logic [2:0] vga_r, // vga red 
    output logic [2:0] vga_g, // vga green
    output logic [1:0] vga_b  // vga blue
);

    // VGA converter
    logic vga_clk_en;  // Master / 2
    clock_div #(DIV=2) v_ck(.clk, .rst_n, .clk_en(vga_clk_en));

    // internal PPU clock
    logic ppu_clk_en;  // Master / 4
    clock_div #(DIV=4) p_ck(.clk, .rst_n, .clk_en(ppu_clk_en));


    // VRAM (SYNC READ)
    logic [10:0] vram_addr;
    logic vram_we;
    logic [7:0] vram_d_in, vram_d_out;

    vram vr(.clk, .clk_en(ppu_clk_en), .rst_n, 
            .addr(vram_addr), .we(vram_we),  
            .data_in(vram_d_in), .data_out(vram_d_out));

    // OAM
    logic [5:0] oam_addr;
    logic oam_we;
    logic [7:0] oam_d_in, oam_d_out;

    oam om(.clk, .clk_en(ppu_clk_en), .rst_n, .addr(oam_addr), .we(oam_we), 
            .data_in(oam_d_in), .data_out(oam_d_out));

    // PAL_RAM
    logic [4:0] pal_addr;
    logic pal_we;
    logic [7:0] pal_d_in, pal_d_out;

    pal_ram pr(.clk, .clk_en(ppu_clk_en), .rst_n, .addr(pal_addr), .we(pal_we), 
            .data_in(pal_d_in), .data_out(pal_d_out));

    // CHR_ROM
    logic [12:0] chr_rom_addr1, chr_rom_addr2;
    logic [7:0] chr_rom_out1, chr_rom_out2;

    chr_rom cr(.clk, .clk_en(ppu_clk_en), .rst_n,
               .addr1(chr_rom_addr1), .addr2(chr_rom_addr2),
               .data_out1(chr_rom_out1), .data_out2(chr_rom_out2));


    // Scanline buffer
    local parameter VIS_SL_WIDTH = 256;
    local parameter VIS_SL_HEIGHT = 240;


    logic [5:0] ppu_buffer[VIS_SL_WIDTH-1:0]; // 256 color indexes
    logic ppu_buffer_wr;
    logic [7:0] ppu_buf_idx;
    logic [5:0] ppu_buf_in;

    always_ff @(posedge clk or negedge rst_n)
        if(~rst_n) begin
            ppu_buf_idx <= 0;
            for(int i = 0; i<VIS_SL_WIDTH; i++) begin 
                ppu_buffer[i] = 6'h0f; // black
            end
        end else if(ppu_clk_en && ppu_buffer_wr) begin
            ppu_buffer[ppu_buf_idx] <= ppu_buf_in;
            ppu_buf_idx <= ppu_buf_idx + 1;
        end
    end

    // Temp OAM buffer

    

endmodule