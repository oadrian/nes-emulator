`default_nettype none
`include "ppu_defines.vh"

module vga (
    input clk,    // Clock
    input clk_en, // Clock Enable
    input rst_n,  // Asynchronous reset active low
    
    // VGA 
    output logic vsync_n,     // vga vsync enable low
    output logic hsync_n,     // vga hsync enable low
    output logic [2:0] vga_r, // vga red 
    output logic [2:0] vga_g, // vga green
    output logic [1:0] vga_b,  // vga blue

    // Scanline Buffer
    output logic [7:0] vga_buf_idx,
    input logic [5:0] vga_buf_out
);
    // row, col logic

    logic [9:0] row, col;

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            row <= 0;
            col <= 0;
        end else if(clk_en) begin
            if(col == 10'd340) begin
                col <= 0;
            end else begin
                col <= col + 10'd1;
            end 

            if(row == 10'd523 && col == 10'd340) begin
                row <= 0;
            end else if(col == 10'd340) begin
                row <= row + 10'd1;
            end 
        end
    end

    // Horizontal states
    vga_hs_states_t hs_curr_state, hs_next_state;

    
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            hs_curr_state <= VGA_HS_VIS_CYC;
        end else if(clk_en) begin
            hs_curr_state <= hs_next_state;
        end
    end


    always_comb begin 
        hsync_n = 1'b1;
        case (hs_curr_state)
            VGA_HS_VIS_CYC: begin 
                hs_next_state = (col < 10'd255) ? VGA_HS_VIS_CYC : VGA_HS_FP_CYC;
            end 

            VGA_HS_FP_CYC: begin 
                hs_next_state = (col < 10'd262) ? VGA_HS_FP_CYC : VGA_HS_PULSE_CYC;
            end 

            VGA_HS_PULSE_CYC: begin 
                hs_next_state = (col < 10'd303) ? VGA_HS_PULSE_CYC : VGA_HS_BP_CYC;
                hsync_n = 1'b0;
            end 

            VGA_HS_BP_CYC: begin 
                hs_next_state = (col < 10'd323) ? VGA_HS_BP_CYC : VGA_HS_IDLE_CYC;
            end 

            VGA_HS_IDLE_CYC: begin 
                hs_next_state = (col < 10'd340) ? VGA_HS_IDLE_CYC : VGA_HS_VIS_CYC;
            end    
        endcase
    
    end



    // Vertical states
    vga_vs_states_t vs_curr_state, vs_next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            vs_curr_state <= VGA_VS_PRE_SL;
        end else if(clk_en) begin
            vs_curr_state <= vs_next_state;
        end
    end

    always_comb begin
        vsync_n = 1'b1;
        case (vs_curr_state)
            VGA_VS_PRE_SL: begin 
                vs_next_state = (row == 10'd3 && col == 10'd340) ? VGA_VS_VIS_SL : VGA_VS_PRE_SL;
            end

            VGA_VS_VIS_SL: begin 
                vs_next_state = (row == 10'd483 && col == 10'd340) ? VGA_VS_FP_SL : VGA_VS_VIS_SL;
            end

            VGA_VS_FP_SL: begin 
                vs_next_state = (row == 10'd493 && col == 10'd340) ? VGA_VS_PULSE_SL : VGA_VS_FP_SL;
            end

            VGA_VS_PULSE_SL: begin 
                vs_next_state = (row == 10'd495 && col == 10'd340) ? VGA_VS_BP_SL : VGA_VS_PULSE_SL;
                vsync_n = 1'b0;
            end

            VGA_VS_BP_SL: begin 
                vs_next_state = (row == 10'd523 && col == 10'd340) ? VGA_VS_PRE_SL :  VGA_VS_BP_SL;
            end
        endcase
    end


    // vertical states

    // palette lookup table taken from Brian Benette's vga module"
    // https://github.com/brianbennett/fpga_nes/blob/master/hw/src/ppu/ppu_vga.v
    logic [7:0] rgb;
    
    always_comb begin
        case (vga_buf_out)
          6'h00:  rgb = { 3'h3, 3'h3, 2'h1 };
          6'h01:  rgb = { 3'h1, 3'h0, 2'h2 };
          6'h02:  rgb = { 3'h0, 3'h0, 2'h2 };
          6'h03:  rgb = { 3'h2, 3'h0, 2'h2 };
          6'h04:  rgb = { 3'h4, 3'h0, 2'h1 };
          6'h05:  rgb = { 3'h5, 3'h0, 2'h0 };
          6'h06:  rgb = { 3'h5, 3'h0, 2'h0 };
          6'h07:  rgb = { 3'h3, 3'h0, 2'h0 };
          6'h08:  rgb = { 3'h2, 3'h1, 2'h0 };
          6'h09:  rgb = { 3'h0, 3'h2, 2'h0 };
          6'h0a:  rgb = { 3'h0, 3'h2, 2'h0 };
          6'h0b:  rgb = { 3'h0, 3'h1, 2'h0 };
          6'h0c:  rgb = { 3'h0, 3'h1, 2'h1 };
          6'h0d:  rgb = { 3'h0, 3'h0, 2'h0 };
          6'h0e:  rgb = { 3'h0, 3'h0, 2'h0 };
          6'h0f:  rgb = { 3'h0, 3'h0, 2'h0 };

          6'h10:  rgb = { 3'h5, 3'h5, 2'h2 };
          6'h11:  rgb = { 3'h0, 3'h3, 2'h3 };
          6'h12:  rgb = { 3'h1, 3'h1, 2'h3 };
          6'h13:  rgb = { 3'h4, 3'h0, 2'h3 };
          6'h14:  rgb = { 3'h5, 3'h0, 2'h2 };
          6'h15:  rgb = { 3'h7, 3'h0, 2'h1 };
          6'h16:  rgb = { 3'h6, 3'h1, 2'h0 };
          6'h17:  rgb = { 3'h6, 3'h2, 2'h0 };
          6'h18:  rgb = { 3'h4, 3'h3, 2'h0 };
          6'h19:  rgb = { 3'h0, 3'h4, 2'h0 };
          6'h1a:  rgb = { 3'h0, 3'h5, 2'h0 };
          6'h1b:  rgb = { 3'h0, 3'h4, 2'h0 };
          6'h1c:  rgb = { 3'h0, 3'h4, 2'h2 };
          6'h1d:  rgb = { 3'h0, 3'h0, 2'h0 };
          6'h1e:  rgb = { 3'h0, 3'h0, 2'h0 };
          6'h1f:  rgb = { 3'h0, 3'h0, 2'h0 };

          6'h20:  rgb = { 3'h7, 3'h7, 2'h3 };
          6'h21:  rgb = { 3'h1, 3'h5, 2'h3 };
          6'h22:  rgb = { 3'h2, 3'h4, 2'h3 };
          6'h23:  rgb = { 3'h5, 3'h4, 2'h3 };
          6'h24:  rgb = { 3'h7, 3'h3, 2'h3 };
          6'h25:  rgb = { 3'h7, 3'h3, 2'h2 };
          6'h26:  rgb = { 3'h7, 3'h3, 2'h1 };
          6'h27:  rgb = { 3'h7, 3'h4, 2'h0 };
          6'h28:  rgb = { 3'h7, 3'h5, 2'h0 };
          6'h29:  rgb = { 3'h4, 3'h6, 2'h0 };
          6'h2a:  rgb = { 3'h2, 3'h6, 2'h1 };
          6'h2b:  rgb = { 3'h2, 3'h7, 2'h2 };
          6'h2c:  rgb = { 3'h0, 3'h7, 2'h3 };
          6'h2d:  rgb = { 3'h0, 3'h0, 2'h0 };
          6'h2e:  rgb = { 3'h0, 3'h0, 2'h0 };
          6'h2f:  rgb = { 3'h0, 3'h0, 2'h0 };

          6'h30:  rgb = { 3'h7, 3'h7, 2'h3 };
          6'h31:  rgb = { 3'h5, 3'h7, 2'h3 };
          6'h32:  rgb = { 3'h6, 3'h6, 2'h3 };
          6'h33:  rgb = { 3'h6, 3'h6, 2'h3 };
          6'h34:  rgb = { 3'h7, 3'h6, 2'h3 };
          6'h35:  rgb = { 3'h7, 3'h6, 2'h3 };
          6'h36:  rgb = { 3'h7, 3'h5, 2'h2 };
          6'h37:  rgb = { 3'h7, 3'h6, 2'h2 };
          6'h38:  rgb = { 3'h7, 3'h7, 2'h2 };
          6'h39:  rgb = { 3'h7, 3'h7, 2'h2 };
          6'h3a:  rgb = { 3'h5, 3'h7, 2'h2 };
          6'h3b:  rgb = { 3'h5, 3'h7, 2'h3 };
          6'h3c:  rgb = { 3'h4, 3'h7, 2'h3 };
          6'h3d:  rgb = { 3'h0, 3'h0, 2'h0 };
          6'h3e:  rgb = { 3'h0, 3'h0, 2'h0 };
          6'h3f:  rgb = { 3'h0, 3'h0, 2'h0 };
        endcase
    end

    // index of ppu buffer
    assign vga_buf_idx = col[7:0];

    assign {vga_r, vga_g, vga_b} = 
        (vs_curr_state == VGA_VS_VIS_SL && 
         hs_curr_state == VGA_HS_VIS_CYC && 
         row[0] == 1'b0) ? // CRT LOOK ENABLED
         rgb : { 3'h0, 3'h0, 2'h0 };




endmodule