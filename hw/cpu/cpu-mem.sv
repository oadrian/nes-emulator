`default_nettype none
`include "../include/ppu_defines.vh"

`define SYNTH
`ifdef NO_SYNTH
`undef SYNTH
`endif

`define prg_rom_init

module cpu_register #(WIDTH=8, RESET_VAL=0) (
    input  logic clock, clock_en, reset_n, data_en,
    input logic[WIDTH-1:0] data_in,
    output logic[WIDTH-1:0] data_out);

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n) begin
            data_out <= RESET_VAL;
        end
        else if (clock_en && data_en) begin
            data_out <= data_in;
        end
    end

endmodule : cpu_register


module cpu_wide_counter_register #(RESET_VAL=0) (
    input  logic clock, clock_en, reset_n, inc_en,
    input  logic[1:0] data_en,
    input logic[15:0] data_in,
    output logic[15:0] data_out);

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n) begin
            data_out <= RESET_VAL;
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


module cpu_wide_write_thru_register #(RESET_VAL=0) (
    input  logic clock, clock_en, reset_n,
    input  logic[1:0] data_en,
    input logic[15:0] data_in,
    output logic[15:0] data_out);

    logic [15:0] data_val;

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
	 
	 // press start
	 input logic pressed_start,
	 
	 // debug output
	 output logic [7:0] read_prom
    
    );

    // prev reg_en
    logic prev_reg_en;
    always_ff @(posedge clock or negedge reset_n) begin
        if(~reset_n) begin
            prev_reg_en <= 0;
        end else if(clock_en) begin
            prev_reg_en <= reg_en;
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

    //assign r_data = (prev_reg_en) ? reg_data_rd : mem_data_rd;
	 
	 /// debug press the start button
	 
	 logic [7:0] button_data_rd, button_data_rd_in;
	 enum logic [2:0] {IDLE, WROTE1, WROTE0, READ_A, READ_B, READ_SEL, READ_START} curr, next;
	 
	 logic [7:0] mem_data_rd;
	 
	 always_comb begin
		r_data = mem_data_rd;
		if(curr == READ_START) 
			r_data = button_data_rd;
		else if(prev_reg_en) 
			r_data = reg_data_rd;
		else
			r_data = mem_data_rd;
	 end
	 
	 always_ff @(posedge clock or negedge reset_n) begin
		if(~reset_n) begin
			curr <= IDLE;
			button_data_rd <= 8'd0;
		end else if(clock_en) begin
			curr <= next;
			button_data_rd <= button_data_rd_in;
		end
	 end
	 
	 always_comb begin
		next = IDLE;
		button_data_rd_in = 8'd0;
		case(curr)
			IDLE: begin
				next = (!r_en && addr == 16'h4016 && w_data[0] == 1'b1) ? WROTE1 : IDLE;
			end
			WROTE1: begin
				next = (!r_en && addr == 16'h4016 && w_data[0] == 1'b0) ? WROTE0 : WROTE1;
			end
			WROTE0: begin
				next = (r_en && addr == 16'h4016) ? READ_A : WROTE0;
			end
			READ_A: begin
				next = (r_en && addr == 16'h4016) ? READ_B : READ_A;
			end
			READ_B: begin
				next = (r_en && addr == 16'h4016) ? READ_SEL : READ_B;
			end
			READ_SEL: begin
				next = (r_en && addr == 16'h4016) ? READ_START : READ_SEL;
				button_data_rd_in = (pressed_start) ? 8'd1 : 8'd0;
			end
			READ_START: begin
				next = IDLE;
			end
			default: ;
		endcase
	 
	 end

    `ifdef SYNTH
    logic [13:0] prom_address;
    logic prom_rden;
    logic [7:0] prom_data_rd;

    prg_rom_16 prom(.address(prom_address), .clock,  .q(prom_data_rd));

    logic [10:0]  cram_address;
    logic [7:0]  cram_data_wr;
    logic cram_rden;
    logic cram_wren;
    logic  [7:0]  cram_data_rd;

    cram cmem(.address(cram_address), .clock,
              .data(cram_data_wr),
              .wren(cram_wren), .q(cram_data_rd));

    assign prom_rden = (addr[15:14] == 2'b11 && r_en);
    assign prom_address = addr[13:0];

//	assign prom_rden = 1'b1;
//	assign prom_address = 14'd0;
	assign read_prom = prom_data_rd;

    assign cram_rden = (16'h0000 <= addr && addr < 16'h2000 && r_en);
    assign cram_wren = (16'h0000 <= addr && addr < 16'h2000 && !r_en);
    assign cram_address = addr[10:0];
    assign cram_data_wr = w_data;

    always_ff @(posedge clock or negedge reset_n) begin
        if(~reset_n) begin
            mem_data_rd <= 8'd0;
        end else if(clock_en) begin
            if(cram_rden) begin 
                mem_data_rd <= cram_data_rd;
            end else if(prom_rden) begin
                mem_data_rd <= prom_data_rd;
            end
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
                for (int i = 16416; i < 49152; i++) begin
                    cartridge_mem[i] <= 8'd0;
                end
                $readmemh("init/prg_rom_init.txt", cartridge_mem, 49152, 65535);
            `else
                for (int i = 16416; i < 65536; i++) begin
                    cartridge_mem[i] <= 8'd0;
                end
            `endif 
            mem_data_rd <= 8'd0;
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

module mem_inputs(
    input  instr_ctrl_signals_t instr_ctrl_vector,
    input  ucode_ctrl_signals_t ucode_vector,

    input processor_state_t state,

    input  logic[7:0] A, X, Y, SP, r_data, r_data_buffer, alu_out,
    input  logic[15:0] PC,
    input  logic n_flag, v_flag, d_flag, i_flag, z_flag, c_flag,

    input  logic nmi_active,
    
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
                    if (nmi_active) begin
                        addr[7:0] = 8'hFA;
                    end
                    else begin
                        addr[7:0] = 8'hFE;
                    end
                end
                ADDRLO_BRKHI: begin
                    if (nmi_active) begin
                        addr[7:0] = 8'hFB;
                    end
                    else begin
                        addr[7:0] = 8'hFF;
                    end
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
                WMEMSRC_STATUS_BRK: w_data = (nmi_active) ? {n_flag, v_flag, 1'b1, 1'b0, d_flag, i_flag, z_flag, c_flag} : {n_flag, v_flag, 1'b1, 1'b1, d_flag, i_flag, z_flag, c_flag};
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