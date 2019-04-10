`default_nettype none
`include "../include/ppu_defines.vh"


module sp_pixel (
    // current pixel to draw
    input logic [8:0] row,
    input logic [8:0] col,

    // Second OAM 
    input second_oam_t sec_oam [7:0],  // the second oam entries
 
    // output pixel (pal_idx << 2 | color_idx)
    output logic [3:0] sp_color_idx,
    output logic sp_prio,
    output logic sp_zero
);


    // Get color sp_color_idx for all sprites in the sec_oam
    logic [3:0] sp_color_idxs [7:0];
    logic [7:0] sp_prios;
    genvar i;
    generate
        for (i = 0; i < 8; i++) begin: sp_blocks_inst
            sp_pixel_h sp_inst(.row, .col, .sprite(sec_oam[i]), .sp_color_idx(sp_color_idxs[i]), .sp_prio(sp_prios[i]));
        end
    endgenerate

    // find the first active, non-transparent, and within range sprite in sec_oam
    always_comb begin
        sp_color_idx = 4'd0;
        sp_prio = 1'b0;
        sp_zero = 1'b0;
        if(sec_oam[0].active && sp_color_idxs[0][1:0] != 2'b00 && sec_oam[0].x_pos <= col && col < sec_oam[0].x_pos + `SPRITE_WIDTH) begin 
            sp_color_idx = sp_color_idxs[0];
            sp_prio = sp_prios[0];
            sp_zero = 1'b1;
        end else if(sec_oam[1].active && sp_color_idxs[1][1:0] != 2'b00 && sec_oam[1].x_pos <= col && col < sec_oam[1].x_pos + `SPRITE_WIDTH) begin 
            sp_color_idx = sp_color_idxs[1];
            sp_prio = sp_prios[1];
        end else if(sec_oam[2].active && sp_color_idxs[2][1:0] != 2'b00 && sec_oam[2].x_pos <= col && col < sec_oam[2].x_pos + `SPRITE_WIDTH) begin 
            sp_color_idx = sp_color_idxs[2];
            sp_prio = sp_prios[2];
        end else if(sec_oam[3].active && sp_color_idxs[3][1:0] != 2'b00 && sec_oam[3].x_pos <= col && col < sec_oam[3].x_pos + `SPRITE_WIDTH) begin 
            sp_color_idx = sp_color_idxs[3];
            sp_prio = sp_prios[3];
        end else if(sec_oam[4].active && sp_color_idxs[4][1:0] != 2'b00 && sec_oam[4].x_pos <= col && col < sec_oam[4].x_pos + `SPRITE_WIDTH) begin 
            sp_color_idx = sp_color_idxs[4];
            sp_prio = sp_prios[4];
        end else if(sec_oam[5].active && sp_color_idxs[5][1:0] != 2'b00 && sec_oam[5].x_pos <= col && col < sec_oam[5].x_pos + `SPRITE_WIDTH) begin 
            sp_color_idx = sp_color_idxs[5];
            sp_prio = sp_prios[5];
        end else if(sec_oam[6].active && sp_color_idxs[6][1:0] != 2'b00 && sec_oam[6].x_pos <= col && col < sec_oam[6].x_pos + `SPRITE_WIDTH) begin 
            sp_color_idx = sp_color_idxs[6];
            sp_prio = sp_prios[6];
        end else if(sec_oam[7].active && sp_color_idxs[7][1:0] != 2'b00 && sec_oam[7].x_pos <= col && col < sec_oam[7].x_pos + `SPRITE_WIDTH) begin 
            sp_color_idx = sp_color_idxs[7];
            sp_prio = sp_prios[7];
        end
    end


endmodule

module sp_pixel_h (
    input logic [8:0] row,
    input logic [8:0] col,

    input second_oam_t sprite,

    output logic [3:0] sp_color_idx,
    output logic sp_prio
);

    logic [7:0] sp_bitmap_hi, sp_bitmap_lo;
    logic [1:0] pal_idx, color_idx;
    logic flip_hor;

    logic [2:0] bit_idx;
    logic [7:0] col_within;

    assign col_within = col[7:0] - sprite.x_pos;
    assign sp_bitmap_hi = sprite.bitmap_hi;
    assign sp_bitmap_lo = sprite.bitmap_lo;
    assign pal_idx = sprite.attribute[1:0];
    assign sp_prio = sprite.attribute[5];
    assign flip_hor = sprite.attribute[6];

    assign bit_idx = (flip_hor) ? col_within[2:0] : 3'd7 - col_within[2:0];
    assign color_idx = {sp_bitmap_hi[bit_idx], sp_bitmap_lo[bit_idx]};
    
    assign sp_color_idx = {pal_idx, color_idx};

endmodule