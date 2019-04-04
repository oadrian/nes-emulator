`default_nettype none
`include "../include/ppu_defines.vh"

module top ();
    int f;
    string filename = "my_frame.txt";

    logic clk;
    logic rst_n;
    default clocking cb_main @(posedge clk); endclocking

    logic ppu_clk_en;
    logic vblank_nmi;
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
    clock_div #(4) ppu_ck(.clk, .rst_n, .clk_en(ppu_clk_en));    

    // CPU clock enable
    clock_div #(12) cpu_ck(.clk, .rst_n, .clk_en(cpu_clk_en));

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
        reg_rw = 1'b0;
        reg_data_in = 8'b00000000;

        cpu_cyc_par = 1'b0;
        cpu_rd_data = 8'd0;
        @(negedge cpu_clk_en);
        reg_sel = PPUCTRL;
        reg_en = 1'b0;
        reg_rw = 1'b1;
        reg_data_in = 8'b00000000;

        cpu_cyc_par = 1'b0;
        cpu_rd_data = 8'd0;
        @(negedge cpu_clk_en);
        reg_sel = PPUCTRL;
        reg_en = 1'b1;
        reg_rw = 1'b1;
        reg_data_in = 8'b10010000;
        @(negedge cpu_clk_en);
        reg_sel = PPUMASK;
        reg_en = 1'b1;
        reg_rw = 1'b1;
        reg_data_in = 8'b00011110;
        @(negedge cpu_clk_en);
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
        rand bit [7:0] upper_addr;
        rand bit cyc_par;
    endclass : OAM

    class VRAM;
        rand bit [7:0] mem[32];
        rand bit I_mode;   // 0 - +1, 1 - +32
        rand bit [15:0] offset;
        constraint c {
            if(I_mode == 1'b1)
                (16'h2000 <= offset && offset <= 16'h3C00);
            else 
                (16'h2000 <= offset && offset <= 16'h3FE0);
        }
    endclass : VRAM

    OAM oam, dma;
    VRAM vram;

    logic [7:0] i;

    task oamdataTest(output logic passed);
        oam = new();
        oam.randomize();
        reg_sel = PPUCTRL;
        reg_en = 1'b0;
        reg_rw = 1'b0;
        reg_data_in = 8'b00000000;

        cpu_cyc_par = 1'b0;
        cpu_rd_data = 8'd0;

        passed = 1;
        @(negedge cpu_clk_en);
        reg_sel = PPUCTRL;
        reg_en = 1'b0;
        reg_rw = 1'b0;
        reg_data_in = 8'd0;
        @(negedge cpu_clk_en);
        if($test$plusargs("DEBUG")) begin
            $display("Writing to OAM");
        end
        reg_sel = OAMADDR;
        reg_en = 1'b1;
        reg_rw = 1'b1;
        reg_data_in = oam.offset;
        if($test$plusargs("DEBUG")) begin
            $display("offset : %d",oam.offset);
        end
        @(negedge cpu_clk_en);
        // test OAMDATA
        for (i = 8'd0; i != 8'd255; i++) begin
            reg_sel = OAMDATA;
            reg_en = 1'b1;
            reg_rw = 1'b1;   // write
            reg_data_in = oam.mem[i];
            @(negedge cpu_clk_en);
        end
        @(negedge cpu_clk_en);
        if($test$plusargs("DEBUG")) begin
            $display("Reading from OAM");
        end
        // test OAMDATA
        for (i = 8'd0; i != 8'd255; i++) begin
            reg_sel = OAMADDR;
            reg_en = 1'b1;
            reg_rw = 1'b1;
            reg_data_in = oam.offset + i;
            @(negedge cpu_clk_en);
            reg_sel = OAMDATA;
            reg_en = 1'b1;
            reg_rw = 1'b0;  // read
            @(negedge cpu_clk_en);
            #1; // simulation uses values in preponed region for reg_data_out otherwise lul
            if(oam.mem[i] != reg_data_out) begin 
                $display({"random oam did not match ppu's oam: ",
                          "random mem[%d] = %h, ppu mem[%d] = %h\n"}, 
                          i, oam.mem[i], i + oam.offset, reg_data_out);
                passed = 0;
            end
        end
        @(negedge cpu_clk_en);



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
        dma = new();
		dma.randomize();
        reg_sel = PPUCTRL;
        reg_en = 1'b0;
        reg_rw = 1'b0;
        reg_data_in = 8'b00000000;

        cpu_cyc_par = 1'b0;
        cpu_rd_data = 8'd0;

        passed = 1;
        @(negedge cpu_clk_en);
		reg_sel = PPUCTRL;
        reg_en = 1'b1;
        reg_rw = 1'b1;
        reg_data_in = 8'd00000000;   // increment 1 going across
		@(negedge cpu_clk_en);
		reg_sel = OAMADDR;
		reg_en = 1'b1;
		reg_rw = 1'b1;
		reg_data_in = dma.offset;
		if($test$plusargs("DEBUG")) begin
            $display("offset : %d",dma.offset);
        end
        @(negedge cpu_clk_en);
        reg_sel = OAMDMA;
		reg_en = 1'b1;
		reg_rw = 1'b1;
		reg_data_in = dma.upper_addr;
		
		cpu_cyc_par = dma.cyc_par;
		@(negedge cpu_clk_en);
		reg_sel = PPUCTRL;
        reg_en = 1'b0;
        reg_rw = 1'b0;
        reg_data_in = 8'd00000000;
		if(cpu_cyc_par) begin
			@(negedge cpu_clk_en);
			@(negedge cpu_clk_en);
		end else begin
			@(negedge cpu_clk_en);		
		end
		for(i = 8'd0; i != 8'd255; i++) begin
			// read cycle
			read_sus: assert(cpu_sus);
			read_addr: assert(cpu_addr[15:8] == dma.upper_addr);
			@(negedge cpu_clk_en);
			// write cycle
			write_sus: assert(cpu_sus);
			cpu_rd_data = dma.mem[i];
			@(negedge cpu_clk_en);
		end
		@(negedge cpu_clk_en);
		@(negedge cpu_clk_en);
		@(negedge cpu_clk_en);
		
		// check oam contents
		for(i = 8'd0; i != 8'd255; i++) begin 
            if(dma.mem[i] != dut.om.mem[i + dma.offset]) begin 
                $display({"random oam did not match ppu's oam: ",
                          "random mem[%d] = %h, ppu mem[%d] = %h\n"}, 
                          i, dma.mem[i], i + dma.offset, dut.om.mem[i + dma.offset]);
                passed = 0;
            end
        end

        if($test$plusargs("DEBUG")) begin
            if(passed) $display("passed test for offset %d", dma.offset);
            else $display("failed test for offset %d", dma.offset);
        end
		
    endtask : oamdmaTest

    logic [15:0] j, k, curr_addr;
    task ppudataTest(output logic passed);
        /////// VRAM READS/WRITES ////////
        vram = new();
        vram.randomize();
        reg_sel = PPUCTRL;
        reg_en = 1'b0;
        reg_rw = 1'b0;
        reg_data_in = 8'b00000000;

        cpu_cyc_par = 1'b0;
        cpu_rd_data = 8'd0;

        passed = 1;
        @(negedge cpu_clk_en);
        reg_sel = PPUCTRL;
        reg_en = 1'b1;
        reg_rw = 1'b1;
        reg_data_in = {5'b00000, vram.I_mode ,2'b00};   // increment 1 going across
        @(negedge cpu_clk_en);
        reg_sel = PPUADDR;
        reg_en = 1'b1;
        reg_rw = 1'b1;
        reg_data_in = vram.offset[15:8];
        @(negedge cpu_clk_en);
        reg_sel = PPUADDR;
        reg_en = 1'b1;
        reg_rw = 1'b1;
        reg_data_in = vram.offset[7:0];
        @(negedge cpu_clk_en);
        for (j = 16'd0; j < 16'd32; j++) begin
            reg_sel = PPUDATA;
            reg_en = 1'b1;
            reg_rw = 1'b1;   // write
            reg_data_in = vram.mem[j];
            @(negedge cpu_clk_en);
        end
        @(negedge cpu_clk_en);
        @(negedge cpu_clk_en);
        k = 16'd0;
        if(vram.I_mode) begin
            $display("I_mode was +32");
        end else begin 
            $display("I_mode was +1");
        end
        for(j = 16'd0; j < 16'd32 ; j++) begin 
            curr_addr = k + vram.offset;
            if(16'h2000 <= curr_addr && curr_addr <= 16'h27ff) begin
                if(vram.mem[j] != dut.vr.mem[curr_addr[10:0]]) begin 
                    $display({"random vram did not match ppu's vram: ",
                              "random mem[%d] = %h, ppu's mem[%d] = %h\n"}, 
                              j, vram.mem[j], curr_addr[10:0], dut.vr.mem[curr_addr[10:0]]);
                    passed = 0;
                end
            end else if(16'h3000 <= curr_addr && curr_addr <= 16'h37ff) begin 
                if(vram.mem[j] != dut.vr.mem[curr_addr[10:0]]) begin 
                    $display({"random vram did not match ppu's vram: ",
                              "random mem[%d] = %h, ppu mem[%d] = %h\n"}, 
                              j, vram.mem[j], curr_addr[10:0], dut.vr.mem[curr_addr[10:0]]);
                    passed = 0;
                end
            end else if(16'h3f00 <= curr_addr && curr_addr <= 16'h3fff) begin 
                if(vram.mem[j] != dut.pr.mem[curr_addr[4:0]]) begin 
                    $display({"random vram did not match ppu's vram: ",
                              "random mem[%d] = %h, ppu mem[%d] = %h\n"}, 
                              j, vram.mem[j], curr_addr[4:0], dut.pr.mem[curr_addr[4:0]]);
                    passed = 0;
                end
            end
            k = (vram.I_mode) ? k+16'd32 : k+16'd1;
        end
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

        if($test$plusargs("OAMDATA")) begin 
            $display({"\n",
                      "---------------------\n",
                      "<Testing OAMDATA Register Interface Reads/Writes>\n",
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
        
        if($test$plusargs("OAMDMA")) begin 
            $display({"\n",
                      "---------------------\n",
                      "<Testing OAMDMA Register Interface Writes>\n",
                      "---------------------\n" });
            doReset;
            @(posedge clk);
            passes = 0;
            tests = 500;
            for (int i = 0; i < tests; i++) begin
                oamdmaTest(passed);
                if(passed) passes++;
                @(posedge clk);    
            end
            $display("passed %d/%d tests", passes, tests);
           
        end

        if($test$plusargs("PPUDATA")) begin
            $display({"\n",
                      "---------------------\n",
                      "<Testing PPUDATA Register Interface Writes>\n",
                      "---------------------\n" });
            doReset;
            @(posedge clk);
            passes = 0;
            tests = 500;
            for (int i = 0; i < tests; i++) begin
                ppudataTest(passed);
                if(passed) passes++;
                @(posedge clk);    
            end
            $display("passed %d/%d tests", passes, tests);
        end
        $finish;

    end
    
    /*
    check_dma: assert property(
    	@(negedge cpu_clk_en)  (reg_sel == OAMDMA && cpu_cyc_par == 1'b1) ##1 
    ) else $error("dma failed");
	*/
	
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
