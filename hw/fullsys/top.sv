`default_nettype none
`include "../ppu/ppu_defines.vh"

module top ();
     string logFile = "logs/fullsys-log.txt";

    logic clock;
    logic reset_n;
    default clocking cb_main @(posedge clock); endclocking

    logic ppu_clk_en;  // Master / 4
    clock_div #(4) p_ck(.clk(clock), .rst_n, .clk_en(ppu_clk_en));

    logic cpu_clk_en;  // Master / 12
    clock_div #(12) p_ck(.clk(clock), .rst_n, .clk_en(cpu_clk_en));

    // ppu cycle
    logic [63:0] ppu_cycle;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            cycle <= 64'd0;
        end else if(ppu_clk_en) begin
            cycle <= cycle + 64'd1;
        end
    end

    // cpu cycle
    logic [63:0] cpu_cycle;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            cycle <= 64'd0;
        end else if(cpu_clk_en) begin
            cycle <= cycle + 64'd1;
        end
    end

    // PPU stuff
    logic vblank_nmi;
    logic vsync_n;                // vga vsync enable low
    logic hsync_n;                // vga hsync enable low
    logic [7:0] vga_r;            // vga red 
    logic [7:0] vga_g;            // vga green
    logic [7:0] vga_b;            // vga blue
    logic blank;
    reg_t reg_sel;                  // register to write to
    logic reg_en;                   // 1 - write to register; 0 - do nothing
    logic reg_rw;                   // 1 - write mode; 0 - read mode
    logic [7:0] reg_data_wr;        // data to write
    logic [7:0] reg_data_rd;       // data read
    logic cpu_cyc_par;              // used for exact DMA timing
    logic cpu_sus;                  // suspend CPU when performing OAMDMA
    logic [15:0] mem_addr_p;
    logic mem_re_p;
    logic [7:0] mem_rd_data_p;

    assign cpu_cyc_par = cpu_cycle[0];

    ppu peep(.clk(clock), .rst_n(reset_n), .ppu_clk_en, .vblank_nmi, 
            .vsync_n, .hsync_n, .vga_r, .vga_g, .vga_b, .blank, 
            .cpu_clk_en, .reg_sel, .reg_en, .reg_rw, .reg_data_in(reg_data_wr), .reg_data_out(reg_data_rd),
            .cpu_cyc_par, .cpu_sus, 
            .cpu_addr(mem_addr_p), .cpu_re(mem_re_p), .cpu_rd_data(mem_rd_data_p));

    // CPU stuff
    logic [15:0] mem_addr_c;
    logic mem_re_c;
    logic [7:0] mem_wr_data_c;
    logic [7:0] mem_rd_data_c;

    core cpu(.addr(mem_addr_c), .r_en(mem_re_c), .w_data(mem_wr_data_c),
             .r_data(mem_rd_data_c), .clock_en(cpu_clk_en && !suspend), .clock, .reset_n,
             .reg_sel, .reg_en, .reg_rw, .reg_data_wr, .reg_data_rd);

    // CPU Memory Interface
    logic [15:0] mem_addr;
    logic mem_re;
    logic [7:0] mem_wr_data, mem_rd_data;

    assign mem_addr = (cpu_sus) ? mem_addr_p : mem_addr_c;
    assign mem_re = (cpu_sus) ? mem_re_p : mem_re_c;

    assign mem_wr_data = mem_wr_data_c;

    assign mem_rd_data_c = mem_rd_data;
    assign mem_rd_data_p = mem_rd_data;

    cpu_memory mem(.addr(mem_addr), .r_en(mem_re), .w_data(mem_wr_data), 
                   .clock, .clock_en, .reset_n, .r_data(mem_rd_data), .nmi(vblank_nmi));

    initial begin 
        clock = 1'b0;
        forever #5 clock = ~clock;
    end

    // Conduct a system reset
    task doReset;
        reset_n = 1'b1;
        reset_n <= 1'b0;

        #1 reset_n <= 1'b1;
    endtask : doReset

    int fd;
    int cnt;
    initial begin
        fd = $fopen(logFile,"w");
        doReset;
        @(posedge cpu_clk_en);
        @(posedge cpu_clk_en);
        @(posedge cpu_clk_en);
        cnt = 0;
        while(cnt < 32'd2012633) begin
            
            cnt++; 
        end
        @(posedge cpu_clk_en);
        @(posedge cpu_clk_en);
        @(posedge cpu_clk_en);
        @(posedge cpu_clk_en);
        $finish;
    end

endmodule