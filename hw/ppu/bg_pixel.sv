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
    input logic [7:0] ppuscrollX, ppuscrollY // (x,y) in name_tbl to start
                                             // rendering from
);
    logic [8:0] act_row, act_col, row, col;
    logic row_ovf, col_ovf;

    assign act_row = (ppuscrollY < 8'd240) ? sl_row + {1'b0,ppuscrollY} : sl_row - {1'b0, (~ppuscrollY + 8'd1)};
    assign act_col = sl_col + {1'b0, ppuscrollX};

    assign row_ovf = act_row >= 9'd240;
    assign col_ovf = act_col[8];        // col >= 256

    assign row = (row_ovf) ? act_row - 9'd240 : act_row;
    assign col = {1'b0, act_col[7:0]};

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
        nametbl_off = 11'h000;
        if(mirroring == VER_MIRROR) begin 
            case (name_tbl) 
                TOP_L_TBL: nametbl_off = (!col_ovf) ? 11'h000 : 11'h400;
                TOP_R_TBL: nametbl_off = (!col_ovf) ? 11'h400 : 11'h000;
                BOT_L_TBL: nametbl_off = (!col_ovf) ? 11'h000 : 11'h400;   // depends on mirroring
                BOT_R_TBL: nametbl_off = (!col_ovf) ? 11'h400 : 11'h000;   // deppends on mirroring
            endcase
        end else if(mirroring == HOR_MIRROR) begin
            case (name_tbl) 
                TOP_L_TBL: nametbl_off = (!row_ovf) ? 11'h000 : 11'h400;
                TOP_R_TBL: nametbl_off = (!row_ovf) ? 11'h000 : 11'h400;
                BOT_L_TBL: nametbl_off = (!row_ovf) ? 11'h400 : 11'h000;   // depends on mirroring
                BOT_R_TBL: nametbl_off = (!row_ovf) ? 11'h400 : 11'h000;   // deppends on mirroring
            endcase
        end 
    end

    assign nametbl_idx = {nametbl_row, 5'b0} + {5'b0,nametbl_col}; 
    assign vram_addr1= nametbl_off + nametbl_idx;
    assign tile_idx = vram_data1;  // tile info

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