`default_nettype none
`include "ppu_defines.vh"

module reg_inter (
    input logic clk,    // Clock
    input logic cpu_clk_en, // CPU Clock Enable
    input logic ppu_clk_en, // PPU Clock Enable
    input logic rst_n,  // Asynchronous reset active low
    
    // CPU bus 
    input reg_t reg_sel,  // register to write to
    input logic reg_en,        // 1 - register interface enabled, 0 - do nothing
    input logic reg_rw,        // 1 - write mode, 0 - read mode
    input logic [7:0] reg_data_in,  // data to write
    output logic [7:0] reg_data_out, // data read

    // CPU cycle parity
    input logic cpu_cyc_par,  // used for exact DMA timing

    // CPU suspend
    output logic cpu_sus,     // suspend CPU when performing OAMDMA

    // PPU status flags
    input logic sp_over_set,
    input logic sp_over_clr,

    input logic sp_zero_set,
    input logic sp_zero_clr,

    input logic vblank_set,
    input logic vblank_clr,

    // OAM  (Async read)
    output logic [7:0] oam_addr, 
    output logic oam_we,
    output logic oam_re,

    output logic [7:0] oam_wr_data,
    input logic [7:0] oam_rd_data,

    // VRAM (Async read)
    output logic [10:0] vram_addr,
    output logic vram_we,
    output logic vram_re,

    output logic [7:0] vram_wr_data,
    input logic [7:0] vram_rd_data,

    // PAL RAM (ASYNC)
    output logic [4:0] pal_addr,
    output logic pal_we,
    output logic pal_re,

    output logic [7:0] pal_wr_data,
    input logic [7:0] pal_rd_data,

    // CPU MEM READ (SYNC)
    output logic [15:0] cpu_addr,
    output logic cpu_re,
    input logic [7:0] cpu_rd_data,

    // register interface
    output logic [7:0] ppuctrl_out,
    output logic [7:0] ppumask_out,
    output logic [7:0] ppuscrollX_out,
    output logic [7:0] ppuscrollY_out
);
    // update flops
    logic update0, update1, update2, update3,
          update4, update5, update6, update7,
          update8, update9, update_flops;  

    always_ff @(posedge clk or negedge rst_n) begin
           if(~rst_n) begin
               update0 <= 0;
               update1 <= 0;
               update2 <= 0;
               update3 <= 0;
               update4 <= 0;
               update5 <= 0;
               update6 <= 0;
               update7 <= 0;
               update8 <= 0;
               update9 <= 0;
               update_flops <= 0;
           end else begin
                update0 <= cpu_clk_en;
                update1 <= update0;
                update2 <= update1;
                update3 <= update2;
                update4 <= update3;
                update5 <= update4;
                update6 <= update5;
                update7 <= update6;
                update8 <= update7;
                update9 <= update8;
                update_flops <= update9;
           end
       end 

    /////// ALL register definitions  ////////

    // write only
    logic [7:0] ppuctrl_in;
    logic [7:0] ppumask_in;
    logic [7:0] ppuscrollX_in;
    logic [7:0] ppuscrollY_in;
    logic [7:0] oamdma_out, oamdma_in;

    // need to pipeline them 12 stages so that increment doesn't happen to early
    logic [15:0] ppuaddr_out, ppuaddr_in;
    logic [7:0] oamaddr_out, oamaddr_in;

    // read only
    logic [7:0] ppustatus_out, last_write;

    // oam write wires for OAMDATA
    logic oam_re_reg;
    logic oam_we_reg;
    logic [7:0] oam_wr_data_reg;

    // oam write wires for OAMDMA process
    logic oam_we_dma;
    logic [7:0] oam_wr_data_dma;
    logic [7:0] oam_addr_dma;

    // OAM address to read or write to
    assign oam_re = oam_re_reg;
    assign oam_we = (oam_we_dma || oam_we_reg);

    always_comb begin
        oam_addr = oamaddr_out;
        if(oam_we_dma) begin 
            oam_addr = oam_addr_dma;
        end else if(oam_we_reg || oam_re_reg) begin 
            oam_addr = oamaddr_out;
        end
    end

    always_comb begin
        oam_wr_data = 8'd0;
        if(oam_we_dma) begin 
            oam_wr_data = oam_wr_data_dma;
        end else if(oam_we_reg) begin 
            oam_wr_data = oam_wr_data_reg;
        end
    end

    // PPU VRAM address to read or write to
    logic vram_we_reg;
    assign vram_we = vram_we_reg;
    assign vram_addr = ppuaddr_out[10:0];

    // PAL ram address to read or write to
    logic pal_we_reg;
    assign pal_we = pal_we_reg; 
    assign pal_addr = ppuaddr_out[4:0];

    /////// Write Only Registers //////////
    logic ppustatus_rd_clr;
    logic oamaddr_inc;
    logic ppuaddr_inc;
    logic [15:0] ppuaddr_inc_amnt;

    // OAM increment logic
    assign oamaddr_inc = (reg_sel == OAMDATA) && reg_en && reg_rw;

    // VRAM increment logic
    assign ppuaddr_inc = (reg_sel == PPUDATA) && reg_en;
    assign ppuaddr_inc_amnt = (ppuctrl_out[2]) ? 16'd32 : 16'd1;  

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            ppuctrl_out <= 8'd0;
            ppumask_out <= 8'd0;
            oamaddr_out <= 8'd0;
            ppuscrollX_out <= 8'd0;
            ppuscrollY_out <= 8'd0;
            ppuaddr_out <= 16'd0;
            oamdma_out <= 8'd0;
        end else if(update_flops) begin
            ppuctrl_out <= ppuctrl_in;
            ppumask_out <= ppumask_in;
            oamdma_out <= oamdma_in;
            ppuscrollX_out <= ppuscrollX_in;
            ppuscrollY_out <= ppuscrollY_in;
            oamaddr_out <= oamaddr_in;
            ppuaddr_out <= ppuaddr_in;

            if(oamaddr_inc) begin 
                oamaddr_out <= oamaddr_out + 8'd1;
            end

            if(ppuaddr_inc) begin 
                ppuaddr_out <= ppuaddr_out + ppuaddr_inc_amnt;
            end

            if(ppustatus_rd_clr) begin 
                ppuscrollX_out <= 8'd0;
                ppuscrollY_out <= 8'd0;
                ppuaddr_out <= 16'd0;
            end
        end
    end
    

    ///////// double writes /////////
    enum logic {
        FIRST_WRITE,
        SECOND_WRITE
    } scroll_wr_curr_state, scroll_wr_next_state,
      addr_wr_curr_state, addr_wr_next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            scroll_wr_curr_state <= FIRST_WRITE;
            addr_wr_curr_state <= FIRST_WRITE;
        end else if(update_flops) begin
            scroll_wr_curr_state <= scroll_wr_next_state;
            addr_wr_curr_state <= addr_wr_next_state;
        end
    end

    ///////// read out register //////////
    logic [7:0] reg_data_out_next;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            reg_data_out <= 8'd0;
        end else if(update_flops) begin
            reg_data_out <= reg_data_out_next;
        end
    end

    /////////// READ ONLY registers //////////
    logic force_vblank_clr0, force_vblank_clr1;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            ppustatus_out <= 8'd0;
            force_vblank_clr0 <= 1'b0;
            force_vblank_clr1 <= 1'b0;
        end else if(ppu_clk_en) begin
            ppustatus_out[4:0] <= last_write[4:0];

            force_vblank_clr0 <= ppustatus_rd_clr;
            force_vblank_clr1 <= force_vblank_clr0;

            if(sp_over_set)
                ppustatus_out[5] <= 1'b1;
            if(sp_over_clr)
                ppustatus_out[5] <= 1'b0;

            if(sp_zero_set)
                ppustatus_out[6] <= 1'b1;
            if(sp_zero_clr)
                ppustatus_out[6] <= 1'b0; 

            if(vblank_set)
                ppustatus_out[7] <= 1'b1;
            if(vblank_clr || force_vblank_clr1) begin 
                ppustatus_out[7] <= 1'b0;            
                force_vblank_clr0 <= 1'b0;
                force_vblank_clr1 <= 1'b0;                
            end
        end
    end

    //////// OAMDMA FSM ////////
    logic begin_dma;
    enum logic [2:0] {
        OAMDMA_IDLE,
        OAMDMA_DUMMY1,
        OAMDMA_DUMMY2,
        OAMDMA_READ,
        OAMDMA_WRITE
    } oamdma_curr_state, oamdma_next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            oamdma_curr_state <= OAMDMA_IDLE;
        end else if(update_flops) begin
            oamdma_curr_state <= oamdma_next_state;
        end
    end

    logic [7:0] counter;
    logic counter_en, counter_clr;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            counter <= 8'd0;
        end else if(update_flops) begin
            if(counter_clr)
                counter <= 8'd0;
            else if(counter_en)
                counter <= counter + 8'd1;
        end
    end

    // address to read from CPU RAM
    assign cpu_addr = {oamdma_out, counter};

    // address to write to in OAM
    assign oam_addr_dma = counter + oamaddr_out;

    // data to write to OAM
    assign oam_wr_data_dma = cpu_rd_data;

    always_comb begin
        oamdma_next_state = oamdma_curr_state;

        // suspend flag
        cpu_sus = 1'b0;

        // counter
        counter_en = 1'b0;
        counter_clr = 1'b0;

        // CPU read 
        cpu_re = 1'b0;

        // OAM write
        oam_we_dma = 1'b0;
        case (oamdma_curr_state)
            OAMDMA_IDLE: begin 
                oamdma_next_state = (begin_dma) ? OAMDMA_DUMMY1 : OAMDMA_IDLE;
                cpu_sus = (begin_dma) ? 1'b1 : 1'b0;
            end
            OAMDMA_DUMMY1: begin 
                cpu_sus = 1'b1;
                oamdma_next_state = (cpu_cyc_par) ? OAMDMA_DUMMY2 : OAMDMA_READ;
                counter_clr = 1'b1;
            end
            OAMDMA_DUMMY2: begin 
                cpu_sus = 1'b1;
                oamdma_next_state = OAMDMA_READ;
            end
            OAMDMA_READ: begin 
                cpu_sus = 1'b1;
                oamdma_next_state = OAMDMA_WRITE;
                cpu_re = 1'b1;
            end
            OAMDMA_WRITE: begin 
                oam_we_dma = 1'b1;
                if(counter == 8'd255) begin 
                    oamdma_next_state = OAMDMA_IDLE;
                    cpu_sus = 1'b0;
                    counter_en = 1'b0;
                end else begin 
                    oamdma_next_state = OAMDMA_READ;
                    cpu_sus = 1'b1;
                    counter_en = 1'b1;
                end
            end
            default : /* default */;
        endcase
    
    end

    // handle reads and writes to ppu registers 
    
    always_comb begin
        // registers written by cpu
        ppuctrl_in = ppuctrl_out;
        ppumask_in = ppumask_out;
        oamaddr_in = oamaddr_out;
        ppuscrollX_in = ppuscrollX_out;
        ppuscrollY_in = ppuscrollY_out;
        ppuaddr_in = ppuaddr_out;
        oamdma_in = oamdma_out;

        // last write
        last_write = ppustatus_out;

        // mult writes 
        scroll_wr_next_state = scroll_wr_curr_state;
        addr_wr_next_state = addr_wr_curr_state;

        // dma fsm controll
        begin_dma = 1'b0;

        // OAM
        oam_re_reg = 1'b0;
        oam_we_reg = 1'b0;
        oam_wr_data_reg = 8'd0;

        // PPU VRAM
        vram_re = 1'b0;
        vram_we_reg = 1'b0;
        vram_wr_data = 8'd0;

        // PAL RAM
        pal_re = 1'b0;
        pal_we_reg = 1'b0;
        pal_wr_data = 8'd0;

        // read register
        reg_data_out_next = reg_data_out;

        // ppustatus read clear
        ppustatus_rd_clr = 1'b0;
        case (reg_sel)
            PPUCTRL: begin        // write only
                if(reg_en && reg_rw) begin 
                    ppuctrl_in = reg_data_in;
                    last_write = reg_data_in;
                end 
            end
            PPUMASK: begin       // write only 
                if(reg_en && reg_rw) begin 
                    ppumask_in = reg_data_in;
                    last_write = reg_data_in;
                end
            end
            OAMADDR: begin       // write only 
                if(reg_en && reg_rw) begin
                    oamaddr_in = reg_data_in;
                    last_write = reg_data_in;
                end
            end
            PPUSCROLL: begin     // write twice
                if(reg_en && reg_rw && scroll_wr_curr_state == FIRST_WRITE) begin 
                    scroll_wr_next_state = SECOND_WRITE;
                    ppuscrollX_in = reg_data_in;
                    last_write = reg_data_in;
                end else if(reg_en && reg_rw && scroll_wr_curr_state == SECOND_WRITE) begin 
                    scroll_wr_next_state = FIRST_WRITE;
                    ppuscrollY_in = reg_data_in;
                    last_write = reg_data_in;
                end
            end   
            PPUADDR: begin       // write twice
                if(reg_en && reg_rw && addr_wr_curr_state == FIRST_WRITE) begin 
                    addr_wr_next_state = SECOND_WRITE;
                    ppuaddr_in = {reg_data_in, ppuaddr_out[7:0]};
                    last_write = reg_data_in;
                end else if(reg_en && reg_rw && addr_wr_curr_state == SECOND_WRITE) begin 
                    addr_wr_next_state = FIRST_WRITE;
                    ppuaddr_in = {ppuaddr_out[15:8], reg_data_in};
                    last_write = reg_data_in;
                end
            end
            OAMDMA: begin        // write only
                if(reg_en && reg_rw) begin 
                    oamdma_in = reg_data_in;
                    last_write = reg_data_in;

                    begin_dma = 1'b1;
                end 
            end


            OAMDATA: begin     // read/write
                if(reg_en && reg_rw) begin 
                    /* write */
                    oam_we_reg = 1'b1;
                    oam_wr_data_reg = reg_data_in;
                    last_write = reg_data_in;
                end else if(reg_en && !reg_rw) begin
                    oam_re_reg = 1'b1;
                    reg_data_out_next = oam_rd_data;
                end
            end
            PPUDATA: begin     // read/write 
                if(reg_en && reg_rw) begin 
                    /* write */
                    last_write = reg_data_in;
                    if(16'h2000 <= ppuaddr_out && ppuaddr_out <= 16'h27ff) begin 
                        vram_we_reg = 1'b1;
                        vram_wr_data = reg_data_in;
                    end else if(16'h3000 <= ppuaddr_out && ppuaddr_out <= 16'h37ff) begin 
                        vram_we_reg = 1'b1;
                        vram_wr_data = reg_data_in;
                    end else if(16'h3f00 <= ppuaddr_out && ppuaddr_out <= 16'h3fff) begin 
                        pal_we_reg = 1'b1;
                        pal_wr_data = reg_data_in;
                    end 
                    // nametable 2 and 3 are in 0x2800 - 0x2FFF which are not used
                    // for mapper-0
                end else if(reg_en && !reg_rw) begin 
                    vram_re = 1'b1;
                    reg_data_out_next = vram_rd_data;
                end
            end


            PPUSTATUS: begin       // read only 
                if(reg_en && !reg_rw) begin 
                    reg_data_out_next = ppustatus_out;
                    ppustatus_rd_clr = 1'b1;
                end 
            end
            default : /* default */;
        endcase
    end

endmodule
