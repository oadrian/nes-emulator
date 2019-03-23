`default_nettype none
`include "ppu_defines.vh"


module sp_pixel (
    // current pixel to draw
    input logic [8:0] row,
    input logic [8:0] col,

    // Second OAM 
    input second_oam_t sec_oam [7:0],  // the second oam entries
 
    // output pixel (pal_idx << 2 | color_idx)
    output logic [3:0] sp_color_idx,
    output logic sp_prio
);

    // find current active sprite
    second_oam_t curr_sp;
    logic sp_active;
    always_comb begin
        curr_sp = 'd0;
        sp_active = 0;
        if(sec_oam[0].active && sec_oam[0].x_pos <= col && col < sec_oam[0].x_pos + `SPRITE_WIDTH) begin 
            curr_sp = sec_oam[0];
            sp_active = 1'b1;
        end else if(sec_oam[1].active && sec_oam[1].x_pos <= col && col < sec_oam[1].x_pos + `SPRITE_WIDTH) begin 
            curr_sp = sec_oam[1];
            sp_active = 1'b1;
        end else if(sec_oam[2].active && sec_oam[2].x_pos <= col && col < sec_oam[2].x_pos + `SPRITE_WIDTH) begin 
            curr_sp = sec_oam[2];
            sp_active = 1'b1;
        end else if(sec_oam[3].active && sec_oam[3].x_pos <= col && col < sec_oam[3].x_pos + `SPRITE_WIDTH) begin 
            curr_sp = sec_oam[3];
            sp_active = 1'b1;
        end else if(sec_oam[4].active && sec_oam[4].x_pos <= col && col < sec_oam[4].x_pos + `SPRITE_WIDTH) begin 
            curr_sp = sec_oam[4];
            sp_active = 1'b1;
        end else if(sec_oam[5].active && sec_oam[5].x_pos <= col && col < sec_oam[5].x_pos + `SPRITE_WIDTH) begin 
            curr_sp = sec_oam[5];
            sp_active = 1'b1;
        end else if(sec_oam[6].active && sec_oam[6].x_pos <= col && col < sec_oam[6].x_pos + `SPRITE_WIDTH) begin 
            curr_sp = sec_oam[6];
            sp_active = 1'b1;
        end else if(sec_oam[7].active && sec_oam[7].x_pos <= col && col < sec_oam[7].x_pos + `SPRITE_WIDTH) begin 
            curr_sp = sec_oam[7];
            sp_active = 1'b1;
        end
    end
    
    // 
    logic [7:0] sp_bitmap_hi, sp_bitmap_lo;
    logic [1:0] pal_idx, color_idx;
    logic flip_hor;

    logic [2:0] bit_idx;
    logic [7:0] col_within;
    assign col_within = col[7:0] - curr_sp.x_pos;
    always_comb begin
        sp_bitmap_hi = curr_sp.bitmap_hi;
        sp_bitmap_lo = curr_sp.bitmap_lo;
        pal_idx = curr_sp.attribute[1:0];
        sp_prio = curr_sp.attribute[5];
        flip_hor = curr_sp.attribute[6];
        
        bit_idx = 3'd0;
        color_idx = 2'd0;
        if(sp_active) begin
            if(flip_hor) begin 
                bit_idx = col_within[2:0]; 
            end else begin
                bit_idx = 3'd7 - col_within[2:0];
            end
            color_idx = {sp_bitmap_hi[bit_idx], sp_bitmap_lo[bit_idx]};
        end
    end


    assign sp_color_idx = {pal_idx, color_idx};

endmodule