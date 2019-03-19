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
    clock_div #(2) v_ck(.clk, .rst_n, .clk_en(vga_clk_en));

    // internal PPU clock
    logic ppu_clk_en;  // Master / 4
    clock_div #(4) p_ck(.clk, .rst_n, .clk_en(ppu_clk_en));


    // VRAM (ASYNC READ)
    logic [10:0] vram_addr1, vram_addr2;
    logic vram_we1, vram_we2;
    logic [7:0] vram_d_in1, vram_d_in2, vram_d_out1, vram_d_out2;

    vram vr(.clk, .clk_en(ppu_clk_en), .rst_n, 
            .addr1(vram_addr1), .addr2(vram_addr2),
            .we1(vram_we1), .we2(vram_we2),  
            .data_in1(vram_d_in1), .data_in2(vram_d_in2), 
            .data_out1(vram_d_out1), .data_out2(vram_d_out2));

    // OAM (ASYNC READ)
    logic [7:0] oam_addr;
    logic oam_we;
    logic [7:0] oam_d_in, oam_d_out;

    oam om(.clk, .clk_en(ppu_clk_en), .rst_n, .addr(oam_addr), .we(oam_we), 
            .data_in(oam_d_in), .data_out(oam_d_out));

    // PAL_RAM (ASYNC READ)
    logic [4:0] pal_addr;
    logic pal_we;
    logic [7:0] pal_d_in, pal_d_out;

    pal_ram pr(.clk, .clk_en(ppu_clk_en), .rst_n, .addr(pal_addr), .we(pal_we), 
            .data_in(pal_d_in), .data_out(pal_d_out));

    // CHR_ROM (ASYNC READ)
    logic [12:0] chr_rom_addr1, chr_rom_addr2;
    logic [7:0] chr_rom_out1, chr_rom_out2;

    chr_rom cr(.clk, .clk_en(ppu_clk_en), .rst_n,
               .addr1(chr_rom_addr1), .addr2(chr_rom_addr2),
               .data_out1(chr_rom_out1), .data_out2(chr_rom_out2));


    // Scanline buffer

    logic [5:0] ppu_buffer[`SCREEN_WIDTH-1:0]; // 256 color indexes
    logic ppu_buffer_wr;
    logic [7:0] ppu_buf_idx;
    logic [7:0] ppu_buf_in;

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            ppu_buf_idx <= 0;
            for(int i = 0; i<`SCREEN_WIDTH; i++) begin 
                ppu_buffer[i] <= 'h00; // black
            end
        end else if(ppu_clk_en && ppu_buffer_wr) begin
            ppu_buffer[ppu_buf_idx] <= ppu_buf_in;
            ppu_buf_idx <= ppu_buf_idx + 1;
        end
    end




    // row, col logic

    logic [8:0] row, col;
    logic update_row;

    assign update_row = (col == 9'd340);

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            row <= 0;
            col <= 0;
        end else if(ppu_clk_en) begin
            if(col == 9'd340) begin
                col <= 0;
            end else begin
                col <= col + 9'd1;
            end 

            if(row == 9'd261 && col == 9'd340) begin
                row <= 0;
            end else if(update_row) begin
                row <= row + 9'd1;
            end 
        end
    end

    // Horizontal states
    hs_state_t hs_curr_state, hs_next_state;

    
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            hs_curr_state <= SL_PRE_CYC;
        end else if(ppu_clk_en) begin
            hs_curr_state <= hs_next_state;
        end
    end


    always_comb begin 
        case (hs_curr_state)
            SL_PRE_CYC: begin 
                hs_next_state = (col < 9'd255) ? SL_PRE_CYC : IDLE_CYC;
            end 

            IDLE_CYC: begin 
                hs_next_state = SP_PRE_CYC;
            end 

            SP_PRE_CYC: begin 
                hs_next_state = (col < 9'd320) ? SP_PRE_CYC : TL_PRE_CYC;
            end 

            TL_PRE_CYC: begin 
                hs_next_state = (col < 9'd336) ? TL_PRE_CYC : GARB_CYC;
            end 

            GARB_CYC: begin 
                hs_next_state = (col < 9'd340) ? GARB_CYC : SL_PRE_CYC;
            end    
        endcase
    
    end



    // Vertical states
    vs_state_t vs_curr_state, vs_next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            vs_curr_state <= PRE_SL;
        end else if(ppu_clk_en) begin
            vs_curr_state <= vs_next_state;
        end
    end

    always_comb begin
        case (vs_curr_state)
            PRE_SL: begin 
                vs_next_state = (row == 9'd0 && col == 9'd340) ? VIS_SL : PRE_SL;
            end

            VIS_SL: begin 
                vs_next_state = (row == 9'd240 && col == 9'd340) ? POST_SL : VIS_SL;
            end

            POST_SL: begin 
                vs_next_state = (row == 9'd241 && col == 9'd340) ? VBLANK_SL : POST_SL;
            end

            VBLANK_SL: begin 
                vs_next_state = (row == 9'd261 && col == 9'd340) ? PRE_SL : VBLANK_SL;
            end
        endcase
    end

    // write to ppu buffer
    assign ppu_buffer_wr = (hs_curr_state == SL_PRE_CYC && vs_curr_state == VIS_SL);


    /////////////////////   BACKGROUND  //////////////////////////
    // background pixel generation
    logic [12:0] bg_chr_rom_addr1, bg_chr_rom_addr2;
    pattern_tbl_t bg_patt_tbl; // register info
    name_tbl_t bg_name_tbl;    // register info
    logic [3:0] bg_color_idx;

    assign bg_patt_tbl = RIGHT_TBL;
    assign bg_name_tbl = TOP_L_TBL;

    // first row is garbage, used for prefetching sprites for first visible sl
    bg_pixel bg(.row(row-9'd1), .col, 
                .patt_tbl(bg_patt_tbl), .name_tbl(bg_name_tbl), 
                .vram_addr1, .vram_data1(vram_d_out1), 
                .vram_addr2, .vram_data2(vram_d_out2),
                .chr_rom_addr1(bg_chr_rom_addr1), .chr_rom_addr2(bg_chr_rom_addr2), 
                .chr_rom_data1(chr_rom_out1), .chr_rom_data2(chr_rom_out2),
                .bg_color_idx);


    /////////////////////   SPRITE  //////////////////////////
    // Tempory OAM for Sprite eval
    second_oam_t temp_oam [`SEC_OAM_SIZE-1:0];
    logic temp_oam_wr, temp_oam_clr;
    logic [2:0] temp_oam_wr_idx, temp_oam_rd_idx;
    logic [3:0] temp_oam_cnt;
    second_oam_t temp_oam_in, temp_oam_out;

    assign temp_oam_out = temp_oam[temp_oam_rd_idx];

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            temp_oam_wr_idx <= 3'd0;
            temp_oam_cnt <= 4'd0;
            for (int i = 0; i < `SEC_OAM_SIZE; i++) begin
                temp_oam[i] <= 'h0;
            end
        end else if(ppu_clk_en && temp_oam_clr) begin 
            temp_oam_wr_idx <= 3'd0;
            temp_oam_cnt <= 4'd0;
            for (int i = 0; i < `SEC_OAM_SIZE; i++) begin
                temp_oam[i] <= 'h0;
            end
        end else if(ppu_clk_en && temp_oam_wr && temp_oam_cnt < 4'd8) begin
            temp_oam[temp_oam_wr_idx] <= temp_oam_in;
            temp_oam_wr_idx <= temp_oam_wr_idx + 3'd1;
            temp_oam_cnt <= temp_oam_cnt + 4'd1;
        end
    end

    // Secondary OAM for Sprite Rendering
    second_oam_t sec_oam [`SEC_OAM_SIZE-1:0];
    logic sec_oam_wr, sec_oam_clr;
    logic [2:0] sec_oam_wr_idx;
    logic [3:0] sec_oam_cnt;
    second_oam_t sec_oam_in;

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            sec_oam_wr_idx <= 3'd0;
            sec_oam_cnt <= 4'd0;
            for (int i = 0; i < `SEC_OAM_SIZE; i++) begin
                sec_oam[i] <= 'h0;
            end
        end else if(ppu_clk_en && sec_oam_clr) begin 
            sec_oam_wr_idx <= 3'd0;
            sec_oam_cnt <= 4'd0;
            for (int i = 0; i < `SEC_OAM_SIZE; i++) begin
                sec_oam[i] <= 'h0;
            end
        end else if(ppu_clk_en && sec_oam_wr && sec_oam_cnt < 4'd8) begin
            sec_oam[sec_oam_wr_idx] <= sec_oam_in;
            sec_oam_wr_idx <= sec_oam_wr_idx + 3'd1;
            sec_oam_cnt <= sec_oam_cnt + 4'd1;
        end
    end

    // sprite evaluation
    pattern_tbl_t sp_patt_tbl; // register info
    logic [12:0] sp_chr_rom_addr1, sp_chr_rom_addr2;
    logic sp_chr_rom_re;

    assign sp_patt_tbl = LEFT_TBL; 

    sp_eval spe(.clk, .clk_en(ppu_clk_en), .rst_n,
                .row(row-9'd1), .col, 
                .hs_state(hs_curr_state), .patt_tbl(sp_patt_tbl),
                .oam_addr(oam_addr), .oam_data(oam_d_out),
                
                .temp_oam_clr, .temp_oam_wr, .temp_oam_wr_data(temp_oam_in),
                .temp_oam_rd_idx, .temp_oam_rd_data(temp_oam_out), 
                
                .sec_oam_clr, .sec_oam_wr, .sec_oam_wr_data(sec_oam_in),

                .chr_rom_addr1(sp_chr_rom_addr1), .chr_rom_addr2(sp_chr_rom_addr2), 
                .chr_rom_data1(chr_rom_out1), .chr_rom_data2(chr_rom_out2),
                .chr_rom_re(sp_chr_rom_re));

    assign chr_rom_addr1 = (sp_chr_rom_re) ? sp_chr_rom_addr1 : bg_chr_rom_addr1;
    assign chr_rom_addr2 = (sp_chr_rom_re) ? sp_chr_rom_addr2 : bg_chr_rom_addr2;


    // sprite pixel generation
    logic [3:0] sp_color_idx;
    logic sp_prio;

    sp_pixel spp(.row(row-9'd1), .col,  
                .sec_oam, 
                .sp_color_idx, .sp_prio);


    /////////////////////   FINAL PIXEL  //////////////////////////
    // merge Background and Sprites using priority

    always_comb begin
        pal_addr = 5'd0;
        if(bg_color_idx == 4'd0 && sp_color_idx == 4'd0) begin 
            pal_addr = {1'b0, bg_color_idx};
        end else if(bg_color_idx == 4'd0 && sp_color_idx != 4'd0) begin 
            pal_addr = {1'b1, sp_color_idx};
        end else if(bg_color_idx != 4'd0 && sp_color_idx == 4'd0) begin 
            pal_addr = {1'b0, bg_color_idx};
        end else if(bg_color_idx != 4'd0 && sp_color_idx != 4'd0 && sp_prio == 1'b0) begin 
            pal_addr = {1'b1, sp_color_idx};
        end else if(bg_color_idx != 4'd0 && sp_color_idx != 4'd0 && sp_prio == 1'b1) begin 
            pal_addr = {1'b0, bg_color_idx};
        end    
    end

    assign ppu_buf_in = pal_d_out;


endmodule
