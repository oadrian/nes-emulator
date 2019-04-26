`default_nettype none
// `include "ppu_defines.vh"

`define ATTR_TBL_OFF 11'h3C0

module bg_pixel (
    input logic clk, 
    input logic rst_n,
    input logic clk_en,

    // current pixel to draw
    input logic [8:0] sl_row,  // 262
    input logic [8:0] sl_col,  // 341

    // pattern table
    input pattern_tbl_t patt_tbl,

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
    input logic [15:0] vAddr, 
    input [2:0] fX,

    output logic h_scroll, v_scroll, h_update, v_update
);
    logic [2:0] tile_pixel;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            tile_pixel <= 0;
        end else if(clk_en) begin
            if(sl_col == 9'd340)
                tile_pixel <= 3'd0;
            else
                tile_pixel <= tile_pixel + 3'd1;
        end
    end

    logic [2:0] net_fX;
    assign net_fX = fX + tile_pixel;

    assign h_scroll = net_fX == 3'd7 && 
                    (9'd0 <= sl_row && sl_row < 9'd240) &&
                    (9'd0 <= sl_col && sl_col < 9'd256);
    assign v_scroll = sl_col == 9'd256 && 
                    (9'd0 <= sl_row && sl_row < 9'd240);

    assign h_update = sl_col == 9'd257 && 
                    (9'd0 <= sl_row && sl_row < 9'd240);

    assign v_update = (9'd280 <= sl_col && sl_col <= 9'd304) &&
                    sl_row == 9'h1FF;  // -1 scanline
    

    //////////// Nametable ////////////
    logic [7:0] tile_idx;
    logic [15:0] nt_addr;

    assign nt_addr = 16'h2000 | vAddr[11:0];

    vram_mirroring vm1(.addr(nt_addr), .mirroring, .vram_addr(vram_addr1));
    
    assign tile_idx = vram_data1;  // tile info

    //////////// Attribute table ////////////
    logic [1:0] pal_idx;
    logic [7:0] attr_blk;
    logic [15:0] at_addr;

    assign at_addr = 16'h23C0 | {4'b0, vAddr[11:10], 4'b0, vAddr[9:7], vAddr[4:2]};
    vram_mirroring vm2(.addr(at_addr), .mirroring, .vram_addr(vram_addr2));
    assign attr_blk = vram_data2;

    always_comb begin
        pal_idx = attr_blk[1:0];
        if(vAddr[6] == 1'b0 && vAddr[1] == 1'b0)
            pal_idx = attr_blk[1:0];       // TOPLEFT
        else if(vAddr[6] == 1'b0 && vAddr[1] == 1'b1)
            pal_idx = attr_blk[3:2];       // TOPRIGHT
        else if(vAddr[6] == 1'b1 && vAddr[1] == 1'b0)
            pal_idx = attr_blk[5:4];       // BOTLEFT
        else if(vAddr[6] == 1'b1 && vAddr[1] == 1'b1)
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

    assign pattbl_idx = {1'b0, tile_idx, 1'b0, vAddr[14:12]};
    assign chr_rom_addr1 = pattbl_off | pattbl_idx;
    assign chr_rom_addr2 = chr_rom_addr1 | 13'd8;

    assign tile_lsb = chr_rom_data1;
    assign tile_msb = chr_rom_data2;

    logic [2:0] bit_idx;
    assign bit_idx = 3'd7 - net_fX;
    assign color_idx = {tile_msb[bit_idx], tile_lsb[bit_idx]};

    // background color index
    always_comb begin 
        bg_color_idx = {pal_idx, color_idx};
        if(bg_color_idx == 4'h4 || bg_color_idx == 4'h8 || bg_color_idx == 4'hC) 
            bg_color_idx = 4'h0;
    end

endmodule