`default_nettype none
`include "../include/ppu_defines.vh"
`include "../apu/apu_defines.vh"

`define CPU_CYCLES 297807
`define NUM_FRAMES 30

module top ();
    string logFile = "logs/fullsys-log.txt";
    string vramFile = "logs/vram-traces/vram";
    string frameCount;

    logic clock;
    logic reset_n;
    default clocking cb_main @(posedge clock); endclocking
    logic svst_stall;

    logic vga_clk_en;  // Master / 2
    clock_div #(2) v_ck(.clk(clock), .rst_n(reset_n), .clk_en(vga_clk_en), .stall(svst_stall));

    logic ppu_clk_en;  // Master / 4
    clock_div #(4) ppu_clk(.clk(clock), .rst_n(reset_n), .clk_en(ppu_clk_en), .stall(svst_stall));

    logic cpu_clk_en;  // Master / 12
    clock_div #(12) cpu_clk(.clk(clock), .rst_n(reset_n), .clk_en(cpu_clk_en), .stall(svst_stall));

    logic apu_clk_en;
    clock_div #(24) apu_clk(.clk(clock), .rst_n(reset_n), .clk_en(apu_clk_en));

    // ppu cycle
    logic [63:0] ppu_cycle;
    always_ff @(posedge clock or negedge reset_n) begin
        if(~reset_n) begin
            ppu_cycle <= 64'd0;
        end else if(ppu_clk_en) begin
            ppu_cycle <= ppu_cycle + 64'd1;
        end
    end

    // cpu cycle
    logic [63:0] cpu_cycle;
    always_ff @(posedge clock or negedge reset_n) begin
        if(~reset_n) begin
            cpu_cycle <= 64'd0;
        end else if(cpu_clk_en) begin
            cpu_cycle <= cpu_cycle + 64'd1;
        end
    end

    // Save State Stuff

    logic [15:0] svst_state_read_data;
    logic [15:0] svst_mem_read_data;
    logic svst_begin_save_state, svst_begin_load_state;
    logic svst_state_write_en, svst_state_read_en;
    logic [`SAVE_STATE_BITS-1:0] svst_state_addr;
    logic [15:0] svst_state_write_data;
    logic svst_mem_write_en, svst_mem_read_en;
    logic [`SAVE_STATE_BITS-1:0] svst_mem_addr;
    logic [15:0] svst_mem_write_data;
    logic [15:0] mem_state_read_data;
    logic [15:0] cpu_state_read_data;

    save_state_module svst_module(
        .clock, .reset_n, 
        .state_read_data(svst_state_read_data),
        .mem_read_data(svst_mem_read_data),
        .begin_save_state(svst_begin_save_state),
        .begin_load_state(svst_begin_load_state),
        .stall(svst_stall),
        .state_write_en(svst_state_write_en),
        .state_read_en(svst_state_read_en),
        .state_addr(svst_state_addr),
        .state_write_data(svst_state_write_data),
        .mem_write_en(svst_mem_write_en),
        .mem_read_en(svst_mem_read_en),
        .mem_addr(svst_mem_addr),
        .mem_write_data(svst_mem_write_data));

    save_data_router svst_data_router(.clock, .reset_n, 
        .save_data(svst_state_read_data),
        .cpu_save_data(cpu_state_read_data), .mem_save_data(mem_state_read_data), 
        .state_addr(svst_state_addr));

    sim_save_state_mem svst_mem(.*);

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

    // debug
    logic [7:0] ppuctrl, ppumask;
    mirror_t mirroring;

    logic [7:0] header [15:0];
    logic [7:0] flag6, prgsz, chrsz;

    always_ff @(posedge clock or negedge reset_n) begin
      if(~reset_n) begin
        $readmemh("../init/header_init.txt", header);
      end
    end

    assign prgsz = header[4];
    assign chrsz = header[5];
    assign flag6 = header[6];

    always_comb begin
        case ({flag6[3], flag6[0]})
            2'b00: mirroring = HOR_MIRROR;
            2'b01: mirroring = VER_MIRROR;
            2'b10: mirroring = FOUR_SCR_MIRROR;   // ONE_SCR_MIRROR?
            2'b11: mirroring = FOUR_SCR_MIRROR;
            default : mirroring = VER_MIRROR;
        endcase
    end
    // APU
    logic [4:0] reg_addr;
    logic [7:0] reg_write_data;
    logic [7:0] reg_read_data;
    logic data_valid, reg_we;

    assign cpu_cyc_par = cpu_cycle[0];

    ppu peep(.clk(clock), .rst_n(reset_n), .ppu_clk_en, .vblank_nmi, 
            .vsync_n, .hsync_n, .vga_r, .vga_g, .vga_b, .blank, 
            .cpu_clk_en, .reg_sel, .reg_en, .reg_rw, .reg_data_in(reg_data_wr), .reg_data_out(reg_data_rd),
            .cpu_cyc_par, .cpu_sus, 
            .cpu_addr(mem_addr_p), .cpu_re(mem_re_p), .cpu_rd_data(mem_rd_data_p),
            .ppuctrl, .ppumask, .mirroring);

    // CPU stuff
    logic [15:0] mem_addr_c;
    logic mem_re_c;
    logic [7:0] mem_wr_data_c;
    logic [7:0] mem_rd_data_c;
    logic irq_n;

    // debug
    logic [15:0] PC_debug;

    core cpu(.addr(mem_addr_c), .mem_r_en(mem_re_c), .w_data(mem_wr_data_c),
             .r_data(mem_rd_data_c), .clock_en(cpu_clk_en && !cpu_sus), .clock, .reset_n,
             .irq_n, .nmi(vblank_nmi),
             .save_state_load_en(svst_state_write_en),
             .save_state_addr(svst_state_addr),
             .save_state_load_data(svst_state_write_data),
             .save_state_save_data(cpu_state_read_data));

    logic [15:0] audio_out;

    apu apooh (
      .clk(clock), .rst_l(reset_n), .cpu_clk_en, .apu_clk_en, .reg_addr, 
      .reg_data_in(reg_write_data), .reg_en(data_valid), .reg_we,
      .irq_l(irq_n),
      .reg_data_out(reg_read_data),
      .audio_out);

    // CPU Memory Interface
    logic [15:0] mem_addr;
    logic mem_re;
    logic [7:0] mem_wr_data, mem_rd_data;
    logic ctlr_data_p1, ctlr_data_p2;
    logic ctlr_pulse_p1, ctlr_pulse_p2, ctlr_latch;
    logic [7:0] read_prom;

    assign ctlr_data_p1 = 1'b1;
    assign ctlr_data_p2 = 1'b1;

    assign mem_addr = (cpu_sus) ? mem_addr_p : mem_addr_c;
    assign mem_re = (cpu_sus) ? mem_re_p : mem_re_c;

    assign mem_wr_data = mem_wr_data_c;

    assign mem_rd_data_c = mem_rd_data;
    assign mem_rd_data_p = mem_rd_data;

    cpu_memory mem(.addr(mem_addr), .r_en(mem_re), .w_data(mem_wr_data), 
                   .clock, .clock_en(cpu_clk_en), .reset_n, .r_data(mem_rd_data), 
                   .reg_sel, .reg_en, .reg_rw, .reg_data_wr, .reg_data_rd,
                   .ctlr_data_p1(1'b1), .ctlr_data_p2(1'b1),
                   .svst_state_read_data(mem_state_read_data),
                   .svst_state_write_en, .svst_state_read_en,
                   .svst_state_addr, .svst_state_write_data,
                   .reg_addr, .reg_write_data, .reg_read_data, .data_valid, .reg_we,
                   .ctlr_data_p1, .ctlr_data_p2,
                   .read_prom);


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

    logic[`SAVE_STATE_LAST_ADDRESS:0][15:0] old_data, new_data;

    function logic [`SAVE_STATE_LAST_ADDRESS:0][15:0] copy_save_data;
        copy_save_data[`SAVE_STATE_CPU_UCODE_INDEX] = cpu.ucode_index;
        copy_save_data[`SAVE_STATE_CPU_INSTR_CTRL_INDEX] = cpu.instr_ctrl_index;
        copy_save_data[`SAVE_STATE_CPU_STATE] = cpu.state;
        copy_save_data[`SAVE_STATE_CPU_NMI_ACTIVE] = cpu.nmi_active;
        copy_save_data[`SAVE_STATE_CPU_RESET_ACTIVE] = cpu.reset_active;
        copy_save_data[`SAVE_STATE_CPU_CURRENT_INTERRUPT] = cpu.curr_interrupt;
        copy_save_data[`SAVE_STATE_CPU_A] = cpu.A;
        copy_save_data[`SAVE_STATE_CPU_X] = cpu.X;
        copy_save_data[`SAVE_STATE_CPU_Y] = cpu.Y;
        copy_save_data[`SAVE_STATE_CPU_SP] = cpu.SP;
        copy_save_data[`SAVE_STATE_CPU_N_FLAG] = cpu.n_flag;
        copy_save_data[`SAVE_STATE_CPU_V_FLAG] = cpu.v_flag;
        copy_save_data[`SAVE_STATE_CPU_D_FLAG] = cpu.d_flag;
        copy_save_data[`SAVE_STATE_CPU_I_FLAG] = cpu.i_flag;
        copy_save_data[`SAVE_STATE_CPU_Z_FLAG] = cpu.z_flag;
        copy_save_data[`SAVE_STATE_CPU_C_FLAG] = cpu.c_flag;
        copy_save_data[`SAVE_STATE_CPU_PC] = cpu.PC;
        copy_save_data[`SAVE_STATE_CPU_R_DATA_BUFFER] = cpu.r_data_buffer;
        copy_save_data[`SAVE_STATE_CPU_ADDR] = cpu.addr_reg_val;
        copy_save_data[`SAVE_STATE_CPU_ALU_OUT] = cpu.alu_out;
        copy_save_data[`SAVE_STATE_CPU_ALU_C_OUT] = cpu.alu_c_out;
        copy_save_data[`SAVE_STATE_CPU_ALU_V_OUT] = cpu.alu_v_out;
        copy_save_data[`SAVE_STATE_CPU_ALU_Z_OUT] = cpu.alu_z_out;
        copy_save_data[`SAVE_STATE_CPU_ALU_N_OUT] = cpu.alu_n_out;
        for (int i = `SAVE_STATE_CPU_MEM_CPU_RAM_LO; i < `SAVE_STATE_CPU_MEM_CPU_RAM_HI; i++) begin
            copy_save_data[i] = mem.ram[i-`SAVE_STATE_CPU_MEM_CPU_RAM_LO];
        end
        copy_save_data[`SAVE_STATE_CPU_MEM_READ_DATA] = mem.mem_data_rd;
        copy_save_data[`SAVE_STATE_CPU_MEM_PREV_REG_EN] = mem.prev_reg_en;
        copy_save_data[`SAVE_STATE_CPU_MEM_PREV_BUT_RD] = mem.prev_but_rd;
        copy_save_data[`SAVE_STATE_CPU_MEM_PREV_APU_RD] = mem.prev_apu_read;

    endfunction : copy_save_data

    task compare_save_data;
        int mismatch_count;
        mismatch_count = 0;
        for (int i = 0; i <= `SAVE_STATE_LAST_ADDRESS; i++) begin
            if (old_data[i] != new_data[i]) begin
                $display("bad addr: %d", i);
                mismatch_count++;
            end
        end
        $display("mismatch_count: %d", mismatch_count);
    endtask : compare_save_data

    int fd, vram_fd;
    int cnt;

    logic [7:0] can_A, can_X, can_Y, can_status, can_SP;
    logic can_n, can_v, can_d, can_i, can_z, can_c;

    assign can_A = (cpu.A_en) ? cpu.next_A : cpu.A;
    assign can_X = (cpu.X_en) ? cpu.next_X : cpu.X;
    assign can_Y = (cpu.Y_en) ? cpu.next_Y : cpu.Y;
    assign can_SP = (cpu.SP_en) ? cpu.next_SP : cpu.SP;

    assign can_n = (cpu.n_flag_en) ? cpu.next_n_flag : cpu.n_flag;
    assign can_v = (cpu.v_flag_en) ? cpu.next_v_flag : cpu.v_flag;
    assign can_d = (cpu.d_flag_en) ? cpu.next_d_flag : cpu.d_flag;
    assign can_i = (cpu.i_flag_en) ? cpu.next_i_flag : cpu.i_flag;
    assign can_z = (cpu.z_flag_en) ? cpu.next_z_flag : cpu.z_flag;
    assign can_c = (cpu.c_flag_en) ? cpu.next_c_flag : cpu.c_flag;

    assign can_status = {can_n, can_v, 1'b1, 1'b0, 
                         can_d, can_i, can_z, can_c};


    int load_save_counter;
    logic do_begin_save;
    logic do_begin_load;
    logic saved_once, loaded_once;
    logic just_enabled_all, just_stalled;

    task cpuTrace(input int fd);
        cnt = 0;
        load_save_counter = 0;
        saved_once = 1'b0;
        loaded_once = 1'b0;
        just_enabled_all = 1'b0;
        just_stalled = 1'b0;
        while(cnt < 12*`CPU_CYCLES) begin

            svst_begin_save_state = 1'b0;
            if (load_save_counter > 12*50 && !saved_once && just_enabled_all) begin
                svst_begin_save_state = 1'b1;
                old_data = copy_save_data();
                saved_once = 1'b1;
            end   
            
            svst_begin_load_state = 1'b0;
            if (load_save_counter > (12*100 + 4 + `SAVE_STATE_LAST_ADDRESS) && !loaded_once && just_enabled_all) begin
                svst_begin_load_state = 1'b1;
                loaded_once = 1'b1;
            end
            if (load_save_counter > (12*100 + 4 + `SAVE_STATE_LAST_ADDRESS) && loaded_once && just_stalled && !svst_stall) begin
                new_data = copy_save_data();
                compare_save_data;
                load_save_counter = 0;
                saved_once = 1'b0;
                loaded_once = 1'b0;
            end
            
            just_enabled_all = cpu_clk_en & ppu_clk_en;// & vga_clk_en; 
            just_stalled = svst_stall;
            load_save_counter++;

            if(cpu.state == STATE_DECODE && cpu_clk_en) begin 
                $fwrite(fd,"%.4x %.2x ", cpu.PC-16'b1, mem_rd_data);
                $fwrite(fd,"A:%.2x X:%.2x Y:%.2x P:%.2x SP:%.2x CYC:%1.d",
                        can_A, can_X, can_Y, can_status, can_SP, cpu_cycle);
                $fwrite(fd," ppuctrl: %.2x, ppumask: %.2x, nmi: %d\n", peep.ppuctrl, peep.ppumask, vblank_nmi);
            end
            @(posedge clock);
            cnt++; 
        end
        @(posedge clock);
        @(posedge clock);
        @(posedge clock);
        @(posedge clock);
    endtask : cpuTrace

    int i;
    task vramTrace(input int fd);
        while(!(peep.vs_curr_state == VIS_SL && peep.col == 9'd0)) begin 
            @(posedge clock);
        end
        // wait until 
        if($test$plusargs("DEBUG")) begin
            $display("Visible Pixel\n");
            $display("tAddr: %X", peep.ri.addr_reg.tAddr);
            $display(" vAddr: %X", peep.ri.addr_reg.vAddr);
            $display(" NT Addr: %X",peep.bg.nt_addr);
        end

        // wait until nmi
        while(vblank_nmi) begin 
            @(posedge clock);
        end

        if($test$plusargs("DEBUG")) begin 
            $display("NMI\n");
            $display("tAddr: %X", peep.ri.addr_reg.tAddr);
            $display(" vAddr: %X\n", peep.ri.addr_reg.vAddr);            
        end


        // write chr_rom data
        for (i = 0; i < 'h2000; i++) begin
            $fwrite(fd,"%.2x ", peep.cr.mem[i%8192]);
        end

        // write name table data
        if(mirroring == VER_MIRROR) begin 
            for (i = 0; i < 4096; i++) begin
                $fwrite(fd,"%.2x ", peep.vr.mem[i%2048]);
            end
        end else if(mirroring == HOR_MIRROR) begin 
            for (i = 0; i < 2048; i++) begin
                $fwrite(fd,"%.2x ", peep.vr.mem[i%1024]);
            end
            for (int i = 0; i < 2048; i++) begin
                $fwrite(fd,"%.2x ", peep.vr.mem[(i%1024) + 1024]);
            end
        end

        // write mirror name table data
        if(mirroring == VER_MIRROR) begin 
            for (i = 0; i < 3840; i++) begin
                $fwrite(fd,"%.2x ", peep.vr.mem[i%2048]);
            end
        end else if(mirroring == HOR_MIRROR) begin 
            for (i = 0; i < 2048; i++) begin
                $fwrite(fd,"%.2x ", peep.vr.mem[i%1024]);
            end
            for (int i = 0; i < 1792; i++) begin
                $fwrite(fd,"%.2x ", peep.vr.mem[(i%1024) + 1024]);
            end
        end

        // write pal ram data and mirrors
        for (i = 0; i < 'h100; i++) begin
            $fwrite(fd,"%.2x ", peep.pr.mem[i%32]);
        end

        // new line
        $fwrite(fd,"\n");

        // pal ram data line
        for (i = 0; i < 'h20; i++) begin
            $fwrite(fd,"%.2x ", peep.pr.mem[i%32]);
        end

        // new line
        $fwrite(fd,"\n");

        // oam data line
        for (i = 0; i < 'h100; i++) begin
            $fwrite(fd,"%.2x ", peep.om.mem[i%256]);
        end


        while(!vblank_nmi)
            @(posedge clock);
    endtask : vramTrace

    initial begin
        if($test$plusargs("CPUTRACE")) begin 
            fd = $fopen(logFile,"w");

            $display({"\n",
                      "---------------------\n",
                      "<Getting a CPU trace>\n",
                      "---------------------\n" });
            doReset;
            @(posedge clock);
            cpuTrace(fd);
        end

        if($test$plusargs("VRAMTRACE")) begin 
            $display({"\n",
                      "---------------------\n",
                      "<Getting a PPU vram trace>\n",
                      "---------------------\n" });
            doReset;
            @(posedge clock);
            if(mirroring == VER_MIRROR) begin 
                $display("Vertical mirroring");
            end else if(mirroring == HOR_MIRROR) begin
                $display("Horizontal mirroring");
            end else begin 
                $error("mirroring was wrong");
            end
            for (int i = 0; i < `NUM_FRAMES; i++) begin
                frameCount.itoa(i);
                vram_fd = $fopen({vramFile, frameCount, ".txt"},"w");
                vramTrace(vram_fd);
                $fclose(vram_fd);
                @(posedge clock);
            end
        end

        $finish;
    end

endmodule
