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

    output logic h_scroll, v_scroll, h_update, v_update,

    input vs_state_t vs_state,
    input hs_state_t hs_state
);

    assign v_scroll = sl_col == 9'd256 && vs_state == VIS_SL; 
    assign h_update = 
                // (mirroring == VER_MIRROR) ? 
                // sl_col == 9'd257 && (vs_state == VIS_SL) : 
                sl_col == 9'd257 && (vs_state == VIS_SL || vs_state == PRE_SL);
    assign v_update = (9'd280 <= sl_col && sl_col <= 9'd304) && (vs_state == PRE_SL);

    //////////// Nametable ////////////
    logic [7:0] nt;
    logic nt_ld;
    logic [15:0] nt_addr;

    assign nt_addr = 16'h2000 | vAddr[11:0];

    vram_mirroring vm1(.addr(nt_addr), .mirroring, .vram_addr(vram_addr1));

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            nt <= 8'd0;
        end else if(clk_en) begin
            if(nt_ld)
                nt <= vram_data1;
        end
    end
    
    //////////// Attribute table ////////////
    logic [1:0] at;
    logic at_ld;
    logic [15:0] at_addr;

    assign at_addr = 16'h23C0 | {4'b0, vAddr[11:10], 4'b0, vAddr[9:7], vAddr[4:2]};
    vram_mirroring vm2(.addr(at_addr), .mirroring, .vram_addr(vram_addr2));

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
           at <= 2'd0;
        end else if(clk_en) begin
            if(at_ld) begin 
                if(vAddr[6] == 1'b0 && vAddr[1] == 1'b0)
                    at <= vram_data2[1:0];       // TOPLEFT
                else if(vAddr[6] == 1'b0 && vAddr[1] == 1'b1)
                    at <= vram_data2[3:2];       // TOPRIGHT
                else if(vAddr[6] == 1'b1 && vAddr[1] == 1'b0)
                    at <= vram_data2[5:4];       // BOTLEFT
                else if(vAddr[6] == 1'b1 && vAddr[1] == 1'b1)
                    at <= vram_data2[7:6];       // BOTRIGHT              
            end
        end
    end

    //////////// Pattern table //////////////
    logic pattbl_off;    
    logic [7:0] bg_l, bg_h;
    logic bg_l_ld, bg_h_ld;

    always_comb begin
        pattbl_off = 1'b0;
        case (patt_tbl)
            LEFT_TBL: pattbl_off = 1'b0;
            RIGHT_TBL: pattbl_off = 1'b1;
            default : ;
        endcase
    
    end

    assign chr_rom_addr1 = {pattbl_off, nt, 1'b0, vAddr[14:12]};
    assign chr_rom_addr2 = chr_rom_addr1 | 13'd8;

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            bg_l <= 8'd0;
            bg_h <= 8'd0;
        end else if(clk_en) begin
            if(bg_l_ld)
                bg_l <= chr_rom_data1;
            if(bg_h_ld)
                bg_h <= chr_rom_data2;
        end
    end

    /////// tile and attribute data for two consecutive tiles /////////
    logic [15:0] bg_l_both, bg_h_both;
    logic [1:0] at_l_both, at_h_both;
    logic bg_next_ld, bg_next_sh, at_next_ld, at_next_sh;

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            bg_l_both <= 0;
            bg_h_both <= 0;
        end else if(clk_en) begin
            if(bg_next_sh && bg_next_ld) begin
                bg_l_both <= {bg_l_both[7:0], bg_l};
                bg_h_both <= {bg_h_both[7:0], bg_h};
            end else if(bg_next_sh) begin
                bg_l_both <= {bg_l_both[7:0], 8'd0};
                bg_h_both <= {bg_h_both[7:0], 8'd0};
            end else if(bg_next_ld) begin 
                bg_l_both <= {bg_l_both[15:8], bg_l};
                bg_h_both <= {bg_h_both[15:8], bg_h};
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            at_l_both <= 0;
            at_h_both <= 0;
        end else if(clk_en) begin
            if(at_next_sh && at_next_ld) begin 
                at_l_both <= {at_l_both[0], at[0]};
                at_h_both <= {at_h_both[0], at[1]}; 
            end  else if (at_next_sh) begin 
                at_l_both <= {at_l_both[0], 1'b0};
                at_h_both <= {at_h_both[0], 1'b0};
            end else if(at_next_ld) begin 
                at_l_both <= {at_l_both[1], at[0]};
                at_h_both <= {at_h_both[1], at[1]};
            end
        end
    end

    logic [8:0] tl_pre_col;
    assign tl_pre_col = sl_col - 9'd321;
    always_comb begin
        // nametable load
        nt_ld = 1'b0;

        // attribute table load
        at_ld = 1'b0;

        // background registers
        bg_l_ld = 1'b0;
        bg_h_ld = 1'b0;

        // background tile registers
        bg_next_sh = 1'b0;    
        bg_next_ld = 1'b0;
        at_next_sh = 1'b0;
        at_next_ld = 1'b0;

        // h_scroll
        h_scroll = 1'b0;
        case (hs_state)
            SL_PRE_CYC: begin 
                case (sl_col[2:0])
                    3'd0: begin 
                        bg_next_ld = 1'b1;
                        at_next_ld = 1'b1;
                    end
                    3'd1: nt_ld = 1'b1; 
                    3'd3: at_ld = 1'b1;
                    3'd5: bg_l_ld = 1'b1;
                    3'd7: begin 
                        bg_h_ld = 1'b1;
                        h_scroll = (vs_state == VIS_SL) ? 1'b1 : 1'b0;

                        bg_next_sh = 1'b1;
                        at_next_sh = 1'b1;
                    end
                    default : /* default */;
                endcase
            end
            TL_PRE_CYC: begin
                case (tl_pre_col[2:0])
                    3'd0: begin 
                        bg_next_ld = 1'b1;
                        at_next_ld = 1'b1;
                    end
                    3'd1: nt_ld = 1'b1; 
                    3'd3: at_ld = 1'b1;
                    3'd5: bg_l_ld = 1'b1;
                    3'd7: begin 
                        bg_h_ld = 1'b1;
                        h_scroll = (vs_state == VIS_SL || vs_state == PRE_SL) ? 1'b1 : 1'b0;

                        bg_next_sh = 1'b1;
                        at_next_sh = 1'b1;
                    end
                    default : /* default */;
                endcase
            end
            default : /* default */;
        endcase

    
    end

    // net x position
    logic [2:0] net_fX, bit_idx;
    logic ovf;

    logic [7:0] tile_lsb, tile_msb;
    logic [1:0] pal_idx, color_idx;

    assign {ovf, net_fX} = {1'b0, fX} + {1'b0, sl_col[2:0]};

    assign tile_lsb = (ovf) ? bg_l_both[7:0] : bg_l_both[15:8];
    assign tile_msb = (ovf) ? bg_h_both[7:0] : bg_h_both[15:8];

    assign bit_idx = 3'd7 - net_fX;

    assign pal_idx = (ovf) ? {at_h_both[0], at_l_both[0]} : {at_h_both[1], at_l_both[1]};
    assign color_idx = {tile_msb[bit_idx], tile_lsb[bit_idx]};

    // background color index
    always_comb begin 
        bg_color_idx = {pal_idx, color_idx};
        if(bg_color_idx == 4'h4 || bg_color_idx == 4'h8 || bg_color_idx == 4'hC) 
            bg_color_idx = 4'h0;
    end

endmodule