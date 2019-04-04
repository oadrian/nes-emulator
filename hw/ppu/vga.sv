`default_nettype none
`include "../include/ppu_defines.vh"

//`define CRT_LOOK

module vga (
    input clk,    // Clock
    input clk_en, // Clock Enable
    input rst_n,  // Asynchronous reset active low
    
    // VGA 
    output logic vsync_n,     // vga vsync enable low
    output logic hsync_n,     // vga hsync enable low
    output logic [7:0] vga_r, // vga red 
    output logic [7:0] vga_g, // vga green
    output logic [7:0] vga_b,  // vga blue
	  output logic blank,        // vga blank

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
	 
	 // blanking
	 logic vblank_n, hblank_n;

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
		  hblank_n = 1'b1;
        case (hs_curr_state)
            VGA_HS_VIS_CYC: begin 
                hs_next_state = (col < 10'd255) ? VGA_HS_VIS_CYC : VGA_HS_FP_CYC;
					 hblank_n = 1'b0;
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
		  vblank_n = 1'b1;
        case (vs_curr_state)
            VGA_VS_PRE_SL: begin 
                vs_next_state = (row == 10'd3 && col == 10'd340) ? VGA_VS_VIS_SL : VGA_VS_PRE_SL;
            end

            VGA_VS_VIS_SL: begin 
                vs_next_state = (row == 10'd483 && col == 10'd340) ? VGA_VS_FP_SL : VGA_VS_VIS_SL;
					 vblank_n = 1'b0;
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
	 
	 // set blank
	 assign blank = vblank_n | hblank_n;

    // palette lookup table taken from Brian Benette's vga module"
    // https://github.com/brianbennett/fpga_nes/blob/master/hw/src/ppu/ppu_vga.v
    logic [23:0] rgb;
    
    always_comb begin
        case (vga_buf_out)
          6'h00:   rgb = { 8'd84, 8'd84, 8'd84 };
          6'h01:   rgb = { 8'd0, 8'd30, 8'd116 };
          6'h02:   rgb = { 8'd8, 8'd16, 8'd144 };
          6'h03:   rgb = { 8'd48, 8'd0, 8'd136 };
          6'h04:   rgb = { 8'd68, 8'd0, 8'd100 };
          6'h05:   rgb = { 8'd92, 8'd0, 8'd48 };
          6'h06:   rgb = { 8'd84, 8'd4, 8'd0 };
          6'h07:   rgb = { 8'd60, 8'd24, 8'd0 };
          6'h08:   rgb = { 8'd32, 8'd42, 8'd0 };
          6'h09:   rgb = { 8'd8, 8'd58, 8'd0 };
          6'h0a:   rgb = { 8'd0, 8'd64, 8'd0 };
          6'h0b:   rgb = { 8'd0, 8'd60, 8'd0 };
          6'h0c:   rgb = { 8'd0, 8'd50, 8'd60 };
          6'h0d:   rgb = { 8'd0, 8'd0, 8'd0 };
          6'h0e:   rgb = { 8'd0, 8'd0, 8'd0 };
          6'h0f:   rgb = { 8'd0, 8'd0, 8'd0 };

          6'h10:   rgb = { 8'd152, 8'd150, 8'd152 };
          6'h11:   rgb = { 8'd8, 8'd76, 8'd196 };
          6'h12:   rgb = { 8'd48, 8'd50, 8'd236 };
          6'h13:   rgb = { 8'd92, 8'd30, 8'd228 };
          6'h14:   rgb = { 8'd136, 8'd20, 8'd176 };
          6'h15:   rgb = { 8'd160, 8'd20, 8'd100 };
          6'h16:   rgb = { 8'd152, 8'd34, 8'd32 };
          6'h17:   rgb = { 8'd120, 8'd60, 8'd0 };
          6'h18:   rgb = { 8'd84, 8'd90, 8'd0 };
          6'h19:   rgb = { 8'd40, 8'd114, 8'd0 };
          6'h1a:   rgb = { 8'd8, 8'd124, 8'd0 };
          6'h1b:   rgb = { 8'd0, 8'd118, 8'd40 };
          6'h1c:   rgb = { 8'd0, 8'd102, 8'd120 };
          6'h1d:   rgb = { 8'd0, 8'd0, 8'd0 };
          6'h1e:   rgb = { 8'd0, 8'd0, 8'd0 };
          6'h1f:   rgb = { 8'd0, 8'd0, 8'd0 };

          6'h20:   rgb = { 8'd236, 8'd238, 8'd236 };
          6'h21:   rgb = { 8'd76, 8'd154, 8'd236 };
          6'h22:   rgb = { 8'd120, 8'd124, 8'd236 };
          6'h23:   rgb = { 8'd176, 8'd98, 8'd236 };
          6'h24:   rgb = { 8'd228, 8'd84, 8'd236 };
          6'h25:   rgb = { 8'd236, 8'd88, 8'd180 };
          6'h26:   rgb = { 8'd236, 8'd106, 8'd100 };
          6'h27:   rgb = { 8'd212, 8'd136, 8'd32 };
          6'h28:   rgb = { 8'd160, 8'd170, 8'd0 };
          6'h29:   rgb = { 8'd116, 8'd196, 8'd0 };
          6'h2a:   rgb = { 8'd76, 8'd208, 8'd32 };
          6'h2b:   rgb = { 8'd56, 8'd204, 8'd108 };
          6'h2c:   rgb = { 8'd56, 8'd180, 8'd204 };
          6'h2d:   rgb = { 8'd60, 8'd60, 8'd60 };
          6'h2e:   rgb = { 8'd0, 8'd0, 8'd0 };
          6'h2f:   rgb = { 8'd0, 8'd0, 8'd0 };

          6'h30:   rgb = { 8'd236, 8'd238, 8'd236 };
          6'h31:   rgb = { 8'd168, 8'd204, 8'd236 };
          6'h32:   rgb = { 8'd188, 8'd188, 8'd236 };
          6'h33:   rgb = { 8'd212, 8'd178, 8'd236 };
          6'h34:   rgb = { 8'd236, 8'd174, 8'd236 };
          6'h35:   rgb = { 8'd236, 8'd174, 8'd212 };
          6'h36:   rgb = { 8'd236, 8'd180, 8'd176 };
          6'h37:   rgb = { 8'd228, 8'd196, 8'd144 };
          6'h38:   rgb = { 8'd204, 8'd210, 8'd120 };
          6'h39:   rgb = { 8'd180, 8'd222, 8'd120 };
          6'h3a:   rgb = { 8'd168, 8'd226, 8'd144 };
          6'h3b:   rgb = { 8'd152, 8'd226, 8'd180 };
          6'h3c:   rgb = { 8'd160, 8'd214, 8'd228 };
          6'h3d:   rgb = { 8'd160, 8'd162, 8'd160 };
          6'h3e:   rgb = { 8'd0, 8'd0, 8'd0 };
          6'h3f:   rgb = { 8'd0, 8'd0, 8'd0 };
        endcase
    end

    // index of ppu buffer
    assign vga_buf_idx = col[7:0];

	 `ifdef CRT_LOOK
    assign {vga_r, vga_g, vga_b} = 
        (vs_curr_state == VGA_VS_VIS_SL && 
         hs_curr_state == VGA_HS_VIS_CYC && 
         row[0] == 1'b0) ? 
         rgb : { 8'd0, 8'd0, 8'd0 };
		`else
		assign {vga_r, vga_g, vga_b} = 
        (vs_curr_state == VGA_VS_VIS_SL && 
         hs_curr_state == VGA_HS_VIS_CYC) ? 
         rgb : { 8'd0, 8'd0, 8'd0 };
		`endif

endmodule