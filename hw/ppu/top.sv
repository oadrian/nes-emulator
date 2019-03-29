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

    logic cpu_clk_en;    // use to update register interface  Master / 12
    reg_t reg_sel;       // register to write to
    logic reg_en;        // 1 - write to register, 0 - do nothing
    logic reg_rw;        // 1 - write mode, 0 - read mode
    logic [7:0] reg_data_in;  // data to write
    logic [7:0] reg_data_out; // data read

    logic cpu_cyc_par;  // used for exact DMA timing
    logic cpu_sus;      // suspend CPU when performing OAMDMA

    logic [15:0] cpu_addr;
    logic cpu_re;
    logic [7:0] cpu_rd_data;

    // CPU clock enable
    clock_div #(12) p_ck(.clk, .rst_n, .clk_en(cpu_clk_en));

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

   task frameTest();
        f = $fopen(filename, "w");
        reg_sel = PPUCTRL;
        reg_en = 1'b0;
        reg_rw = 1'b1;
        reg_data_in = 8'b00000000;
        @(posedge cpu_clk_en);
        reg_sel = PPUCTRL;
        reg_en = 1'b1;
        reg_rw = 1'b1;
        reg_data_in = 8'b10010000;
        @(posedge cpu_clk_en);
        reg_sel = PPUMASK;
        reg_en = 1'b1;
        reg_rw = 1'b1;
        reg_data_in = 8'b00011110;
        @(posedge cpu_clk_en);
        reg_sel = PPUCTRL;
        reg_en = 1'b0;
        reg_rw = 1'b1;
        reg_data_in = 8'b00000000;
        while(!(dut.row == 9'd261 && dut.col == 9'd340)) begin 
            if(dut.ppu_clk_en) begin 
                // $display("row: %d, col: %d",dut.row, dut.col);
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
   endtask : frameTest

   class OAM;
        rand bit [7:0] mem[256];
        rand bit [7:0] offset;
   endclass : OAM

   class RAM;
        rand bit [7:0] vram[1000];
        rand bit [7:0] pal[32];
   endclass : RAM

   logic [7:0] oam_test_read;
   logic [7:0] ram_test_read;

    OAM oam;
    RAM ram;

    logic [7:0] i;

    task oamdataTest(output logic passed);
        oam = new();
        oam.randomize();
        ram = new();
        ram.randomize();
        reg_sel = PPUCTRL;
        reg_en = 1'b0;
        reg_rw = 1'b0;
        reg_data_in = 8'd0;

        passed = 1;
        @(posedge cpu_clk_en)
        reg_sel = OAMADDR;
        reg_en = 1'b1;
        reg_rw = 1'b1;
        reg_data_in = oam.offset;
        if($test$plusargs("DEBUG")) begin
            $display("offset : %d",oam.offset);
        end
        @(posedge cpu_clk_en);
        // test OAMDATA
        for (i = 8'd0; i != 8'd255; i++) begin
            reg_sel = OAMDATA;
            reg_en = 1'b1;
            reg_rw = 1'b1;
            reg_data_in = oam.mem[i];
            @(posedge cpu_clk_en);
        end
        @(posedge cpu_clk_en);

        for(i = 8'd0; i != 8'd255; i++) begin 
            if(oam.mem[i] != dut.om.mem[i + oam.offset]) begin 
                $display({"random oam did not match ppu's oam: ",
                          "random mem[%d] = %h, ppu mem[%d] = %h\n"}, 
                          i, oam.mem[i], i + oam.offset, dut.om.mem[i + oam.offset]);
                passed = 0;
            end
        end

        if($test$plusargs("DEBUG")) begin
            if(passed) $display("passed test for offset %d", oam.offset);
            else $display("failed test for offset %d", oam.offset);
        end
    endtask : oamdataTest

    task oamdmaTest(output logic passed);

    endtask : oamdmaTest


    task ppudataTest(output logic passed);

    endtask: ppudataTest

    int passes, tests;
    logic passed;
    initial begin
        if($test$plusargs("FRAMETEST")) begin
            $display({"\n",
                      "---------------------\n",
                      "<Testing Frame Generation>\n",
                      "---------------------\n" });
            doReset;
            @(posedge clk);
            frameTest;
        end 

        if($test$plusargs("REGINTER")) begin 
            $display({"\n",
                      "---------------------\n",
                      "<Testing Register Interface Reads and Writes>\n",
                      "---------------------\n" });
            doReset;
            @(posedge clk);
            passes = 0;
            tests = 500;
            for (int i = 0; i < tests; i++) begin
                oamdataTest(passed);
                if(passed) passes++;
                @(posedge clk);    
            end
            $display("passed %d/%d tests", passes, tests);
        end
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