`default_nettype none

module alu_inputs(
    input  instr_ctrl_signals_t instr_ctrl_vector,
    input  ucode_ctrl_signals_t ucode_vector,
    input  logic[7:0] X, Y, SP, r_data, alu_out,
    input  logic[15:0] PC,
    input  logic c_out, c_flag,
    output logic c_in, src2_inv,
    output logic[7:0] src1, src2,
    output ctrl_alu_op_t op);

    always_comb begin
        op = ALUOP_HOLD;
        src2_inv = 1'b0;
        src1 = 8'b0;
        src2 = 8'b0;
        c_in = 1'b0;
        if (ucode_vector.alu_op == ALUOP_ADD) begin
            //ALUOP_HOLD, ALUOP_ADD, ALUOP_AND, ALUOP_OR, ALUOP_XOR, ALUOP_SHIFT_LEFT, ALUOP_SHIFT_RIGHT
            // can only hold or add here

            op = ALUOP_ADD;
            src2_inv = ucode_vector.alu_src2_inv;
            
            case (ucode_vector.alu_src1)
                // SRC1_A, SRC1_X, SRC1_Y, SRC1_RMEM, SRC1_SP, SRC1_PCHI, SRC1_PCLO, SRC1_ALUOUT
                // can be SP, X, Y, RMEM, PCLO, PCHI, ALUOUT
                SRC1_X: src1 = X;
                SRC1_Y: src1 = Y;
                SRC1_RMEM: src1 = r_data;
                SRC1_SP: src1 = SP;
                SRC1_PCHI: src1 = PC[15:8];
                SRC1_PCLO: src1 = PC[7:0];
                SRC1_ALUOUT: src1 = alu_out;
            endcase

            case (ucode_vector.alu_src2)
                // SRC2_RMEM, SRC2_0
                SRC2_RMEM: src2 = r_data;
                SRC2_0: src2 = 8'b0;
            endcase

            case (ucode_vector.alu_c_src)
                // ALUC_C, ALUC_0, ALUC_1, ALUC_ALUCOUT
                // can be 0, 1, or ALUCOUT
                ALUC_0: c_in = 1'b0;
                ALUC_1: c_in = 1'b1;
                ALUCOUT: c_in = c_out;
            endcase
        
        end
        else if (ucode_vector.alu_op == ALUOP_HOLD &&
                 ucode_vector.instr_ctrl == INSTR_CTRL_1) begin

            op = instr_ctrl_vector.alu_op;
            src2_inv = instr_ctrl_vector.alu_src2_inv;

            case (instr_ctrl_vector.alu_src1) begin
                // SRC1_A, SRC1_X, SRC1_Y, SRC1_RMEM, SRC1_SP, SRC1_PCHI, SRC1_PCLO, SRC1_ALUOUT
                // can be SP, X, Y, RMEM, A
                SRC1_A: src1 = A;
                SRC1_X: src1 = X;
                SRC1_Y: src1 = Y;
                SRC1_RMEM: src1 = r_data;
                SRC1_SP: src1 = SP;
            endcase

            case (instr_ctrl_vector.alu_src2)
                // SRC2_RMEM, SRC2_0
                SRC2_RMEM: src2 = r_data;
                SRC2_0: src2 = 8'b0;
            endcase

            case (instr_ctrl_vector.alu_c_src)
                // ALUC_C, ALUC_0, ALUC_1, ALUC_ALUCOUT
                // can only be 0, 1, or C
                ALUC_C: c_in = c_flag;
                ALUC_0: c_in = 1'b0;
                ALUC_1: c_in = 1'b1;
            endcase

        end

    end

endmodule : alu_inputs

module alu_module(
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