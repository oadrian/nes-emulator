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


    // VRAM (SYNC READ)
    logic [10:0] vram_addr1, vram_addr2;
    logic vram_we1, vram_we2;
    logic [7:0] vram_d_in1, vram_d_in2, vram_d_out1, vram_d_out2;

    vram vr(.clk, .clk_en(ppu_clk_en), .rst_n, 
            .addr1(vram_addr1), .addr2(vram_addr2),
            .we1(vram_we1), .we2(vram_we2),  
            .data_in1(vram_d_in1), .data_in2(vram_d_in2), 
            .data_out1(vram_d_out1), .data_out2(vram_d_out2));

    // OAM (SYNC READ)
    logic [5:0] oam_addr;
    logic oam_we;
    logic [7:0] oam_d_in, oam_d_out;

    oam om(.clk, .clk_en(ppu_clk_en), .rst_n, .addr(oam_addr), .we(oam_we), 
            .data_in(oam_d_in), .data_out(oam_d_out));

    // PAL_RAM (SYNC READ)
    logic [4:0] pal_addr;
    logic pal_we;
    logic [7:0] pal_d_in, pal_d_out;

    pal_ram pr(.clk, .clk_en(ppu_clk_en), .rst_n, .addr(pal_addr), .we(pal_we), 
            .data_in(pal_d_in), .data_out(pal_d_out));

    // CHR_ROM (SYNC READ)
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
                ppu_buffer[i] = 8'h00; // black
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
            end 
            if(row == 9'd261) begin
                row <= 0;
            end else if(update_row) begin
                row <= row + 9'd1;
            end

            col <= col + 9'd1;
        end
    end

    // Horizontal states
    hs_state_t hs_curr_state, hs_next_state;

	assign ppu_buffer_wr = (hs_curr_state == SL_PRE_CYC);
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            hs_curr_state <= SL_PRE_CYC;
        end else begin
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
        end else begin
            vs_curr_state <= vs_next_state;
        end
    end

    always_comb begin
        case (vs_curr_state)
            PRE_SL: begin 
                vs_next_state = VIS_SL;
            end

            VIS_SL: begin 
                vs_next_state = (row < 9'd240) ? VIS_SL : POST_SL;
            end

            POST_SL: begin 
                vs_next_state = VBLANK_SL;
            end

            VBLANK_SL: begin 
                vs_next_state = (row < 9'd261) ? VBLANK_SL : PRE_SL;
            end
        endcase
    end

    // background pixel generation
    pattern_tbl_t patt_tbl; // register info
    name_tbl_t name_tbl;    // register info
    logic [7:0] pal_color;

    assign ppu_buf_in = pal_color;

    bg_pixel bg(.clk, .clk_en(ppu_clk_en), .rst_n, .row, .col, 
                .patt_tbl, .name_tbl, 
                .vram_addr1, .vram_data1(vram_d_out1), 
                .vram_addr2, .vram_data2(vram_d_out2),
                .chr_rom_addr1, .chr_rom_addr2, 
                .chr_rom_data1(chr_rom_out1), .chr_rom_data2(chr_rom_out2),
                .pal_addr, .pal_data(pal_d_out),
                .pal_color);

endmodule
