`default_nettype none
`include "ppu_defines.vh"


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

    // Secondary Read/Write OAM
        // clearing OAM 
    output logic sec_oam_clr, 

        // writing to OAM
    output logic sec_oam_wr,
    output second_oam_t sec_oam_wr_data

        // reading OAM
    output logic sec_oam_rd_idx,
    input logic sec_oam_rd_data,

    // Secondary Read Only OAM
    output logic sec_oam_mv

);
    
    assign oam_addr = col[7:0];

    second_oam_t curr_sprite_in, curr_sprite;

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            curr_sprite <= 49'd0;
        end else if(clk_en) begin
            curr_sprite <= curr_sprite_in;
        end
    end

    always_comb begin
        curr_sprite_in = 49'd0;
        sec_oam_wr_data = 49'd0;
        sec_oam_wr = 1'b0;
        unique case (hs_state)
            SL_PRE_CYC: begin 
                unique case (col[1:0])
                    2'd0: begin 
                        if(oam_data == row[7:0] + 8'd1) begin 
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

                            sec_oam_wr_data = curr_sprite_in;
                            sec_oam_wr = 1'b1;
                        end
                    end
                endcase
            end
            IDLE_CYC:
            SP_PRE_CYC:
            TL_PRE_CYC:
            GARB_CYC: 
        endcase
    
    end


endmodule