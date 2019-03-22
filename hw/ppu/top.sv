`default_nettype none
`include "ppu_defines.vh"

module top ();
    int f;
    string filename = "my_frame.txt";

    logic clk;
    logic rst_n;
    default clocking cb_main @(posedge clk); endclocking

    logic vblank;
    logic vsync_n;     // vga vsync enable low
    logic hsync_n;     // vga hsync enable low
    logic [7:0] vga_r; // vga red 
    logic [7:0] vga_g; // vga green
    logic [7:0] vga_b; // vga blue
    logic blank;       // vga blank

    ppu dut(.*);

    // Conduct a system reset
    task doReset;

        rst_n = 1'b1;
        rst_n <= 1'b0;

        #1 rst_n <= 1'b1;
    endtask : doReset

    initial begin 
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

   //  initial begin
   //  	##1000000000;
   //  	$finish;
   // end


    initial begin
        doReset;

        f = $fopen(filename, "w");

        while(!(dut.row == 9'd261 && dut.col == 9'd340)) begin 
            if(dut.ppu_clk_en) begin 
                $display("row: %d, col: %d",dut.row, dut.col);
                if(dut.vs_curr_state == VIS_SL && dut.col == 9'd256) begin 
                    for (int i = 0; i < 256; i++) begin
                        $fwrite(f, "%X ", dut.ppu_buffer[i]);
                    end
                    $fwrite(f, "\n");
                end
            end
            @(posedge clk);
        end
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        $finish;

    end

    // Vertical States Assertions
    check_vs_pre: assert property(
        @(posedge clk) dut.vs_curr_state == PRE_SL |-> (dut.row == 0)
    ) else $error("vs_pre failed");

    check_vs_vis: assert property(
        @(posedge clk) dut.vs_curr_state == VIS_SL |-> (1 <= dut.row && dut.row <= 240)
    ) else $error("vs_vis failed");

    check_vs_post: assert property(
        @(posedge clk) dut.vs_curr_state == POST_SL |-> (dut.row == 241)
    ) else $error("vs_post failed");

    check_vs_vblank: assert property(
        @(posedge clk) dut.vs_curr_state == VBLANK_SL |-> (242 <= dut.row && dut.row <= 261)
    ) else $error("vs_vblank failed");



    // Horizontal States Assertions
    check_hs_sl_pre: assert property(
        @(posedge clk) dut.hs_curr_state == SL_PRE_CYC |-> (0 <= dut.col && dut.col <= 255)
    ) else $error("hs_sl_pre failed");

    check_hs_idle: assert property(
        @(posedge clk) dut.hs_curr_state == IDLE_CYC |-> (dut.col == 256)
    ) else $error("hs_idle failed");

    check_hs_sp_pre: assert property(
        @(posedge clk) dut.hs_curr_state == SP_PRE_CYC |-> (257 <= dut.col && dut.col <= 320)
    ) else $error("hs_sp_pre failed");

    check_hs_tl_pre: assert property(
        @(posedge clk) dut.hs_curr_state == TL_PRE_CYC |-> (321 <= dut.col && dut.col <= 336)
    ) else $error("hs_tl_pre failed");

    check_hs_garb: assert property(
        @(posedge clk) dut.hs_curr_state == GARB_CYC |-> (337 <= dut.col && dut.col <= 340)
    ) else $error("hs_garb failed");


endmodule