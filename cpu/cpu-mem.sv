`default_nettype none

module #(WIDTH=8, RESET_VAL=0) cpu_register(
    input  logic clock, clock_en, reset_n, data_en,
    intput logic[WIDTH-1:0] data_in,
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


module #(RESET_VAL=0) cpu_wide_counter_register(
    input  logic clock, clock_en, reset_n, inc_en,
    input  logic[1:0] data_en,
    intput logic[15:0] data_in,
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


module #(RESET_VAL=0) cpu_wide_write_thru_register(
    input  logic clock, clock_en, reset_n,
    input  logic[1:0] data_en,
    intput logic[15:0] data_in,
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
    input  logic reset_n
    output logic [7:0] r_data);

    // addr is latched
    // r_en and w_data are not latched
    // r_data is latched

    // FEDC_BA98_7654_3210

    logic clock_en;
    assign clock_en = 1'b1;

    logic [0:8191][7:0] ram;
    logic [0:7][7:0] ppu_regs;
    logic [0:31][7:0] io_regs;
    logic [16416:65535] cartridge_mem;

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n) begin
            ram <= 'b0;
            ppu_regs <= 'b0;
            io_regs <= 'b0;
            cartridge_mem <= 'b0;
        end
        else if (clock_en) begin
            if (addr < 16'h2000) begin
                if (r_en = 1'b1) begin
                    r_data <= ram[addr[6:0]];
                end
                else begin
                    ram[addr[6:0]] <= w_data;
                end
            end
            else if (addr < 16'h4000) begin
                if (r_en = 1'b1) begin
                    r_data <= ppu_regs[addr[2:0]];
                end
                else begin
                    ppu_regs[addr[2:0]] <= w_data;
                end
            end
            else if (addr < 16'h4020) begin
                if (r_en = 1'b1) begin
                    r_data <= io_regs[addr[4:0]];
                end
                else begin
                    io_regs[addr[4:0]] <= w_data;
                end
            end
            else begin
                if (r_en = 1'b1) begin
                    r_data <= cartridge_mem[addr];
                end
                else begin
                    cartridge_mem[addr] <= w_data;
                end
            end
        end
    end

endmodule : cpu_memory

module mem_inputs(
    input  instr_ctrl_signals_t instr_ctrl_vector,
    input  ucode_ctrl_signals_t ucode_vector,

    input processor_state_t state,

    input  logic[7:0] A, X, Y, SP, r_data, r_data_buffer, alu_out,
    input  logic[15:0] PC,
    input  logic n_flag, v_flag, d_flag, i_flag, z_flag, c_flag,
    
    output logic[15:0] addr,
    output logic[7:0] w_data,
    output logic mem_r_en,
    output logic[1:0] addr_en);

    always_comb begin

        addr = 16'b0;
        w_data = 8'b0;
        mem_r_en = 1'b1;
        addr_en = 2'b11;

        if (state == STATE_NEITHER) begin

            case (ucode_vector.addr_lo_src) begin
                // ADDRLO_FF, ADDRLO_FE, ADDRLO_FD, ADDRLO_FC, ADDRLO_FB, ADDRLO_FA, ADDRLO_PCLO, ADDRLO_RMEMBUFFER, ADDRLO_RMEM, ADDRLO_ALUOUT, ADDRLO_SP, ADDRLO_HOLD
                ADDRLO_FF: addr[7:0] = 8'hFF;
                ADDRLO_FE: addr[7:0] = 8'hFE;
                ADDRLO_FD: addr[7:0] = 8'hFD;
                ADDRLO_FC: addr[7:0] = 8'hFC;
                ADDRLO_FB: addr[7:0] = 8'hFB;
                ADDRLO_FA: addr[7:0] = 8'hFA;
                ADDRLO_PCLO: addr[7:0] = PC[7:0];
                ADDRLO_RMEMBUFFER: addr[7:0] = r_data_buffer;
                ADDRLO_RMEM: addr[7:0] = r_data;
                ADDRLO_ALUOUT: addr[7:0] = alu_out;
                ADDRLO_SP: addr[7:0] = SP;
                ADDRLO_HOLD: addr_en[0] = 1'b0;
            endcase

            case (ucode_vector.addr_hi_src) begin
                // ADDRHI_1, ADDRHI_0, ADDRHI_FF, ADDRHI_PCHI, ADDRHI_RMEM, ADDRHI_ALUOUT, ADDRHI_HOLD
                ADDRHI_1: addr[15:8] = 8'h1;
                ADDRHI_0: addr[15:8] = 8'h0;
                ADDRHI_FF: addr[15:8] = 8'hFF;
                ADDRHI_PCHI: addr[15:8] = PC[15:8];
                ADDRHI_RMEM: addr[15:8] = r_data;
                ADDRHI_ALUOUT: addr[15:8] = alu_out;
                ADDRHI_HOLD: addr_en[1] = 1'b0;
            endcase

            case (ucode_vector.r_en) begin
                // READ_EN_R, READ_EN_W, READ_EN_NONE
                READ_EN_R: mem_r_en = 1'b1;
                READ_EN_W: mem_r_en = 1'b0;
                READ_EN_NONE: mem_r_en = 1'b1;
            endcase
        
        end
        else begin
            // if in fetch or decode, r_en and addr_en are 1

            addr[7:0] = PC[7:0];

            if (ucode_vector.addr_hi_src == ADDRHI_RMEM) begin
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

        case (ucode_vector.write_mem_src)
            // WMEMSRC_PCHI, WMEMSRC_PCLO, WMEMSRC_STATUS_BS, WMEMSRC_STATUS_BC, WMEMSRC_INSTER_STORE, WMEMSRC_RMEM
            WMEMSRC_PCHI: w_data = PC[15:8];
            WMEMSRC_PCLO: w_data = PC[7:0];
            // NV-BDIZC
            WMEMSRC_STATUS_BS: {n_flag, v_flag, 1'b1, 1'b1, d_flag, i_flag, z_flag, c_flag};
            WMEMSRC_STATUS_BC: {n_flag, v_flag, 1'b1, 1'b0, d_flag, i_flag, z_flag, c_flag};
            WMEMSRC_INSTER_STORE: begin
                case (instr_ctrl_vector.store_reg)
                    // STORE_A, STORE_X, STORE_Y, STORE_STATUS
                    STORE_A: w_data = A;
                    STORE_X: w_data = X;
                    STORE_Y: w_data = Y;
                    // PHP -> b set
                    STORE_STATUS: {n_flag, v_flag, 1'b1, 1'b1, d_flag, i_flag, z_flag, c_flag};
                endcase
            end
            WMEMSRC_RMEM: w_data = r_data;
        endcase

    end

endmodule : mem_inputs