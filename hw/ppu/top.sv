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
    logic [2:0] vga_r; // vga red 
    logic [2:0] vga_g; // vga green
    logic [1:0] vga_b; // vga blue

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

    initial begin
    	##100000;
    	$finish;
  	end


    initial begin
        doReset;

        f = $fopen(filename, "w");

        $display("row: %d, col: %d",dut.row, dut.col);

        while(!(dut.row == 9'd261 && dut.col == 9'd340)) begin 
            if(dut.col == 9'd256) begin 
                for (int i = 0; i < 256; i++) begin
                    $fwrite(f, "%X ", dut.ppu_buffer[i]);
                end
                $fwrite(f, "\n");
            end
            @(posedge clk);
        end


    end


endmodule
