`default_nettype none
`include "../include/ppu_defines.vh"

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

    // mirroring
    input mirror_t mirroring, 

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

    // vram address connections
    output addr_t vAddr, 
    output logic [2:0] fX,

    input logic h_scroll, v_scroll, h_update, v_update,

    input logic rendering

);
    /////// ALL register definitions  ////////

    // write only
    logic [7:0] ppuctrl_in;
    logic [7:0] ppumask_in;
    logic [7:0] oamdma_out, oamdma_in;
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

    /////// Write Only Registers //////////
    logic ppustatus_rd_clr;

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            ppuctrl_out <= 8'd0;
            ppumask_out <= 8'd0;
            oamdma_out <= 8'd0;
            oamaddr_out <= 8'd0;
        end else if(cpu_clk_en) begin
            ppuctrl_out <= ppuctrl_in;
            ppumask_out <= ppumask_in;
            oamdma_out <= oamdma_in;
            oamaddr_out <= oamaddr_in;
        end
    end


    ///////////////////////// VRAM registers ////////////////////////////////  
    logic [15:0] vAddr_inc_amnt;
    
    addr_t tAddr;
    addr_t vAddr_in, tAddr_in; 
    logic [2:0] fX_in;

    logic vAddr_upd, tAddr_upd, fX_upd;

    assign vAddr_inc_amnt = (ppuctrl_out[2]) ? 16'd32 : 16'd1;

    vram_addr_register addr_reg(
        .clk(clk), .clk_en(ppu_clk_en), .rst_n(rst_n), 
        .vAddr, .tAddr, .fX, 
        // only update once per cpu cycle instead of 3 times since vAddr, tAddr, fX are clocked by ppu_clk_en
        .vAddr_upd(vAddr_upd && cpu_clk_en), .tAddr_upd(tAddr_upd && cpu_clk_en), .fX_upd(fX_upd && cpu_clk_en),
        .vAddr_in, .tAddr_in, .fX_in, 
        .h_scroll, .v_scroll, .h_update, .v_update,
        .rendering); 


    ////////// PPU VRAM address to read or write to /////////////
    logic vram_we_reg;
    assign vram_we = vram_we_reg;

    vram_mirroring vm(.addr({1'b0, vAddr.r}), .mirroring, .vram_addr);

    ////////// PAL ram address to read or write to //////////////
    logic pal_we_reg;
    assign pal_we = pal_we_reg; 

    always_comb begin
        case (vAddr.r[4:0])
            5'h10: pal_addr = 5'h00;
            5'h14: pal_addr = 5'h04;
            5'h18: pal_addr = 5'h08;
            5'h1C: pal_addr = 5'h0C;
            default : pal_addr = vAddr.r[4:0];
        endcase
    end

    ////////////////////// double writes ///////////////////////////////
    enum logic {
        FIRST_WRITE,
        SECOND_WRITE
    } wr_curr_state, wr_next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            wr_curr_state <= FIRST_WRITE;
        end else if(cpu_clk_en) begin
            wr_curr_state <= wr_next_state;
        end
    end

    ////////////////////////// read out register ////////////////////////////
    logic [7:0] reg_data_out_next;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            reg_data_out <= 8'd0;
        end else if(cpu_clk_en) begin
            reg_data_out <= reg_data_out_next;
        end
    end

    /////////////////////////// PPU data read buffer ////////////////////////
    logic [7:0] read_buf_curr, read_buf_next;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            read_buf_curr <= 8'd0;
        end else if(cpu_clk_en) begin
            read_buf_curr <= read_buf_next;
        end
    end

    //////////////////////////// READ ONLY registers //////////////////////////
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

    //////////////////////////// OAMDMA FSM ///////////////////////////////
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
        end else if(cpu_clk_en) begin
            oamdma_curr_state <= oamdma_next_state;
        end
    end

    logic [7:0] counter;
    logic counter_en, counter_clr;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            counter <= 8'd0;
        end else if(cpu_clk_en) begin
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
        cpu_re = 1'b1;

        // OAM write
        oam_we_dma = 1'b0;
        case (oamdma_curr_state)
            OAMDMA_IDLE: begin 
                oamdma_next_state = (begin_dma) ? OAMDMA_DUMMY1 : OAMDMA_IDLE;
                // cpu_sus = (begin_dma) ? 1'b1 : 1'b0;
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
        oamdma_in = oamdma_out;

        // vram registers
        vAddr_in = vAddr;
        tAddr_in = tAddr;
        fX_in = fX;

        vAddr_upd = 1'b0;
        tAddr_upd = 1'b0;
        fX_upd = 1'b0;

        // last write
        last_write = ppustatus_out;

        // mult writes 
        wr_next_state = (ppustatus_rd_clr) ? FIRST_WRITE : wr_curr_state;

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

        // ppu read buffer
        read_buf_next = read_buf_curr;

        // ppustatus read clear
        ppustatus_rd_clr = 1'b0;
        case (reg_sel)
            PPUCTRL: begin        // write only
                if(reg_en && reg_rw) begin 
                    // write ppuctrl register 
                    ppuctrl_in = reg_data_in;

                    // write nt bits of tAddr
                    tAddr_in.pixel_gran.nt = reg_data_in[1:0];
                    tAddr_upd = 1'b1;

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
                if(reg_en && reg_rw && wr_curr_state == FIRST_WRITE) begin 
                    wr_next_state = SECOND_WRITE;
                    // write fX
                    fX_in = reg_data_in[2:0];
                    fX_upd = 1'b1;

                    // write tAddr cX
                    tAddr_in.pixel_gran.cX = reg_data_in[7:3]; 
                    tAddr_upd = 1'b1;

                    last_write = reg_data_in;
                end else if(reg_en && reg_rw && wr_curr_state == SECOND_WRITE) begin 
                    wr_next_state = FIRST_WRITE;
                    // write tAddr fY
                    tAddr_in.pixel_gran.fY = reg_data_in[2:0];

                    // write tAddr cY
                    tAddr_in.pixel_gran.cY = reg_data_in[7:3]; 
                    tAddr_upd = 1'b1;

                    last_write = reg_data_in;
                end
            end   
            PPUADDR: begin       // write twice
                if(reg_en && reg_rw && wr_curr_state == FIRST_WRITE) begin 
                    wr_next_state = SECOND_WRITE;
                    // write tAddr h
                    tAddr_in.split.h = reg_data_in[6:0]; 
                    tAddr_upd = 1'b1;

                    last_write = reg_data_in;
                end else if(reg_en && reg_rw && wr_curr_state == SECOND_WRITE) begin 
                    wr_next_state = FIRST_WRITE;
                    // write tAddr l
                    tAddr_in.split.l = reg_data_in[7:0]; 
                    tAddr_upd = 1'b1;

                    // write vAddr
                    vAddr_in.split.l = reg_data_in[7:0];
                    vAddr_in.split.h = tAddr_in.split.h;
                    vAddr_upd = 1'b1;

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
                    oamaddr_in = oamaddr_out + 8'd1;
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
                    vAddr_in = vAddr + vAddr_inc_amnt;
                    vAddr_upd = 1'b1;
                    last_write = reg_data_in;

                    if(14'h0000 <= vAddr.r[13:0] && vAddr.r[13:0] <= 14'h1FFF) begin 
                        // CHR RAM
                        
                    end else if(14'h2000 <= vAddr.r[13:0] && vAddr.r[13:0] <= 14'h3EFF) begin 
                        // NT RAM
                        vram_we_reg = 1'b1;
                        vram_wr_data = reg_data_in;
                    end else if(14'h3f00 <= vAddr.r[13:0] && vAddr.r[13:0] <= 14'h3fff) begin 
                        // PAL RAM
                        pal_we_reg = 1'b1;
                        pal_wr_data = reg_data_in;
                    end 
                end else if(reg_en && !reg_rw) begin 
                    /* read */
                    vAddr_in = vAddr + vAddr_inc_amnt;
                    vAddr_upd = 1'b1;

                    if(14'h0000 <= vAddr.r[13:0] && vAddr.r[13:0] <= 14'h1FFF) begin 
                        
                    end else if(14'h2000 <= vAddr.r[13:0] && vAddr.r[13:0] <= 14'h3EFF) begin 
                        vram_re = 1'b1;
                        read_buf_next = vram_rd_data;
                        reg_data_out_next = read_buf_curr;
                    end else if(14'h3f00 <= vAddr.r[13:0] && vAddr.r[13:0] <= 14'h3fff) begin 
                        pal_re = 1'b1;
                        reg_data_out_next = pal_rd_data;
                    end
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


// this was more useful than NES dev for these compilcated bit manipulations
// https://github.com/AndreaOrru/LaiNES/blob/master/src/ppu.cpp
module vram_addr_register (
    input clk,    // Clock
    input clk_en, // Clock Enable
    input rst_n,  // Asynchronous reset active low
    
    output addr_t vAddr, tAddr, 
    output logic [2:0] fX,

    // standard update of register
    input logic vAddr_upd, tAddr_upd, fX_upd,

    input addr_t vAddr_in, tAddr_in, 
    input logic [2:0] fX_in,

    // more complex commands
    input logic h_scroll, v_scroll, h_update, v_update,

    // is ppu rendering
    input logic rendering
);

    // fX register
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            fX <= 3'd0;
        end else if(clk_en && fX_upd) begin
            fX <= fX_in;
        end
    end

    // tAddr register
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            tAddr <= 15'd0;
        end else if(clk_en && tAddr_upd) begin
            tAddr <= tAddr_in;
        end
    end

    // vAddr register
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            vAddr <= 15'd0;
        end else if(clk_en) begin
            if(vAddr_upd) begin
                vAddr <= vAddr_in;
            end else if(rendering && h_scroll) begin
                if(vAddr.pixel_gran.cX == 5'd31) begin 
                    vAddr.r <= vAddr.r ^ 15'h41F;
                end else begin 
                    vAddr.pixel_gran.cX <= vAddr.pixel_gran.cX + 5'd1;
                end
            end else if(rendering && v_scroll) begin
                if(vAddr.pixel_gran.fY < 3'd7) begin 
                    vAddr.pixel_gran.fY <= vAddr.pixel_gran.fY + 3'd1;
                end else begin 
                    vAddr.pixel_gran.fY <= 5'd0;
                    if (vAddr.pixel_gran.cY == 5'd31)
                        vAddr.pixel_gran.cY <= 5'd0;
                    else if (vAddr.pixel_gran.cY == 5'd29) begin  
                        vAddr.pixel_gran.cY <= 5'd0; 
                        vAddr.pixel_gran.nt <= vAddr.pixel_gran.nt ^ 2'b10;
                    end 
                    else begin
                        vAddr.pixel_gran.cY <= vAddr.pixel_gran.cY + 5'd1;
                    end
                end
            end else if(rendering && h_update) begin
                vAddr.r <= (vAddr.r & ~15'h041F) | (tAddr.r & 15'h041F);
            end else if(rendering && v_update) begin
                vAddr.r <= (vAddr.r & ~15'h7BE0) | (tAddr.r & 15'h7BE0); 
            end
        end
    end

endmodule