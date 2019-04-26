`default_nettype none
`include "../include/ppu_defines.vh"

module ppu (
    input clk,    // Master Clock
    input rst_n,  // Asynchronous reset active low
    input logic ppu_clk_en,   // 

    // NMI VBlank
    output logic vblank_nmi, // NMI signal to cpu

    // VGA 
    output logic vsync_n,     // vga vsync enable low
    output logic hsync_n,     // vga hsync enable low
    output logic [7:0] vga_r, // vga red 
    output logic [7:0] vga_g, // vga green
    output logic [7:0] vga_b,  // vga blue
    output logic blank,

    // CPU Read/Write BUS
    input logic cpu_clk_en,    // use to update register interface
    input reg_t reg_sel,       // register to write to
    input logic reg_en,        // 1 - write to register, 0 - do nothing
    input logic reg_rw,        // 1 - write mode, 0 - read mode
    input logic [7:0] reg_data_in,  // data to write
    output logic [7:0] reg_data_out, // data read

    // CPU cycle parity
    input logic cpu_cyc_par,  // used for exact DMA timing

    // CPU suspend
    output logic cpu_sus,     // suspend CPU when performing OAMDMA

    // CPU MEM READ (SYNC)
    output logic [15:0] cpu_addr,
    output logic cpu_re,
    input logic [7:0] cpu_rd_data, 

    // debug
    output logic [7:0] ppuctrl, ppumask,

    // mirroring
    input mirror_t mirroring
);

    //////////// VGA clk   /////////////
    logic vga_clk_en;  // Master / 2
    clock_div #(2) v_ck(.clk, .rst_n, .clk_en(vga_clk_en));


    //////////// VRAM (ASYNC READ)   /////////////
    logic [10:0] vram_addr1, vram_addr2;
    logic vram_we1, vram_we2;
    logic [7:0] vram_d_in1, vram_d_in2, vram_d_out1, vram_d_out2;

    assign vram_we2 = 1'b0;
    assign vram_d_in2 = 8'd0;

    vram vr(.clk, .clk_en(ppu_clk_en), .rst_n, 
            .addr1(vram_addr1), .addr2(vram_addr2),
            .we1(vram_we1), .we2(vram_we2),  
            .data_in1(vram_d_in1), .data_in2(vram_d_in2), 
            .data_out1(vram_d_out1), .data_out2(vram_d_out2));

    //////////// OAM (ASYNC READ)   /////////////
    logic [7:0] oam_addr;
    logic oam_we;
    logic [7:0] oam_d_in, oam_d_out;

    oam om(.clk, .clk_en(ppu_clk_en), .rst_n, .addr(oam_addr), .we(oam_we), 
            .data_in(oam_d_in), .data_out(oam_d_out));

    //////////// PAL_RAM (ASYNC READ)   /////////////
    logic [4:0] pal_addr;
    logic pal_we;
    logic [7:0] pal_d_in, pal_d_out;

    pal_ram pr(.clk, .clk_en(ppu_clk_en), .rst_n, .addr(pal_addr), .we(pal_we), 
            .data_in(pal_d_in), .data_out(pal_d_out));

    //////////// CHR_ROM (ASYNC READ)   /////////////
    logic [12:0] chr_rom_addr1, chr_rom_addr2;
    logic [7:0] chr_rom_out1, chr_rom_out2;

    chr_rom cr(.clk, .clk_en(ppu_clk_en), .rst_n,
               .addr1(chr_rom_addr1), .addr2(chr_rom_addr2),
               .data_out1(chr_rom_out1), .data_out2(chr_rom_out2));

    //////////// CPU Register Interface   /////////////
    logic sp_over_set, sp_over_clr;
    logic sp_zero_set, sp_zero_clr;
    logic vblank_set, vblank_clr;

    // OAM  (Async read)
    logic [7:0] oam_addr_ri; 
    logic oam_we_ri, oam_re_ri;
    logic [7:0] oam_wr_data_ri, oam_rd_data_ri;

    assign oam_we = oam_we_ri;
    assign oam_d_in = oam_wr_data_ri;
    assign oam_rd_data_ri = oam_d_out;

    // VRAM (Async read)
    logic [10:0] vram_addr_ri;
    logic vram_we_ri, vram_re_ri;
    logic [7:0] vram_wr_data_ri, vram_rd_data_ri;

    assign vram_we1 = vram_we_ri;
    assign vram_d_in1 = vram_wr_data_ri;
    assign vram_rd_data_ri = vram_d_out1;

    // PAL RAM (ASYNC)
    logic [4:0] pal_addr_ri;
    logic pal_we_ri, pal_re_ri;
    logic [7:0] pal_wr_data_ri, pal_rd_data_ri;

    assign pal_we = pal_we_ri;
    assign pal_d_in = pal_wr_data_ri;
    assign pal_rd_data_ri = pal_d_out;

    // register interface
    addr_t vAddr;
    logic [2:0] fX;
    logic h_scroll, v_scroll, h_update, v_update;
    logic rendering;

    // show background or sprites
    assign rendering = ppumask[3] | ppumask[4];
    reg_inter ri(.clk, .cpu_clk_en, .ppu_clk_en, .rst_n,
                 .reg_sel, .reg_en, .reg_rw, .reg_data_in, .reg_data_out,
                 .cpu_cyc_par, .cpu_sus,
                 .sp_over_set, .sp_over_clr, .sp_zero_set, .sp_zero_clr, .vblank_set, .vblank_clr,
                 
                 .oam_addr(oam_addr_ri), .oam_we(oam_we_ri), .oam_re(oam_re_ri),
                 .oam_wr_data(oam_wr_data_ri), .oam_rd_data (oam_rd_data_ri),

                 .vram_addr(vram_addr_ri), .vram_we(vram_we_ri), .vram_re(vram_re_ri),
                 .vram_wr_data(vram_wr_data_ri), .vram_rd_data(vram_rd_data_ri),

                 .mirroring,

                 .pal_addr(pal_addr_ri), .pal_we(pal_we_ri), .pal_re(pal_re_ri),
                 .pal_wr_data(pal_wr_data_ri), .pal_rd_data(pal_rd_data_ri),

                 .cpu_addr, .cpu_re, .cpu_rd_data, 

                 .ppuctrl_out(ppuctrl), .ppumask_out(ppumask), 
                 
                 .vAddr, .fX,
                 .h_scroll, .v_scroll, .h_update, .v_update,
                 .rendering);

    //////////// row, col logic   /////////////

    logic [8:0] row, col;

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
            end else if(col == 9'd340) begin
                row <= row + 9'd1;
            end 
        end
    end

    //////////// Horizontal states   /////////////
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



    //////////// Vertical states   /////////////
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

    // clear the ppustatus bits on the 1-st (second) dot of pre render scanline
    assign sp_over_clr = (vs_curr_state == PRE_SL && col == 9'd0);
    assign sp_zero_clr = (vs_curr_state == PRE_SL && col == 9'd0);
    assign vblank_clr =  (vs_curr_state == PRE_SL && col == 9'd0);

    // set the blank bit in ppustatus at dot 1 of the post render scanline
    assign vblank_set = (vs_curr_state == POST_SL && col == 9'd0);

    // produce nmi
    assign vblank_nmi = !(vs_curr_state == POST_SL && col < 9'd3 && ppuctrl[7]);


    //////////// Scanline buffer   /////////////

    logic [5:0] ppu_buffer[`SCREEN_WIDTH-1:0]; // 256 color indexes
    logic ppu_buffer_wr;
    logic [7:0] ppu_buf_idx;
    logic [7:0] ppu_buf_in;

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            ppu_buf_idx <= 0;
            for(int i = 0; i<`SCREEN_WIDTH; i++) begin 
                ppu_buffer[i] <= 6'h00; // black
            end
        end else if(ppu_clk_en && ppu_buffer_wr) begin
            ppu_buffer[ppu_buf_idx] <= ppu_buf_in[5:0];
            ppu_buf_idx <= ppu_buf_idx + 8'd1;
        end
    end

    //////////// write to PPU's scanline buffer    /////////////
    assign ppu_buffer_wr = (hs_curr_state == SL_PRE_CYC && vs_curr_state == VIS_SL);


    //////////// VGA's scanline buffer   /////////////

    logic [5:0] vga_buffer[`SCREEN_WIDTH-1:0]; // 256 color indeces
    logic vga_buffer_mv;
    logic [7:0] vga_buf_idx;
    logic [5:0] vga_buf_out;

    assign vga_buf_out = vga_buffer[vga_buf_idx];

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            for (int i = 0; i < `SCREEN_WIDTH; i++) begin
                vga_buffer[i] <= 6'h00;
            end
        end else if(ppu_clk_en && vga_buffer_mv) begin
            for (int i = 0; i < `SCREEN_WIDTH; i++) begin
                vga_buffer[i] <= ppu_buffer[i];
            end
        end
    end

    // transfer ppu_buffer to vga_buffer on last tick of current scanline to 
    // be displayed throughout the next scanline
    assign vga_buffer_mv = (col == 9'd340);

    //////////// VGA module  ////////////

    vga v(.clk, .clk_en(vga_clk_en), .rst_n, 
          .vsync_n, .hsync_n, .vga_r, .vga_g, .vga_b, .blank,
          .vga_buf_idx, .vga_buf_out);

    /////////////////////   BACKGROUND  //////////////////////////
    // background pixel generation
    logic [12:0] bg_chr_rom_addr1, bg_chr_rom_addr2;
    pattern_tbl_t bg_patt_tbl; // register info
    name_tbl_t bg_name_tbl;    // register info
    logic [3:0] bg_color_idx, bg_color_idx_t, bg_color_idx_en;

    assign bg_patt_tbl = (ppuctrl[4]) ? RIGHT_TBL : LEFT_TBL;

    always_comb begin
        bg_name_tbl = TOP_L_TBL;        
        case (ppuctrl[1:0])
            2'b00: 
                bg_name_tbl = TOP_L_TBL;
            2'b01:  
                bg_name_tbl = TOP_R_TBL;
            2'b10: 
                bg_name_tbl = BOT_L_TBL;
            2'b11: 
                bg_name_tbl = BOT_R_TBL;
            default : /* default */;
        endcase
    
    end

    // first row is garbage, used for prefetching sprites for first visible sl
    logic [10:0] vram_addr1_bg, vram_addr2_bg;
    bg_pixel bg(.clk, .clk_en(ppu_clk_en), .rst_n,
                .sl_row(row-9'd1), .sl_col(col), 
                .patt_tbl(bg_patt_tbl), 
                .vram_addr1(vram_addr1_bg), .vram_data1(vram_d_out1), 
                .vram_addr2(vram_addr2_bg), .vram_data2(vram_d_out2),
                .mirroring, 
                .chr_rom_addr1(bg_chr_rom_addr1), .chr_rom_addr2(bg_chr_rom_addr2), 
                .chr_rom_data1(chr_rom_out1), .chr_rom_data2(chr_rom_out2),
                .bg_color_idx(bg_color_idx_t),
                .vAddr, .fX,
                .h_scroll, .v_scroll, .h_update, .v_update);

    // ppumask control bits
    assign bg_color_idx_en = (ppumask[3]) ? bg_color_idx_t : 4'b0000;
    assign bg_color_idx = (!ppumask[1] && col < 9'd8) ? 4'b0000 : bg_color_idx_en;

    // share address bus with register interface
    assign vram_addr1 = (vram_we_ri || vram_re_ri) ? vram_addr_ri : vram_addr1_bg;
    assign vram_addr2 = vram_addr2_bg;

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

    assign sp_over_set = (temp_oam_cnt == 4'd8 && temp_oam_wr);

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
    logic [7:0] oam_addr_spe;

    assign sp_patt_tbl = (ppuctrl[3]) ? RIGHT_TBL : LEFT_TBL; 

    sp_eval spe(.clk, .clk_en(ppu_clk_en), .rst_n,
                .row(row-9'd1), .col, 
                .hs_state(hs_curr_state), .patt_tbl(sp_patt_tbl),
                .oam_addr(oam_addr_spe), .oam_data(oam_d_out),
                
                .temp_oam_clr, .temp_oam_wr, .temp_oam_wr_data(temp_oam_in),
                .temp_oam_rd_idx, .temp_oam_rd_data(temp_oam_out), 
                
                .sec_oam_clr, .sec_oam_wr, .sec_oam_wr_data(sec_oam_in),

                .chr_rom_addr1(sp_chr_rom_addr1), .chr_rom_addr2(sp_chr_rom_addr2), 
                .chr_rom_data1(chr_rom_out1), .chr_rom_data2(chr_rom_out2),
                .chr_rom_re(sp_chr_rom_re));

    // background and sprite rendering share address lines for tile data
    assign chr_rom_addr1 = (sp_chr_rom_re) ? sp_chr_rom_addr1 : bg_chr_rom_addr1;
    assign chr_rom_addr2 = (sp_chr_rom_re) ? sp_chr_rom_addr2 : bg_chr_rom_addr2;

    // share the OAM addr bus
    assign oam_addr = (oam_we_ri || oam_re_ri) ? oam_addr_ri : oam_addr_spe;


    // sprite pixel generation
    logic [3:0] sp_color_idx, sp_color_idx_t, sp_color_idx_en;
    logic sp_prio, sp_zero;

    sp_pixel spp(.row(row-9'd1), .col,  
                .sec_oam, 
                .sp_color_idx(sp_color_idx_t), .sp_prio, .sp_zero);

    // ppumask control bits
    assign sp_color_idx_en = (ppumask[4]) ? sp_color_idx_t : 4'b0000;
    assign sp_color_idx = (!ppumask[2] && col < 9'd8) ? 4'b0000 : sp_color_idx_en;

    /////////////////////   FINAL PIXEL  //////////////////////////

    // Sprite - zero hit
    assign sp_zero_set = (vs_curr_state == VIS_SL && col < 9'd255 && 
                          sp_zero && bg_color_idx[1:0] != 2'd0 && sp_color_idx[1:0] != 2'd0);

    // merge Background and Sprites using priority
    logic [4:0] pal_addr_merger;    
    always_comb begin
        pal_addr_merger = 5'd0;
        if(bg_color_idx[1:0] == 2'd0 && sp_color_idx[1:0] == 2'd0) begin 
            pal_addr_merger = {1'b0, bg_color_idx};
        end else if(bg_color_idx[1:0] == 2'd0 && sp_color_idx[1:0] != 2'd0) begin 
            pal_addr_merger = {1'b1, sp_color_idx};
        end else if(bg_color_idx[1:0] != 2'd0 && sp_color_idx[1:0] == 2'd0) begin 
            pal_addr_merger = {1'b0, bg_color_idx};
        end else if(bg_color_idx[1:0] != 2'd0 && sp_color_idx[1:0] != 2'd0 && sp_prio == 1'b0) begin 
            pal_addr_merger = {1'b1, sp_color_idx};
        end else if(bg_color_idx[1:0] != 2'd0 && sp_color_idx[1:0] != 2'd0 && sp_prio == 1'b1) begin 
            pal_addr_merger = {1'b0, bg_color_idx};
        end
    end

    // share addr line for pal memory
    assign pal_addr = (pal_we_ri || pal_re_ri) ? pal_addr_ri : pal_addr_merger;

    // greyscale
    assign ppu_buf_in = (ppumask[0]) ? pal_d_out & 8'h30 : pal_d_out;


endmodule
