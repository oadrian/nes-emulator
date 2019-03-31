`default nettype_none

module core(
    output logic [15:0] address,
    output logic mem_r_en,
    output logic [7:0] w_data,
    input  logic [7:0] r_data,
    input  logic clock,
    input  logic reset);

    // state and ctrl signals
    processor_state_t state;
    logic [7:0] ucode_index;
    logic [6:0] instr_ctrl_index;
    logic [1:0] decode_ctrl_vector;
    instr_ctrl_signals_t instr_ctrl_vector;
    ucode_ctrl_signals_t ucode_vector;

    processor_state_t next_state;
    logic [7:0] next_ucode_index;
    //instr_ctrl_signals_t next_instr_ctrl_vector;
    //ucode_ctrl_signals_t next_ucode_vector;


    // architecture signals
    logic [15:0] PC;
    logic [7:0] A, X, Y, SP;
    // NV-BDIZC
    logic n_flag, v_flag, d_flag, i_flag, z_flag, c_flag;

    logic [15:0] next_PC;
    logic [7:0] next_A, next_X, next_Y, next_SP;
    logic next_n_flag, next_v_flag, next_d_flag, next_i_flag, next_z_flag, next_c_flag;


    // memory signals
    logic [7:0] r_data_buffer;
    // logic [7:0] next_r_data_buffer;


    // alu_signals
    logic alu_src2_inv, alu_c_in, alu_c_out, alu_v_out, alu_z_out, alu_n_out;
    logic [7:0] alu_src1, alu_src2, alu_out;
    ctrl_alu_op_t alu_op;

    logic next_alu_c_out, next_alu_v_out, next_alu_z_out, next_alu_n_out;
    logic [7:0] next_alu_out;

endmodule : core

module alu(
    input  logic [7:0] src1, src2,
    input  logic src2_inv, c_in,
    input  ctrl_alu_op_t op,
    output logic [7:0] out,
    output logic c_out, v_out, z_out, n_out);

    logic [7:0] add_res, and_res, or_res, xor_res, ror_res, rol_res;
    logic add_c_out, ror_c_out, rol_c_out;

    logic [7:0] add_src2;
    logic [7:0] partial_sum;
    logic [8:0] full_sum;

    // addition is special
    assign add_src2 = (src2_inv) ? ~src2 : src2;
    assign partial_sum = {1'b0, src1[6:0]} + {1'b0, add_src2[6:0]} + {7'b0, c_in};
    assign full_sum = {1'b0, partial_sum} + {1'b0, src1[7], 7'b0} + {1'b0, add_src2[7], 7'b0};

    assign add_res = full_sum[7:0];
    assign add_c_out = full_sum[8];
    assign v_out = add_c_out ^ partial_sum[7];

    // logic operations are quite simple
    assign and_res = src1 & src2;
    assign or_res  = src1 | src2;
    assign xor_res = src1 ^ src2;

    // rotate operations need to figure out their carries
    assign ror_res = {c_in, alu_src1[7:1]};
    assign ror_c_out = alu_src1[0];
    assign rol_res = {alu_src1[6:0], c_in};
    assign rol_c_out = alu_src1[7];

    always_comb begin
        out = 8'b0;
        c_out = 1'b0;
        case (op)
            // ALUOP_HOLD, ALUOP_ADD, ALUOP_AND, ALUOP_OR, ALUOP_XOR, ALUOP_SHIFT_LEFT, ALUOP_SHIFT_RIGHT
            ALUOP_ADD: begin
                out = add_res;
                c_out = add_c_out;
            end
            ALUOP_AND: out = and_res;
            ALUOP_OR : out = or_res;
            ALUOP_XOR: out = xor_res;
            ALUOP_SHIFT_LEFT: begin
                out = rol_res;
                c_out = rol_c_out;
            end
            ALUOP_SHIFT_RIGHT: begin
                out = ror_res;
                c_out = ror_c_out;
            end
        endcase
    end

    assign z_out = out == 8'b0;
    assign n_out = out[7];

endmodule : alu



