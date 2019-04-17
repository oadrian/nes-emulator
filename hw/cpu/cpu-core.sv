`default_nettype none
`include "../include/cpu_types.vh"
`include "../include/ucode_ctrl.vh"

`define DEFAULT_SP 8'hFD

`define DEFAULT_N 1'b0
`define DEFAULT_V 1'b0
`define DEFAULT_D 1'b0
`define DEFAULT_I 1'b1
`define DEFAULT_Z 1'b0
`define DEFAULT_C 1'b0

// `define DEFAULT_PC 16'h4020

`define DEFAULT_PC 16'hC000

module core(
    output logic [15:0] addr,
    output logic mem_r_en,
    output logic [7:0] w_data,
    input  logic nmi,
    input  logic [7:0] r_data,
    input  logic clock_en,
    input  logic clock,
    input  logic reset_n,
    input  logic irq_n,

    // debug
    output logic [15:0] PC_debug);

    //assign clock_en = 1'b1;

    // roms
    logic rom_en;

    logic [0:255][5:0] instr_ctrl_signals_indices;
    instr_ctrl_signals_t [0:`INSTR_CTRL_SIZE-1] instr_ctrl_signals_rom;

    logic [0:255][7:0] ucode_ctrl_signals_indices;
    ucode_ctrl_signals_t [0:`UCODE_ROM_SIZE-1] ucode_ctrl_signals_rom;

    logic [0:255][1:0] decode_ctrl_signals_rom;


    // state and ctrl signals
    processor_state_t state;
    logic [7:0] ucode_index;
    logic [5:0] instr_ctrl_index;
    logic decode_inc_pc, decode_start_fetch;
    instr_ctrl_signals_t instr_ctrl_vector;
    ucode_ctrl_signals_t ucode_vector;

    processor_state_t next_state;
    logic [7:0] next_ucode_index;
    logic [5:0] next_instr_ctrl_index;
    logic instr_ctrl_index_en, state_en, ucode_index_en;

    logic nmi_active, nmi_active_en, next_nmi_active;
    logic reset_active, reset_active_en, next_reset_active;
    logic interrupt_active;

    logic curr_interrupt_en;
    interrupt_t curr_interrupt, next_interrupt;

    logic [7:0] opcode;


    // architecture signals
    logic [15:0] PC;
    logic [7:0] A, X, Y, SP;
    // NV-BDIZC
    logic n_flag, v_flag, d_flag, i_flag, z_flag, c_flag;
	 
	 assign PC_debug = PC;

    logic [15:0] next_PC;
    logic next_n_flag, next_v_flag, next_d_flag,
          next_i_flag, next_z_flag, next_c_flag;
    logic A_en, X_en, Y_en, SP_en, inc_PC;
    logic [7:0] next_A, next_X, next_Y, next_SP;
    logic n_flag_en, v_flag_en, d_flag_en, i_flag_en, z_flag_en, c_flag_en;
    logic [1:0] PC_en;

    logic branch_bit;

    logic fetched_PC_en;
    logic [15:0] fetched_PC, next_fetched_PC;

    // memory signals
    logic [7:0] r_data_buffer;
    logic [15:0] next_addr;
    logic [1:0] addr_en;
    logic [7:0] next_r_data_buffer;
    logic r_data_buffer_en;


    // alu_signals
    logic alu_src2_inv, alu_c_in, alu_c_out, alu_v_out, alu_z_out, alu_n_out;
    logic [7:0] alu_src1, alu_src2, alu_out;
    ctrl_alu_op_t alu_op;

    logic alu_en;
    logic next_alu_c_out, next_alu_v_out, next_alu_z_out, next_alu_n_out;
    logic [7:0] next_alu_out;


////////////////////////////////////////////////////////////////////////////////
// ROM //

    assign rom_en = 1'b0;

    cpu_register #(.WIDTH(256*6), .RESET_VAL(`INSTR_CTRL_SIGNALS_INDICES))
        instr_ctrl_indices_reg(.data_en(rom_en), 
                               .data_in(instr_ctrl_signals_indices), 
                               .data_out(instr_ctrl_signals_indices), .*);
    cpu_register #(.WIDTH($bits(instr_ctrl_signals_t)*`INSTR_CTRL_SIZE),
                   .RESET_VAL(`INSTR_CTRL_SIGNALS_ROM))
        instr_ctrl_signals_rom_reg(.data_en(rom_en),
                                   .data_in(instr_ctrl_signals_rom),
                                   .data_out(instr_ctrl_signals_rom), .*);

    cpu_register #(.WIDTH(256*8), .RESET_VAL(`UCODE_CTRL_SIGNALS_INDICES))
        ucode_ctrl_signals_indices_reg(.data_en(rom_en),
                                       .data_in(ucode_ctrl_signals_indices),
                                       .data_out(ucode_ctrl_signals_indices), .*);
    cpu_register #(.WIDTH($bits(ucode_ctrl_signals_t)*`UCODE_ROM_SIZE),
                   .RESET_VAL(`UCODE_CTRL_SIGNALS_ROM))
        ucode_ctrl_signals_rom_reg(.data_en(rom_en),
                                   .data_in(ucode_ctrl_signals_rom),
                                   .data_out(ucode_ctrl_signals_rom), .*);

    cpu_register #(.WIDTH(256*2), .RESET_VAL(`DECODE_CTRL_SIGNALS_ROM))
        decode_ctrl_signals_rom_reg(.data_en(rom_en),
                                    .data_in(decode_ctrl_signals_rom),
                                    .data_out(decode_ctrl_signals_rom), .*);


////////////////////////////////////////////////////////////////////////////////
// CTRL //
    
    cpu_next_state next_state_logic(.c_out(alu_c_out), .*);    
    cpu_next_ucode_index next_ucode_index_logic(.c_out(alu_c_out), .*);

    assign opcode = (interrupt_active) ? 8'h00 : r_data;

    assign decode_start_fetch = decode_ctrl_signals_rom[opcode][1];
    assign decode_inc_pc = decode_ctrl_signals_rom[opcode][0] & ~interrupt_active;

    assign state_en = 1'b1;
    assign ucode_index_en = 1'b1;

    // ucode always defaults to index 0 - will trigger break on a fetch
    cpu_register ucode_index_reg(
//		cpu_register #(.RESET_VAL(0)) ucode_index_reg(
        .data_en(ucode_index_en), .data_in(next_ucode_index), 
        .data_out(ucode_index), .*);

    assign next_instr_ctrl_index = instr_ctrl_signals_indices[opcode];
    assign instr_ctrl_index_en = state == STATE_DECODE;

    cpu_register #(.WIDTH(6)) instr_ctrl_index_reg(
        .data_en(instr_ctrl_index_en), .data_in(next_instr_ctrl_index), 
        .data_out(instr_ctrl_index), .*);

    assign instr_ctrl_vector = instr_ctrl_signals_rom[instr_ctrl_index];
    assign ucode_vector = ucode_ctrl_signals_rom[ucode_index];

	// start fetching on a reset - will discard values once we leave decode
    // since we will be forced into a break
    cpu_register #(.WIDTH(2), .RESET_VAL(STATE_FETCH)) state_reg(
        .data_en(state_en), .data_in(next_state[1:0]), .data_out(state[1:0]), .*);


////////////////////////////////////////////////////////////////////////////////
// Interrupts //

    // nmi
    always_comb begin
        next_nmi_active = 1'b0;
        nmi_active_en = 1'b0;

        if (nmi_active == 1'b0 && !nmi) begin
            next_nmi_active = 1'b1;
            nmi_active_en = 1'b1;
        end

        if (nmi_active == 1'b1 && ucode_vector.addr_lo_src == ADDRLO_BRKHI && curr_interrupt == INTERRUPT_NMI) begin
            next_nmi_active = 1'b0;
            nmi_active_en = 1'b1;
        end
    end

    cpu_register #(.WIDTH(1)) nmi_active_reg(
        .data_en(nmi_active_en), .data_in(next_nmi_active),
        .data_out(nmi_active), .*);

    // irq is combinationally read

    // reset can also be treated as an interrupt
    assign next_reset_active = 1'b0;
    assign reset_active_en = (ucode_vector.addr_lo_src == ADDRLO_BRKHI && curr_interrupt == INTERRUPT_RESET);


    // #nestest set the .RESET_VAL from 1 to 0
    cpu_register #(.WIDTH(1), .RESET_VAL(1)) reset_reg(
        .data_en(reset_active_en), .data_in(next_reset_active),
        .data_out(reset_active), .*);

    // interrupt active if any of these signals are active
    assign interrupt_active = nmi_active | (~irq_n) | reset_active;

    // need to figure out which interrupt is the canonical interrupt,
    // if multiple are active and we're in break

    assign curr_interrupt_en = ucode_vector.write_mem_src == WMEMSRC_STATUS_BRK;

    always_comb begin
        next_interrupt = INTERRUPT_NONE;
        if (reset_active) begin
            next_interrupt = INTERRUPT_RESET;
        end
        else if (nmi_active) begin
            next_interrupt = INTERRUPT_NMI;
        end
        else if (~irq_n) begin
            next_interrupt = INTERRUPT_IRQ;
        end
    end

    cpu_register #(.WIDTH(2), .RESET_VAL(INTERRUPT_NONE)) interrupt_reg(
        .data_en(curr_interrupt_en), .data_in(next_interrupt[1:0]),
        .data_out(curr_interrupt[1:0]), .*);


////////////////////////////////////////////////////////////////////////////////
// cpu //

    branch_bit_module bbit(.branch_bit_type(instr_ctrl_vector.branch_bit),
                           .branch_inv(instr_ctrl_vector.branch_inv), .*);

    cpu_inputs cpu_in(.PC(next_PC), 
                      .n_flag(next_n_flag), .v_flag(next_v_flag),
                      .d_flag(next_d_flag), .i_flag(next_i_flag),
                      .z_flag(next_z_flag), .c_flag(next_c_flag), 
                      .fetched_PC(PC), .*);

    assign next_A = alu_out;
    assign next_X = alu_out;
    assign next_Y = alu_out;
    assign next_SP = alu_out;

    cpu_register A_reg(.data_en(A_en), .data_in(next_A), .data_out(A), .*);
    cpu_register X_reg(.data_en(X_en), .data_in(next_X), .data_out(X), .*);
    cpu_register Y_reg(.data_en(Y_en), .data_in(next_Y), .data_out(Y), .*);
    
    cpu_register #(.RESET_VAL(`DEFAULT_SP)) SP_reg(
                        .data_en(SP_en), .data_in(next_SP), .data_out(SP), .*);
    
    cpu_register #(.WIDTH(1), .RESET_VAL(`DEFAULT_N)) n_flag_reg(
            .data_en(n_flag_en), .data_in(next_n_flag), .data_out(n_flag), .*);
    cpu_register #(.WIDTH(1), .RESET_VAL(`DEFAULT_V)) v_flag_reg(
            .data_en(v_flag_en), .data_in(next_v_flag), .data_out(v_flag), .*);
    cpu_register #(.WIDTH(1), .RESET_VAL(`DEFAULT_D)) d_flag_reg(
            .data_en(d_flag_en), .data_in(next_d_flag), .data_out(d_flag), .*);
    cpu_register #(.WIDTH(1), .RESET_VAL(`DEFAULT_I)) i_flag_reg(
            .data_en(i_flag_en), .data_in(next_i_flag), .data_out(i_flag), .*);
    cpu_register #(.WIDTH(1), .RESET_VAL(`DEFAULT_Z)) z_flag_reg(
            .data_en(z_flag_en), .data_in(next_z_flag), .data_out(z_flag), .*);
    cpu_register #(.WIDTH(1), .RESET_VAL(`DEFAULT_C)) c_flag_reg(
            .data_en(c_flag_en), .data_in(next_c_flag), .data_out(c_flag), .*);

    cpu_wide_counter_register #(.RESET_VAL(`DEFAULT_PC)) PC_reg(
        .inc_en(inc_PC), .data_en(PC_en), .data_in(next_PC), .data_out(PC), .*);

    assign fetched_PC_en = state == STATE_FETCH;
    assign next_fetched_PC = PC;

    cpu_register #(.WIDTH(16), .RESET_VAL(`DEFAULT_PC)) fetched_PC_reg(
        .data_en(fetched_PC_en), .data_in(next_fetched_PC), .data_out(fetched_PC), .*);


////////////////////////////////////////////////////////////////////////////////
// mem //

    mem_inputs mem_in(.addr(next_addr), .*);

    // w_data and mem_r_en are not latched outputs,
    // but addr is latched and write thru

    assign next_r_data_buffer = r_data;
    assign r_data_buffer_en = mem_r_en;

    cpu_register r_data_buffer_reg(.data_en(mem_r_en),
        .data_in(next_r_data_buffer), .data_out(r_data_buffer), .*);

    cpu_wide_write_thru_register addr_reg(.data_en(addr_en), 
        .data_in(next_addr), .data_out(addr), .*);


////////////////////////////////////////////////////////////////////////////////
// ALU //

    alu_inputs alu_in(.c_out(alu_c_out), .c_in(alu_c_in), 
                      .src2_inv(alu_src2_inv), .src1(alu_src1),
                      .src2(alu_src2), .op(alu_op), .*);

    alu_module alu(.src1(alu_src1), .src2(alu_src2), .src2_inv(alu_src2_inv),
                   .c_in(alu_c_in), .op(alu_op), .out(next_alu_out),
                   .c_out(next_alu_c_out), .v_out(next_alu_v_out), 
                   .z_out(next_alu_z_out), .n_out(next_alu_n_out));

    assign alu_en = alu_op != ALUOP_HOLD;

    cpu_register alu_out_reg(.data_en(alu_en), .data_in(next_alu_out),
                         .data_out(alu_out), .*);

    cpu_register #(.WIDTH(1)) alu_c_out_reg(
        .data_en(alu_en), .data_in(next_alu_c_out), .data_out(alu_c_out), .*);
    cpu_register #(.WIDTH(1)) alu_v_out_reg(
        .data_en(alu_en), .data_in(next_alu_v_out), .data_out(alu_v_out), .*);
    cpu_register #(.WIDTH(1)) alu_z_out_reg(
        .data_en(alu_en), .data_in(next_alu_z_out), .data_out(alu_z_out), .*);
    cpu_register #(.WIDTH(1)) alu_n_out_reg(
        .data_en(alu_en), .data_in(next_alu_n_out), .data_out(alu_n_out), .*);


////////////////////////////////////////////////////////////////////////////////


endmodule : core


module branch_bit_module(
    input  ctrl_branch_bit_t branch_bit_type, 
    input  logic branch_inv,
    input  logic c_flag, z_flag, n_flag, v_flag,
    output logic branch_bit);

    always_comb begin
        branch_bit = 1'b0;
        case (branch_bit_type)
            // BRANCH_C, BRANCH_Z, BRANCH_N, BRANCH_V
            BRANCH_C: branch_bit = branch_inv ^ c_flag;
            BRANCH_Z: branch_bit = branch_inv ^ z_flag;
            BRANCH_N: branch_bit = branch_inv ^ n_flag;
            BRANCH_V: branch_bit = branch_inv ^ v_flag;
        endcase
    end

endmodule: branch_bit_module


module cpu_inputs(
    input  instr_ctrl_signals_t instr_ctrl_vector,
    input  ucode_ctrl_signals_t ucode_vector,
    input  processor_state_t state,
    input  logic decode_inc_pc,

    input logic[7:0] r_data, r_data_buffer, alu_out,
    input logic branch_bit,

    input logic interrupt_active,
    input logic [15:0] fetched_PC,

    input logic alu_n_out, alu_v_out, alu_z_out, alu_c_out,

    output logic[15:0] PC,
    output logic n_flag, v_flag, d_flag, i_flag, z_flag, c_flag,

    output logic A_en, X_en, Y_en, SP_en, inc_PC, 
                 n_flag_en, v_flag_en, d_flag_en, 
                 i_flag_en, z_flag_en, c_flag_en,

    output logic [1:0] PC_en);

    // PC first
    always_comb begin
        PC = 16'b0;
        PC_en = 2'b11;
        
        if (state == STATE_DECODE &&
            interrupt_active) begin

            PC = fetched_PC - 16'd1;

        end
        else begin

            case (ucode_vector.pclo_src)
                // PCLOSRC_RMEM, PCLOSRC_ALUOUT, PCLOSRC_RMEM_BUFFER, PCLOSRC_NONE
                PCLOSRC_RMEM: PC[7:0] = r_data;
                PCLOSRC_ALUOUT: PC[7:0] = alu_out;
                PCLOSRC_RMEM_BUFFER: PC[7:0] = r_data_buffer;
                PCLOSRC_NONE: PC_en[0] = 1'b0;
            endcase

            case (ucode_vector.pchi_src)
                // PCHISRC_RMEM, PCHISRC_ALUOUT, PCHISRC_NONE
                PCHISRC_RMEM: PC[15:8] = r_data;
                PCHISRC_ALUOUT: PC[15:8] = alu_out;
                PCHISRC_NONE: PC_en[1] = 1'b0;
            endcase

        end
    end    

    // inc PC
    always_comb begin
        inc_PC = 1'b0;
        case (state)
            // STATE_FETCH, STATE_DECODE, STATE_NEITHER
            STATE_FETCH: inc_PC = 1'b1;
            STATE_DECODE: inc_PC = decode_inc_pc;
            STATE_NEITHER: begin
                case (ucode_vector.inc_pc)
                    // BRANCH_DEPEND_0, BRANCH_DEPEND_1, BRANCH_DEPEND_BRANCH_BIT, BRANCH_DEPEND_NOT_C_OUT
                    BRANCH_DEPEND_0: inc_PC = 1'b0;
                    BRANCH_DEPEND_1: inc_PC = 1'b1;
                    BRANCH_DEPEND_BRANCH_BIT: inc_PC = ~branch_bit;
                    BRANCH_DEPEND_NOT_C_OUT: inc_PC = ~(alu_c_out ^ r_data_buffer[7]);
                endcase
            end
        endcase
    end

    //  A, X, Y always get loaded up with alu_out
    always_comb begin
        A_en = 1'b0;
        X_en = 1'b0;
        Y_en = 1'b0;
        SP_en = 1'b0;
        if (ucode_vector.instr_ctrl == INSTR_CTRL_2) begin
            case (instr_ctrl_vector.alu_out_dst)
                // ALUDST_A, ALUDST_X, ALUDST_Y, ALUDST_WMEM, ALUDST_status, ALUDST_SP, ALUDST_none
                ALUDST_A: A_en = 1'b1;
                ALUDST_X: X_en = 1'b1;
                ALUDST_Y: Y_en = 1'b1;
                ALUDST_SP: SP_en = 1'b1;
				default: ;
            endcase
        end

        if (ucode_vector.sp_src == SPSRC_ALUOUT) begin
            SP_en = 1'b1;
        end
    end

    // n_flag, v_flag, d_flag, i_flag, z_flag, c_flag
    always_comb begin

        {n_flag, v_flag, d_flag, i_flag, z_flag, c_flag} = 6'b0;
        {n_flag_en, v_flag_en, d_flag_en, i_flag_en, z_flag_en, c_flag_en} = 6'b0;

        if (ucode_vector.status_src == STATUS_SRC_RMEM) begin
            {n_flag, v_flag, d_flag, i_flag, z_flag, c_flag} = {r_data[7:6], r_data[3:0]};
            {n_flag_en, v_flag_en, d_flag_en, i_flag_en, z_flag_en, c_flag_en} = 6'b111_111;
        end

        else if (ucode_vector.instr_ctrl == INSTR_CTRL_2) begin
            if (instr_ctrl_vector.alu_out_dst == ALUDST_STATUS) begin
                {n_flag, v_flag, d_flag, i_flag, z_flag, c_flag} = {alu_out[7:6], alu_out[3:0]};
                {n_flag_en, v_flag_en, d_flag_en, i_flag_en, z_flag_en, c_flag_en} = 6'b111_111;
            end
            else begin

                case (instr_ctrl_vector.n_src)
                    // FLAG_ALU, FLAG_0, FLAG_1, FLAG_RMEM_BUFFER, FLAG_NONE
                    // alu, rmem_buffer, none
                    FLAG_ALU: begin 
                        n_flag = alu_n_out; 
                        n_flag_en = 1'b1; 
                    end
                    FLAG_RMEM_BUFFER: begin
                        n_flag = r_data_buffer[7];
                        n_flag_en = 1'b1;
                    end
						  default: ;
                endcase

                case (instr_ctrl_vector.v_src)
                    // alu ,rmem_buffer, 0
                    FLAG_ALU: begin
                        v_flag = alu_v_out;
                        v_flag_en = 1'b1;
                    end
                    FLAG_RMEM_BUFFER: begin
                        v_flag = r_data_buffer[6];
                        v_flag_en = 1'b1;
                    end
                    FLAG_0: begin
                        v_flag = 1'b0;
                        v_flag_en = 1'b1;
                    end
						  default: ;
                endcase

                case (instr_ctrl_vector.d_src)
                    // 0 and 1
                    FLAG_0: begin
                        d_flag = 1'b0;
                        d_flag_en = 1'b1;
                    end
                    FLAG_1: begin
                        d_flag = 1'b1;
                        d_flag_en = 1'b1;
                    end
						  default: ;
                endcase

                case (instr_ctrl_vector.i_src)
                    // 0 and 1
                    FLAG_0: begin
                        i_flag = 1'b0;
                        i_flag_en = 1'b1;
                    end
                    FLAG_1: begin
                        i_flag = 1'b1;
                        i_flag_en = 1'b1;
                    end
						  default: ;
                endcase

                case (instr_ctrl_vector.z_src)
                    // alu
                    FLAG_ALU: begin
                        z_flag = alu_z_out;
                        z_flag_en = 1'b1;
                    end
						  default: ;
                endcase

                case (instr_ctrl_vector.c_src)
                    // alu, 0, 1
                    FLAG_ALU: begin
                        c_flag = alu_c_out;
                        c_flag_en = 1'b1;
                    end
                    FLAG_0: begin
                        c_flag = 1'b0;
                        c_flag_en = 1'b1;
                    end
                    FLAG_1: begin
                        c_flag = 1'b1;
                        c_flag_en = 1'b1;
                    end
						  default: ;
                endcase

            end

        end

        if (ucode_vector.addr_hi_src == ADDRLO_BRKHI) begin
            i_flag = 1'b1;
            i_flag_en = 1'b1;
        end

    end 

endmodule : cpu_inputs


module cpu_next_state(
    input  ucode_ctrl_signals_t ucode_vector,
    input  logic[7:0] r_data_buffer,
    input  processor_state_t state,
    input  logic decode_start_fetch, branch_bit, c_out,

    output processor_state_t next_state);

    always_comb begin

        next_state = STATE_NEITHER;
        
        case (state)
            // STATE_FETCH, STATE_DECODE, STATE_NEITHER
            STATE_FETCH: next_state = STATE_DECODE;
            // if interrupt is active in decode, brk decode signals will be fetched, implying we don't start fetch next
            STATE_DECODE: next_state = (decode_start_fetch) ? STATE_FETCH : STATE_NEITHER;
            STATE_NEITHER: begin
                if (ucode_vector.start_fetch == 1'b1) begin
                    next_state = STATE_FETCH;
                end
                else if (ucode_vector.skip_line == 1'b1 && c_out == 1'b0) begin
                    next_state = STATE_FETCH;
                end
                else begin
                    case (ucode_vector.start_decode)
                        // BRANCH_DEPEND_0, BRANCH_DEPEND_1, BRANCH_DEPEND_BRANCH_BIT, BRANCH_DEPEND_NOT_C_OUT
                        BRANCH_DEPEND_0: next_state = STATE_NEITHER;
                        BRANCH_DEPEND_1: next_state = STATE_DECODE;
                        BRANCH_DEPEND_BRANCH_BIT: next_state = (branch_bit) ? STATE_NEITHER : STATE_DECODE;
                        BRANCH_DEPEND_NOT_C_OUT: next_state = (c_out ^ r_data_buffer[7]) ? STATE_NEITHER : STATE_DECODE;
                    endcase
                end
            end
        endcase
    end

endmodule : cpu_next_state

module cpu_next_ucode_index(
    input  ucode_ctrl_signals_t ucode_vector,
    input  processor_state_t state,
    input  logic[7:0] ucode_index, r_data,
    input  logic[7:0] opcode, r_data_buffer,
    input  logic c_out, branch_bit,
    input  logic[0:255][7:0] ucode_ctrl_signals_indices, 

    output logic[7:0] next_ucode_index);

    always_comb begin
        next_ucode_index = 8'b0;

        if (state == STATE_DECODE) begin
            next_ucode_index = ucode_ctrl_signals_indices[opcode];
        end
        else if (ucode_vector.skip_line == 1'b1) begin
            next_ucode_index = (c_out) ? ucode_index + 8'd1 : ucode_index + 8'd2;
        end
        else begin
            case (ucode_vector.stop_ucode)
                // BRANCH_DEPEND_0, BRANCH_DEPEND_1, BRANCH_DEPEND_BRANCH_BIT, BRANCH_DEPEND_NOT_C_OUT
                BRANCH_DEPEND_0: next_ucode_index = ucode_index + 8'd1;
                BRANCH_DEPEND_1: next_ucode_index = 8'd0;
                BRANCH_DEPEND_BRANCH_BIT: next_ucode_index = (branch_bit) ? ucode_index + 8'd1 : 8'd0;
                BRANCH_DEPEND_NOT_C_OUT: next_ucode_index = (c_out ^ r_data_buffer[7]) ? ucode_index + 8'd1 : 8'd0;
            endcase
        end
    end

endmodule : cpu_next_ucode_index
