`ifndef CPU_TYPES_VH_
`define CPU_TYPES_VH_

// enums used for instr ctrl signals

typedef enum logic[2:0] {ALUOP_HOLD, ALUOP_ADD, ALUOP_AND, ALUOP_OR, ALUOP_XOR, ALUOP_SHIFT_LEFT, ALUOP_SHIFT_RIGHT} ctrl_alu_op_t;

typedef enum logic[2:0] {ALUDST_A, ALUDST_X, ALUDST_Y, ALUDST_WMEM, ALUDST_STATUS, ALUDST_SP, ALUDST_NONE} ctrl_alu_out_dst_t;

typedef enum logic[2:0] {SRC1_A, SRC1_X, SRC1_Y, SRC1_RMEM, SRC1_SP, SRC1_PCHI, SRC1_PCLO, SRC1_ALUOUT} ctrl_alu_src1_t;

typedef enum logic {SRC2_RMEM, SRC2_0} ctrl_alu_src2_t;

//typedef enum logic {INVERT_1, INVERT_0} ctrl_inv_t; // may just make this 1/0

typedef enum logic[1:0] {ALUC_C, ALUC_0, ALUC_1, ALUC_ALUCOUT} ctrl_alu_c_src_t;

typedef enum logic[2:0] {FLAG_ALU, FLAG_0, FLAG_1, FLAG_RMEM_BUFFER, FLAG_NONE} ctrl_flag_src_t;

typedef enum logic[1:0] {BRANCH_C, BRANCH_Z, BRANCH_N, BRANCH_V} ctrl_branch_bit_t;

typedef enum logic[1:0] {STORE_A, STORE_X, STORE_Y, STORE_STATUS} ctrl_store_reg_t;

// enums used for addressing mode ucode

typedef enum logic[3:0] {ADDRLO_BRKHI, ADDRLO_BRKLO, ADDRLO_FD, ADDRLO_FC, ADDRLO_PCLO, ADDRLO_RMEMBUFFER, ADDRLO_RMEM, ADDRLO_ALUOUT, ADDRLO_SP, ADDRLO_HOLD} ucode_addr_lo_src_t;

typedef enum logic[2:0] {ADDRHI_1, ADDRHI_0, ADDRHI_FF, ADDRHI_PCHI, ADDRHI_RMEM, ADDRHI_ALUOUT, ADDRHI_HOLD} ucode_addr_hi_src_t;

typedef enum logic[1:0] {READ_EN_R, READ_EN_W, READ_EN_NONE} ucode_r_en_t;

typedef enum logic[2:0] {WMEMSRC_PCHI, WMEMSRC_PCLO, WMEMSRC_STATUS_BRK, WMEMSRC_STATUS_BC, WMEMSRC_INSTR_STORE, WMEMSRC_RMEM} ucode_write_mem_src_t;

typedef enum logic {SPSRC_ALUOUT, SPSRC_NONE} ucode_sp_src_t;

typedef enum logic[1:0] {PCLOSRC_RMEM, PCLOSRC_ALUOUT, PCLOSRC_RMEM_BUFFER, PCLOSRC_NONE} ucode_pclo_src_t;

typedef enum logic[1:0] {PCHISRC_RMEM, PCHISRC_ALUOUT, PCHISRC_NONE} ucode_pchi_src_t;

typedef enum logic {STATUS_SRC_RMEM, STATUS_SRC_NONE} ucode_status_src_t;

typedef enum logic[1:0] {BRANCH_DEPEND_0, BRANCH_DEPEND_1, BRANCH_DEPEND_BRANCH_BIT, BRANCH_DEPEND_NOT_C_OUT} ucode_branch_depend_t;

typedef enum logic[1:0] {INSTR_CTRL_0, INSTR_CTRL_1, INSTR_CTRL_2} ucode_instr_ctrl_t;

//typedef enum logic {ENABLE_1, ENABLE_0} ucode_en; // just make this 1/0

// enum for the states of the processor overall

typedef enum logic[1:0] {STATE_FETCH=2'b00, STATE_DECODE=2'b01, STATE_NEITHER=2'b10} processor_state_t;

typedef struct packed {
    ctrl_alu_op_t alu_op;
    ctrl_alu_out_dst_t alu_out_dst;
    ctrl_alu_src1_t alu_src1;
    ctrl_alu_src2_t alu_src2;
    logic alu_src2_inv;
    ctrl_alu_c_src_t alu_c_src;
    ctrl_flag_src_t n_src;
    ctrl_flag_src_t v_src;
    ctrl_flag_src_t b_src;
    ctrl_flag_src_t d_src;
    ctrl_flag_src_t i_src;
    ctrl_flag_src_t z_src;
    ctrl_flag_src_t c_src;
    ctrl_branch_bit_t branch_bit;
    logic branch_inv;
    ctrl_store_reg_t store_reg;
} instr_ctrl_signals_t;

typedef struct packed {
    ucode_addr_lo_src_t addr_lo_src;
    ucode_addr_hi_src_t addr_hi_src;
    ucode_r_en_t r_en;
    ucode_write_mem_src_t write_mem_src;
    ctrl_alu_src1_t alu_src1;
    ctrl_alu_src2_t alu_src2;
    logic alu_src2_inv;
    ctrl_alu_c_src_t alu_c_src;
    ctrl_alu_op_t alu_op;
    ucode_sp_src_t sp_src;
    ucode_pclo_src_t pclo_src;
    ucode_pchi_src_t pchi_src;
    ucode_status_src_t status_src;
    ucode_branch_depend_t inc_pc;
    ucode_instr_ctrl_t instr_ctrl;
    logic start_fetch;
    ucode_branch_depend_t start_decode;
    logic skip_line;
    ucode_branch_depend_t stop_ucode;
} ucode_ctrl_signals_t;

`endif