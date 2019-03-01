`default_nettype none
`include "ppu_defines.vh"

`define ATTR_TBL_OFF 11'h3C0

module bg_pixel (
    input logic clk, // Master clock
    input logic clk_en, // Master Clock / 4
    input logic rst_n,  // Asynchronous reset active low

    // current pixel to draw
    input logic [8:0] row,  // 262
    input logic [8:0] col,  // 341

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

    // chr rom (pattern table rom)
    output logic [12:0] chr_rom_addr1, chr_rom_addr2,
    input logic [7:0] chr_rom_data1, chr_rom_data2,

    // palette ram
    output logic [4:0] pal_addr, 
    input logic [7:0] pal_data,

    // output pixel
    output logic [7:0] pal_color
);

    //////////// Nametable ////////////
    logic [5:0] nametbl_row, nametbl_col;
    logic [2:0] tile_row, tile_col;

    logic [10:0] nametbl_idx, nametbl_off;
    logic [7:0] tile_idx;

    assign nametbl_row = row[8:3];  //  row / 8
    assign nametbl_col = col[8:3]; //  col / 8

    assign tile_row = row[2:0];    // row % 8
    assign tile_col = col[2:0];    // col % 8

    always_comb begin
        case (name_tbl) 
            TOP_L_TBL: nametbl_off = 11'h000;
            TOP_R_TBL: nametbl_off = 11'h400;
            BOT_L_TBL: nametbl_off = 11'h000;   // depends on mirroring
            BOT_R_TBL: nametbl_off = 11'h400;   // deppends on mirroring
            default : nametbl_off = 11'h000;  // top Left
        endcase
    end

    assign nametbl_idx = {nametbl_row, 5'b0} + {5'b0,nametbl_col}; 
    assign vram_addr1= nametbl_off + nametbl_idx;
    assign tile_idx = vram_data1;  // tile info

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

    //////////// Attribute table ////////////
    logic [1:0] pal_idx;
    logic [3:0] attrtbl_row, attrtbl_col;
    logic [4:0] block_row, block_col;

    logic [10:0] attrtbl_idx;
    logic [7:0] attr_blk;

    assign attrtbl_row = row[8:5]; // row / 32
    assign attrtbl_col = col[8:5]; // col / 32

    assign block_row = row[4:0];   // row % 32
    assign block_col = col[4:0];   // col % 32

    assign attrtbl_idx = {4'b0,attrtbl_row,3'b0} + {7'b0, attrtbl_col}; 
    assign vram_addr2 = nametbl_off + `ATTR_TBL_OFF + attrtbl_idx;
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
        // case (block_row < 5'd16, block_col < 5'd16)
        //     1'b1, 1'b1: pal_idx = attr_blk[1:0];       // TOPLEFT
        //     1'b1, 1'b0: pal_idx = attr_blk[3:2];       // TOPRIGHT
        //     1'b0, 1'b1: pal_idx = attr_blk[5:4];       // BOTLEFT
        //     1'b0, 1'b0: pal_idx = attr_blk[7:6];       // BOTRIGHT
        // endcase    
    end

    // palette color index
    logic [3:0] pal_color_idx;

    always_comb begin 
        pal_color_idx = {pal_idx, color_idx};
        if(pal_color_idx == 4'h4 || pal_color_idx == 4'h8 || pal_color_idx == 4'hC) 
            pal_color_idx = 4'h0;
    end

    assign pal_addr = pal_color_idx;
    assign pal_color = pal_data;

endmodule