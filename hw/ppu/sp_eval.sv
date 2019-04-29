`default_nettype none
`include "../include/ppu_defines.vh"


module sp_eval (
    input logic clk, // Master clock
    input logic clk_en, // Clock Enable (PPU Clock = Master clock/4)
    input logic rst_n,  // Asynchronous reset active low

    // current pixel coordinates
    input logic [8:0] row,   // 262
    input logic [8:0] col,   // 341

    // horizontal state
    input hs_state_t hs_state,

    // pattern table
    input pattern_tbl_t patt_tbl,

    // OAM
    output logic [7:0] oam_addr,
    input logic [7:0] oam_data,

    // Temp OAM
        // clearing Temp OAM 
    output logic temp_oam_clr, 

        // writing to Temp OAM
    output logic temp_oam_wr,
    output second_oam_t temp_oam_wr_data,

        // reading Temp OAM
    output logic [2:0] temp_oam_rd_idx,
    input second_oam_t temp_oam_rd_data,

    // Secondary OAM  
        // clearing secondary OAM
    output logic sec_oam_clr,

        // Writing to Secondary OAM
    output logic sec_oam_wr,
    output second_oam_t sec_oam_wr_data,

    // chr rom (pattern table rom)
    output logic [12:0] chr_rom_addr1, chr_rom_addr2,
    input logic [7:0] chr_rom_data1, chr_rom_data2,
    output logic chr_rom_re
);
    logic [8:0] next_row;
    assign next_row = row - 9'd1;

    // register for current sprite information
    second_oam_t curr_sprite_in, curr_sprite;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            curr_sprite <= 'd0;
        end else if(clk_en) begin
            curr_sprite <= curr_sprite_in;
        end
    end
    
    // constantly reading primary OAM for the SL_PRE_CYC 
    assign oam_addr = col[7:0];

    // write data to sec_oam enabled with temp_oam_wr 
    assign temp_oam_wr_data = curr_sprite_in;

    
    // constantly reading temp OAM, used for SP_PRE_CYC section
    logic [8:0] sp_pre_col;
    assign sp_pre_col =  col - 9'd257;  // 257 is the start cycle of SP_PRE_CYC
    assign temp_oam_rd_idx = sp_pre_col[2:0];

    // Pattern Table Reading
    logic [12:0] pattbl_off, pattbl_idx;    
    logic [7:0] tile_lsb, tile_msb;
    logic [2:0] tile_row;
    logic [8:0] norm_row;
    logic [7:0] tile_idx;
    logic flip_ver;

    always_comb begin
        case (patt_tbl)
            LEFT_TBL: pattbl_off = 13'h0000;
            RIGHT_TBL: pattbl_off = 13'h1000;
            default : pattbl_off = 13'h0000;
        endcase
    
    end

    assign tile_idx = temp_oam_rd_data.tile_idx;
    assign flip_ver = temp_oam_rd_data.attribute[7];
    assign norm_row = next_row - {1'b0, temp_oam_rd_data.y_pos};
    assign tile_row = (flip_ver) ? 3'd7 - norm_row[2:0] : norm_row[2:0]; 
 
    assign pattbl_idx = {1'b0, tile_idx, 1'b0, tile_row};
    assign chr_rom_addr1 = pattbl_off + pattbl_idx;
    assign chr_rom_addr2 = chr_rom_addr1 + 13'd8;

    assign tile_lsb = chr_rom_data1;
    assign tile_msb = chr_rom_data2;

    always_comb begin
        curr_sprite_in = 'd0;

        // clearing temp OAM
        temp_oam_clr = 1'b0;
        // Write to temp OAM
        temp_oam_wr = 1'b0;

        // clearing sec OAM
        sec_oam_clr = 1'b0;
        // write to sec OAM
        sec_oam_wr = 1'b0;
        // write data to sec OAM
        sec_oam_wr_data = 'd0;

        chr_rom_re = 1'b0;

        case (hs_state)
            SL_PRE_CYC: begin 
                case (col[1:0])
                    2'd0: begin 
                        if({1'b0, oam_data} <= next_row && next_row < {1'b0, oam_data} + `SPRITE_WIDTH) begin 
                            curr_sprite_in.active = 1'b1;
                            curr_sprite_in.y_pos = oam_data;
                        end 
                    end
                    2'd1: begin 
                        if(curr_sprite.active) begin 
                            curr_sprite_in.active = curr_sprite.active;
                            curr_sprite_in.y_pos = curr_sprite.y_pos;
                            curr_sprite_in.tile_idx = oam_data;
                        end
                    end
                    2'd2: begin 
                        if(curr_sprite.active) begin 
                            curr_sprite_in.active = curr_sprite.active;
                            curr_sprite_in.y_pos = curr_sprite.y_pos;
                            curr_sprite_in.tile_idx = curr_sprite.tile_idx;
                            curr_sprite_in.attribute = oam_data;
                        end
                    end
                    2'd3: begin 
                        if(curr_sprite.active) begin 
                            curr_sprite_in.active = curr_sprite.active;
                            curr_sprite_in.y_pos = curr_sprite.y_pos;
                            curr_sprite_in.tile_idx = curr_sprite.tile_idx;
                            curr_sprite_in.attribute = curr_sprite.attribute;
                            curr_sprite_in.x_pos = oam_data;

                            // write curr_sprite_in to secondary OAM
                            temp_oam_wr = 1'b1;
                        end
                    end
                    default: ;
                endcase
            end
            IDLE_CYC: begin 
                sec_oam_clr = 1'b1;
            end
            SP_PRE_CYC: begin 
                // only first 8 writes will go through to secondary OAM
                chr_rom_re = 1'b1;
                sec_oam_wr = 1'b1;
                sec_oam_wr_data.active = temp_oam_rd_data.active;
                sec_oam_wr_data.y_pos = temp_oam_rd_data.y_pos;
                sec_oam_wr_data.tile_idx = temp_oam_rd_data.tile_idx;
                sec_oam_wr_data.attribute = temp_oam_rd_data.attribute;
                sec_oam_wr_data.x_pos = temp_oam_rd_data.x_pos;
                sec_oam_wr_data.bitmap_hi = tile_msb;
                sec_oam_wr_data.bitmap_lo = tile_lsb;
            end
            TL_PRE_CYC:
            GARB_CYC: begin 
                temp_oam_clr = 1'b1;
            end
            default: ;
        endcase
    
    end


endmodule