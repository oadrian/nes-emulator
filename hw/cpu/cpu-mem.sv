`default_nettype none
`include "../include/ppu_defines.vh"

`define SYNTH
`ifdef NO_SYNTH
`undef SYNTH
`endif

`define prg_rom_init

`define CTRL_PULSE_LEN 3

module cpu_register #(WIDTH=8, RESET_VAL=0, SAVE_STATE_ADDR=0) (
    input  logic clock, clock_en, reset_n, data_en,
    input  logic[WIDTH-1:0] data_in,
    input  logic save_state_load_en,
    input  logic[15:0] save_state_load_data,
    input  logic[`SAVE_STATE_BITS-1:0] save_state_addr,
    output logic[WIDTH-1:0] data_out);

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n) begin
            data_out <= RESET_VAL;
        end
        if (save_state_load_en && save_state_addr == SAVE_STATE_ADDR) begin
            data_out <= save_state_load_data[WIDTH-1:0];
        end
        else if (clock_en && data_en) begin
            data_out <= data_in;
        end
    end

endmodule : cpu_register


module cpu_wide_counter_register #(RESET_VAL=0, SAVE_STATE_ADDR=0) (
    input  logic clock, clock_en, reset_n, inc_en,
    input  logic[1:0] data_en,
    input  logic[15:0] data_in,
    input  logic save_state_load_en,
    input  logic[15:0] save_state_load_data,
    input  logic[`SAVE_STATE_BITS-1:0] save_state_addr,
    output logic[15:0] data_out);

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n) begin
            data_out <= RESET_VAL;
        end
        if (save_state_load_en && save_state_addr == SAVE_STATE_ADDR) begin
            data_out <= save_state_load_data;
        end
        else if (clock_en) begin
            case (data_en)
                2'b00: data_out <= data_out + {15'b0, inc_en};
                2'b01: data_out <= {data_out[15:8], data_in[7:0]} + {15'b0, inc_en};
                2'b10: data_out <= {data_in[15:8], data_out[7:0]} + {15'b0, inc_en};
                2'b11: data_out <= data_in + {15'b0, inc_en};
            endcase
        end
    end

endmodule : cpu_wide_counter_register


module cpu_wide_write_thru_register #(RESET_VAL=0, SAVE_STATE_ADDR=0) (
    input  logic clock, clock_en, reset_n,
    input  logic[1:0] data_en,
    input  logic[15:0] data_in,
    input  logic save_state_load_en,
    input  logic[15:0] save_state_load_data,
    input  logic[`SAVE_STATE_BITS-1:0] save_state_addr,
    output logic[15:0] data_out,
    output logic[15:0] data_val);

    always_comb begin
        data_out = data_val;
        if (data_en[0]) begin
            data_out[7:0] = data_in[7:0];
        end
        if (data_en[1]) begin
            data_out[15:8] = data_in[15:8];
        end
    end

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n) begin
            data_val <= RESET_VAL;
        end
        if (save_state_load_en && save_state_addr == SAVE_STATE_ADDR) begin
            data_val <= save_state_load_data;
        end
        else if (clock_en) begin
            data_val <= data_out;
        end
    end

endmodule : cpu_wide_write_thru_register


module cpu_memory(
    input  logic [15:0] addr,
    input  logic r_en,
    input  logic [7:0] w_data,
    input  logic clock,
    input  logic clock_en, 
    input  logic reset_n,
    output logic [7:0] r_data,

    // PPU register interface
    
    output reg_t reg_sel,
    output logic reg_en,
    output logic reg_rw,
    output logic [7:0] reg_data_wr,
    input logic [7:0] reg_data_rd,

    // APU register interface 
    output logic [4:0] reg_addr,
    output logic [7:0] reg_write_data,
    input logic [7:0] reg_read_data,
    output logic data_valid, reg_we,

    output logic [15:0] direct_addr,
    output logic [7:0] direct_data_in,
    output logic direct_we,

    input logic dmc_re,
    input logic [14:0] dmc_addr,
    output logic [7:0] dmc_read_data,
	 
	 // Controller GPIO pins
     input logic ctlr_data_p1, ctlr_data_p2, 
     output logic ctlr_pulse_p1, ctlr_pulse_p2, ctlr_latch,
	 
	 // debug output
	 output logic [7:0] read_prom,

     // save state
     output logic [15:0] svst_state_read_data,
     
     input  logic svst_state_write_en, svst_state_read_en, 
     input  logic [`SAVE_STATE_BITS-1:0] svst_state_addr,
     input  logic [15:0] svst_state_write_data,

      // write prg rom
    input logic [14:0] prom_wr_addr,
    input logic prom_we,
    input logic [7:0] prom_wr_data
    );

    logic save_state_active;
    assign save_state_active = svst_state_write_en | svst_state_read_en;
    logic prev_apu_read;

    always_ff @(posedge clock or negedge reset_n)
      if (~reset_n)
        prev_apu_read <= 1'b0;
      else if (svst_state_write_en && svst_state_addr == `SAVE_STATE_CPU_MEM_PREV_APU_RD) begin
        prev_apu_read <= svst_state_write_data[0];
      end
      else if (clock_en & (addr == 16'h4015))
        prev_apu_read <= 1'b1;
      else if (clock_en)
        prev_apu_read <= 1'b0;

    // TODO: HOOK UP APU READS
    // Driving APU registers
    always_comb begin
        reg_addr = addr[4:0];
        reg_write_data = w_data;
        reg_we = ~r_en;
        data_valid = 16'h4000 <= addr && addr <= 16'h4017;

        direct_addr = addr;
        direct_data_in = w_data;
        direct_we = reg_we;
    end

    // prev reg_en
    logic prev_reg_en, prev_but_rd;
    always_ff @(posedge clock or negedge reset_n) begin
        if(~reset_n) begin
            prev_reg_en <= 0;
            prev_but_rd <= 0;
        end
        else if (svst_state_write_en) begin
            if (svst_state_addr == `SAVE_STATE_CPU_MEM_PREV_REG_EN) begin
                prev_reg_en <= svst_state_write_data[0];
            end else if (svst_state_addr == `SAVE_STATE_CPU_MEM_PREV_BUT_RD) begin
                prev_but_rd <= svst_state_write_data[0];
            end
        end else if(clock_en) begin
            prev_reg_en <= reg_en;
            prev_but_rd <= r_en && (addr == 16'h4016 || addr == 16'h4017);
        end
    end
    
    // PPU regsiter interface
    assign reg_rw = ~r_en;  // if r_en - 0 read, re_n - 1 writes
    assign reg_data_wr = w_data;

    always_comb begin
        reg_sel = PPUCTRL;
        reg_en = 1'b0;
        if(addr[15:12] == 4'h2 || addr[15:12] == 4'h3) begin 
            reg_en = 1'b1;
            case (addr[2:0]) 
                3'h0: reg_sel = PPUCTRL;
                3'h1: reg_sel = PPUMASK;
                3'h2: reg_sel = PPUSTATUS;
                3'h3: reg_sel = OAMADDR;
                3'h4: reg_sel = OAMDATA;
                3'h5: reg_sel = PPUSCROLL;
                3'h6: reg_sel = PPUADDR;
                3'h7: reg_sel = PPUDATA;
                default : /* default*/;
            endcase
        end else if(addr == 16'h4014) begin 
            reg_en = 1'b1;
            reg_sel = OAMDMA;
        end
    end

	// Controller interface
    logic [7:0] button_data_rd; 
    ctlr_interface ctrlr(.clock, .reset_n, .clock_en, .save_state_active,
                         .addr, .r_en, .w_data,
                         .ctlr_data_p1, .ctlr_data_p2,
                         .ctlr_pulse_p1, .ctlr_pulse_p2, .ctlr_latch, 
                         .button_data_rd);
	 
    // RD Data MUX
	 logic [7:0] mem_data_rd;
	 
	 always_comb begin
		r_data = mem_data_rd;
		if(prev_but_rd) 
			r_data = button_data_rd;
		else if(prev_reg_en) 
			r_data = reg_data_rd;
		else if (prev_apu_read)
			r_data = reg_read_data;
	 end
	 

`ifdef SYNTH
    logic [14:0] prom_address;
    logic prom_rden;
    logic [7:0] prom_data_rd;


    logic [7:0] dmc_rom_data;

    dmc_rom dm_rom (
      .address(dmc_addr), .clock, .q(dmc_rom_data));
    prg_ram prom(.address(prom_address), .clock,  
                 .data(prom_wr_data), .wren(prom_we),
                 .q(prom_data_rd));

    assign prom_rden = (addr[15] == 1'b1 && r_en);
    assign prom_address = (prom_we) ? prom_wr_addr : addr[14:0];

    assign read_prom = prom_data_rd;

    logic [10:0]  cram_address;
    logic [7:0]  cram_data_wr;
    logic cram_rden;
    logic cram_wren;
    logic  [7:0]  cram_data_rd;

    cram cmem(.address(cram_address), .clock,
              .data(cram_data_wr),
              .wren(cram_wren), .q(cram_data_rd));

    assign prom_rden = (addr[15] == 1'b1 && r_en);
    assign prom_address = addr[14:0];

    assign read_prom = prom_data_rd;
        
    always_comb begin
        cram_wren = 1'b0;
        cram_rden = 1'b0;
        cram_address = addr[10:0];
        cram_data_wr = w_data;
        
        if (svst_state_write_en || svst_state_read_en) begin
            if (svst_state_addr >= `SAVE_STATE_CPU_MEM_CPU_RAM_LO && 
                svst_state_addr <= `SAVE_STATE_CPU_MEM_CPU_RAM_HI) begin
                cram_address = svst_state_addr - `SAVE_STATE_CPU_MEM_CPU_RAM_LO;
                if (svst_state_write_en) begin
                    cram_wren = 1'b1;
                    cram_data_wr = svst_state_write_data[7:0];
                end
            end
        end
        
        else begin
            cram_rden = (16'h0000 <= addr && addr < 16'h2000 && r_en);
            cram_wren = (16'h0000 <= addr && addr < 16'h2000 && !r_en);
        end
    end

    always_ff @(posedge clock, negedge reset_n) begin
        if (reset_n) begin
            svst_state_read_data <= 16'b0;
        end
        else begin
            case (svst_state_addr)
                `SAVE_STATE_CPU_MEM_READ_DATA : svst_state_read_data <= {8'b0, mem_data_rd};
                `SAVE_STATE_CPU_MEM_PREV_REG_EN : svst_state_read_data <= {15'b0, prev_reg_en};
                `SAVE_STATE_CPU_MEM_PREV_BUT_RD : svst_state_read_data <= {15'b0, prev_but_rd};
                `SAVE_STATE_CPU_MEM_PREV_APU_RD : svst_state_read_data <= {15'b0, prev_apu_read};
                default : svst_state_read_data <= {8'b0, cram_data_rd};
            endcase
        end
    end
    
    always_ff @(posedge clock or negedge reset_n) begin
        if(~reset_n) begin
            mem_data_rd <= 8'd0;
            dmc_read_data <= 8'b0;
        end else if (svst_state_write_en && 
                     svst_state_addr == `SAVE_STATE_CPU_MEM_READ_DATA) begin
                mem_data_rd <= svst_state_write_data[7:0];
        end else if(clock_en) begin
            if(cram_rden) begin 
                mem_data_rd <= cram_data_rd;
            end else if(prom_rden) begin
                mem_data_rd <= prom_data_rd;
            end
            if (dmc_re)
                dmc_read_data <= dmc_rom_data;
        end
    end

`else 

    logic [7:0] ram [2047:0];
    logic [7:0] ppu_regs[7:0];
    logic [7:0] io_regs[31:0];
    logic [7:0] cartridge_mem [65535:16416];

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n) begin
            for (int i = 0; i < 2048; i++) begin
                ram[i] <= 8'd0;
            end
            for (int i = 0; i < 8; i++) begin
                ppu_regs[i] <= 8'd0;
            end
            for (int i = 0; i < 32; i++) begin
                io_regs[i] <= 8'd0;
            end
            `ifdef prg_rom_init
                for (int i = 16416; i < 32768; i++) begin
                    cartridge_mem[i] <= 8'd0;
                end
                $readmemh("../init/prg_rom_init.txt", cartridge_mem, 32768, 65535);
            `else
                for (int i = 16416; i < 65536; i++) begin
                    cartridge_mem[i] <= 8'd0;
                end
            `endif 
            mem_data_rd <= 8'd0;
        end

        // save_states taking over control of memory
        else if (svst_state_write_en || svst_state_read_en) begin
            if (svst_state_addr >= `SAVE_STATE_CPU_MEM_CPU_RAM_LO && 
                svst_state_addr <= `SAVE_STATE_CPU_MEM_CPU_RAM_HI) begin
                if (svst_state_write_en) begin
                    ram[svst_state_addr - `SAVE_STATE_CPU_MEM_CPU_RAM_LO] <= svst_state_write_data;
                end
                else begin
                    svst_state_read_data <= ram[svst_state_addr - `SAVE_STATE_CPU_MEM_CPU_RAM_LO];
                end
            end
            else if (svst_state_addr == `SAVE_STATE_CPU_MEM_READ_DATA) begin
                if (svst_state_write_en) begin
                    mem_data_rd <= svst_state_write_data[7:0];
                end
                else begin
                    svst_state_read_data <= {8'b0, mem_data_rd};
                end
            end
            else if (svst_state_addr == `SAVE_STATE_CPU_MEM_PREV_REG_EN && svst_state_read_en) begin
                svst_state_read_data <= {15'b0, prev_reg_en};
            end 
            else if (svst_state_addr == `SAVE_STATE_CPU_MEM_PREV_BUT_RD && svst_state_read_en) begin
                svst_state_read_data <= {15'b0, prev_but_rd};
            end
            else if (svst_state_addr == `SAVE_STATE_CPU_MEM_PREV_APU_RD && svst_state_read_en) begin
                svst_state_read_data <= {15'b0, prev_apu_read};
            end
        end

        else if (clock_en) begin
            if (addr < 16'h2000) begin
                if (r_en == 1'b1) begin
                    mem_data_rd <= ram[addr[10:0]];
                end
                else begin
                    ram[addr[10:0]] <= w_data;
                end
            end
            else if (addr < 16'h4000) begin
                if (r_en == 1'b1) begin
                    mem_data_rd <= ppu_regs[addr[2:0]];
                end
                else begin
                    ppu_regs[addr[2:0]] <= w_data;
                end
            end
            else if (addr < 16'h4020) begin
                if (r_en == 1'b1) begin
                    mem_data_rd <= io_regs[addr[4:0]];
                end
                else begin
                    io_regs[addr[4:0]] <= w_data;
                end
            end
            else begin
                if (r_en == 1'b1) begin
                    mem_data_rd <= cartridge_mem[addr];
                end
                else begin
                    cartridge_mem[addr] <= w_data;
                end
            end
        end
    end
`endif

endmodule : cpu_memory

module ctlr_interface (
    input clock,    // Clock
    input clock_en, // Clock Enable
    input reset_n,  // Asynchronous reset active low

    // cpu 
    input  logic [15:0] addr,
    input  logic r_en,
    input  logic save_state_active,
    input  logic [7:0] w_data,

    // GPIO Pins
    input logic ctlr_data_p1, ctlr_data_p2, 
    output logic ctlr_pulse_p1, ctlr_pulse_p2, ctlr_latch,

    // button_data_rd
    output logic [7:0] button_data_rd
);

    logic [7:0] button_data_rd_in;
    logic next_pulse_p1, next_pulse_p2, next_latch;

    always_ff @(posedge clock or negedge reset_n) begin
        if(!reset_n || save_state_active) begin
            button_data_rd <= 8'd0;
            ctlr_pulse_p1 <= 1'b1;
            ctlr_pulse_p2 <= 1'b1;
            ctlr_latch <= 1'b0;
        end else if(clock_en) begin
            button_data_rd <= button_data_rd_in;
            ctlr_pulse_p1 <= next_pulse_p1;
            ctlr_pulse_p2 <= next_pulse_p2;
            ctlr_latch <= next_latch;
        end
    end

    assign button_data_rd_in = (addr == 16'h4016) ? {7'b0, ~ctlr_data_p1} : {7'b0, ~ctlr_data_p2};

    assign next_latch = (addr == 16'h4016 && !r_en) ? w_data[0] : ctlr_latch;

    assign next_pulse_p1 = (addr == 16'h4016 && r_en) ? 1'b0 : 1'b1;
    assign next_pulse_p2 = (addr == 16'h4017 && r_en) ? 1'b0 : 1'b1;

endmodule

module mem_inputs(
    input  instr_ctrl_signals_t instr_ctrl_vector,
    input  ucode_ctrl_signals_t ucode_vector,

    input processor_state_t state,

    input  logic[7:0] A, X, Y, SP, r_data, r_data_buffer, alu_out,
    input  logic[15:0] PC,
    input  logic n_flag, v_flag, d_flag, i_flag, z_flag, c_flag,

    input  logic interrupt_active, reset_active,
    input  interrupt_t curr_interrupt,
    
    output logic[15:0] addr,
    output logic[7:0] w_data,
    output logic mem_r_en,
    output logic[1:0] addr_en);

    always_comb begin

        addr = 16'b0;
        mem_r_en = 1'b1;
        addr_en = 2'b11;

        if (state == STATE_NEITHER) begin

            case (ucode_vector.addr_lo_src)
                // ADDRLO_FF, ADDRLO_FE, ADDRLO_FD, ADDRLO_FC, ADDRLO_FB, ADDRLO_FA, ADDRLO_PCLO, ADDRLO_RMEMBUFFER, ADDRLO_RMEM, ADDRLO_ALUOUT, ADDRLO_SP, ADDRLO_HOLD
                ADDRLO_BRKLO: begin
                    case (curr_interrupt)
                        //INTERRUPT_NONE, INTERRUPT_NMI, INTERRUPT_IRQ, INTERRUPT_RESET
                        INTERRUPT_NONE:  addr[7:0] = 8'hFE;
                        INTERRUPT_NMI:   addr[7:0] = 8'hFA;
                        INTERRUPT_IRQ:   addr[7:0] = 8'hFE;
                        INTERRUPT_RESET: addr[7:0] = 8'hFC;
                    endcase
                end
                ADDRLO_BRKHI: begin
                    case (curr_interrupt)
                        //INTERRUPT_NONE, INTERRUPT_NMI, INTERRUPT_IRQ, INTERRUPT_RESET
                        INTERRUPT_NONE:  addr[7:0] = 8'hFF;
                        INTERRUPT_NMI:   addr[7:0] = 8'hFB;
                        INTERRUPT_IRQ:   addr[7:0] = 8'hFF;
                        INTERRUPT_RESET: addr[7:0] = 8'hFD;
                    endcase
                end
                ADDRLO_FD: addr[7:0] = 8'hFD;
                ADDRLO_FC: addr[7:0] = 8'hFC;
                ADDRLO_PCLO: addr[7:0] = PC[7:0];
                ADDRLO_RMEMBUFFER: addr[7:0] = r_data_buffer;
                ADDRLO_RMEM: addr[7:0] = r_data;
                ADDRLO_ALUOUT: addr[7:0] = alu_out;
                ADDRLO_SP: addr[7:0] = SP;
                ADDRLO_HOLD: addr_en[0] = 1'b0;
            endcase

            case (ucode_vector.addr_hi_src)
                // ADDRHI_1, ADDRHI_0, ADDRHI_FF, ADDRHI_PCHI, ADDRHI_RMEM, ADDRHI_ALUOUT, ADDRHI_HOLD
                ADDRHI_1: addr[15:8] = 8'h1;
                ADDRHI_0: addr[15:8] = 8'h0;
                ADDRHI_FF: addr[15:8] = 8'hFF;
                ADDRHI_PCHI: addr[15:8] = PC[15:8];
                ADDRHI_RMEM: addr[15:8] = r_data;
                ADDRHI_ALUOUT: addr[15:8] = alu_out;
                ADDRHI_HOLD: addr_en[1] = 1'b0;
            endcase

            case (ucode_vector.r_en)
                // READ_EN_R, READ_EN_W, READ_EN_NONE
                READ_EN_R: mem_r_en = 1'b1;
                READ_EN_W: mem_r_en = 1'b0;
                READ_EN_NONE: mem_r_en = 1'b1;
            endcase
        
        end
        else begin
            // if in fetch or decode, r_en and addr_en are 1

            addr[7:0] = PC[7:0];

            if (ucode_vector.addr_hi_src == ADDRHI_RMEM ||
                ucode_vector.pchi_src == PCHISRC_RMEM) begin
                addr[15:8] = r_data;
            end
            else begin
                addr[15:8] = PC[15:8];
            end
        end

        // if we're in the reset vector we always just read
        if (reset_active) begin
            mem_r_en = 1'b1;
        end

    end

    always_comb begin
        w_data = 8'b0;
        
        if (ucode_vector.instr_ctrl == INSTR_CTRL_2 &&
            instr_ctrl_vector.alu_out_dst == ALUDST_WMEM) begin
            w_data = alu_out;
        end

        else begin
            case (ucode_vector.write_mem_src)
                // WMEMSRC_PCHI, WMEMSRC_PCLO, WMEMSRC_STATUS_BS, WMEMSRC_STATUS_BC, WMEMSRC_INSTER_STORE, WMEMSRC_RMEM
                WMEMSRC_PCHI: w_data = PC[15:8];
                WMEMSRC_PCLO: w_data = PC[7:0];
                // NV-BDIZC
                WMEMSRC_STATUS_BRK: begin
                    if (interrupt_active) begin
                        w_data = {n_flag, v_flag, 1'b1, 1'b0, d_flag, i_flag, z_flag, c_flag};
                    end
                    else begin
                        w_data = {n_flag, v_flag, 1'b1, 1'b1, d_flag, i_flag, z_flag, c_flag};
                    end
                end
                WMEMSRC_STATUS_BC: w_data = {n_flag, v_flag, 1'b1, 1'b0, d_flag, i_flag, z_flag, c_flag};
                WMEMSRC_INSTR_STORE: begin
                    case (instr_ctrl_vector.store_reg)
                        // STORE_A, STORE_X, STORE_Y, STORE_STATUS
                        STORE_A: w_data = A;
                        STORE_X: w_data = X;
                        STORE_Y: w_data = Y;
                        // PHP -> b set
                        STORE_STATUS: w_data = {n_flag, v_flag, 1'b1, 1'b1, d_flag, i_flag, z_flag, c_flag};
                    endcase
                end
                WMEMSRC_RMEM: w_data = r_data;
            endcase
        end

    end

endmodule : mem_inputs
