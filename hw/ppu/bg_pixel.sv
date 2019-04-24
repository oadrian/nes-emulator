`default_nettype none
// `include "ppu_defines.vh"

`define ATTR_TBL_OFF 11'h3C0

module bg_pixel (
    // current pixel to draw
    input logic [8:0] sl_row,  // 262
    input logic [8:0] sl_col,  // 341

    // pattern table
    input pattern_tbl_t patt_tbl,

    // nametable 
    input name_tbl_t name_tbl,

    // vram  
            // access nametable
    output logic [10:0] vram_addr1,
    input logic [7:0] vram_data1,
            // access attribute table
    output logic [10:0] vram_addr2,
    input logic [7:0] vram_data2,

    // mirroring
    input mirror_t mirroring, 

    // chr rom (pattern table rom)
    output logic [12:0] chr_rom_addr1, chr_rom_addr2,
    input logic [7:0] chr_rom_data1, chr_rom_data2,

    // output pixel (pal_idx << 2 || color_idx)
    output logic [3:0] bg_color_idx,

    // scrolling
    input addr_t vAddr, 
    input [2:0] fX
);

    //////////// Nametable ////////////
    logic [7:0] tile_idx;
    logic [15:0] nt_addr;

    assign nt_addr = 16'h2000 | vAddr.r[11:0];

    vram_mirroring vm1(.addr(nt_addr), .mirroring, .vram_addr(vram_addr1));
    
    assign tile_idx = vram_data1;  // tile info

    //////////// Attribute table ////////////
    logic [1:0] pal_idx;
    logic [7:0] attr_blk;
    logic [15:0] at_addr;

    assign at_addr = 16'h23C0 | {4'b0, vAddr.nt, 4'b0, vAddr.cY[4:2], vAddr.cX[4:2]};
    vram_mirroring vm2(.addr(at_addr), .mirroring, .vram_addr(vram_addr2));
    assign attr_blk = vram_data2;

    always_comb begin
        pal_idx = attr_blk[1:0];

        if(block_row < 5'd16 && block_col < 5'd16)
            pal_idx = attr_blk[1:0];       // TOPLEFT
        else if(block_row < 5'd16 && block_col >= 5'd16)
            pal_idx = attr_blk[3:2];       // TOPRIGHT
        else if(block_row >= 5'd16 && block_col < 5'd16)
            pal_idx = attr_blk[5:4];       // BOTLEFT
        else if(block_row >= 5'd16 && block_col >= 5'd16)
            pal_idx = attr_blk[7:6];       // BOTRIGHT   
    end

    //////////// Pattern table //////////////
    logic [1:0] color_idx;
    logic [12:0] pattbl_off, pattbl_idx;    
    logic [7:0] tile_lsb, tile_msb;

    always_comb begin
        case (patt_tbl)
            LEFT_TBL: pattbl_off = 13'h0000;
            RIGHT_TBL: pattbl_off = 13'h1000;
            default : pattbl_off = 13'h0000;
        endcase
    
    end

    assign pattbl_idx = {1'b0, tile_idx, 1'b0, tile_row};
    assign chr_rom_addr1 = pattbl_off + pattbl_idx;
    assign chr_rom_addr2 = chr_rom_addr1 + 13'd8;

    assign tile_lsb = chr_rom_data1;
    assign tile_msb = chr_rom_data2;

    logic [2:0] bit_idx;
    assign bit_idx = 3'd7-tile_col;
    assign color_idx = {tile_msb[bit_idx], tile_lsb[bit_idx]};

    // background color index
    always_comb begin 
        bg_color_idx = {pal_idx, color_idx};
        if(bg_color_idx == 4'h4 || bg_color_idx == 4'h8 || bg_color_idx == 4'hC) 
            bg_color_idx = 4'h0;
    end

endmodule