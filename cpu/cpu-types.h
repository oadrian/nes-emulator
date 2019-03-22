
#include <stdint.h>

// enums used for instr ctrl signals

typedef enum {ALUOP_hold, ALUOP_add, ALUOP_and, ALUOP_or, ALUOP_xor, ALUOP_shift_left, ALUOP_shift_right} ctrl_alu_op;

typedef enum {ALUDST_A, ALUDST_X, ALUDST_Y, ALUDST_WMEM, ALUDST_status, ALUDST_SP, ALUDST_none} ctrl_alu_out_dst;

typedef enum {SRC1_A, SRC1_X, SRC1_Y, SRC1_RMEM, SRC1_SP, SRC1_PCHI, SRC1_PCLO, SRC1_ALUOUT} ctrl_alu_src1;

typedef enum {SRC2_RMEM, SRC2_0} ctrl_alu_src2;

typedef enum {Invert_1, Invert_0} ctrl_inv;

typedef enum {ALUC_C, ALUC_0, ALUC_1, ALUC_ALUCOUT} ctrl_alu_c_src;

typedef enum {Flag_alu, Flag_0, Flag_1, Flag_RMEM_BUFFER, Flag_none} ctrl_flag_src;

typedef enum {Branch_C, Branch_Z, Branch_N, Branch_V} ctrl_branch_bit;

typedef enum {Store_A, Store_X, Store_Y, Store_status} ctrl_store_reg;

// enums used for addressing mode ucode

typedef enum {ADDRLO_1, ADDRLO_FF, ADDRLO_PCLO, ADDRLO_RMEMBUFFER, ADDRLO_0, ADDRLO_ALUOUT, ADDRLO_hold} ucode_addr_lo_src;

typedef enum {ADDRHI_SP, ADDRHI_FE, ADDRHI_FF, ADDRHI_PCHI, ADDRHI_RMEM, ADDRHI_ALUOUT, ADDRHI_hold} ucode_addr_hi_src;

typedef enum {ReadEn_R, ReadEn_W, ReadEn_none} ucode_r_en;

typedef enum {WMEMSRC_PCHI, WMEMSRC_PCLO, WMEMSRC_status, WMEMSRC_instr_store, WMEMSRC_RMEM} ucode_write_mem_src;

typedef enum {SPSRC_ALUOUT, SPSRC_none} ucode_sp_src;

typedef enum {PCLOSRC_RMEM, PCLOSRC_ALUOUT, PCLOSRC_RMEM_BUFFER, PCLOSRC_none} ucode_pclo_src;

typedef enum {PCHISRC_RMEM, PCHISRC_ALUOUT, PCHISRC_none} ucode_pchi_src;

typedef enum {Status_SRC_RMEM, Status_SRC_none} ucode_status_src;

typedef enum {Branch_Depend_0, Branch_Depend_1, Branch_Depend_branch_bit, Branch_Depend_not_c_out} ucode_branch_depend;

typedef enum {INSTR_CTRL_0, INSTR_CTRL_1, INSTR_CTRL_2} ucode_instr_ctrl;

typedef enum {Enable_1, Enable_0} ucode_en;

// enum for the states of the processor overall

typedef enum {State_fetch, State_decode, State_neither} processor_state;

typedef enum {State_ucode_active, State_ucode_inactive} processor_ucode_activity;

typedef struct {
    ctrl_alu_op alu_op;
    ctrl_alu_out_dst alu_out_dst;
    ctrl_alu_src1 alu_src1;
    ctrl_alu_src2 alu_src2;
    ctrl_inv alu_src2_inv;
    ctrl_alu_c_src alu_c_src;
    ctrl_flag_src n_src;
    ctrl_flag_src v_src;
    ctrl_flag_src b_src;
    ctrl_flag_src d_src;
    ctrl_flag_src i_src;
    ctrl_flag_src z_src;
    ctrl_flag_src c_src;
    ctrl_branch_bit branch_bit;
    ctrl_inv branch_inv;
    ctrl_store_reg store_reg;
} instr_ctrl_signals;

typedef struct 
{
    ucode_addr_lo_src addr_lo_src;
    ucode_addr_hi_src addr_hi_src;
    ucode_r_en r_en;
    ucode_write_mem_src write_mem_src;
    ctrl_alu_src1 alu_src1;
    ctrl_alu_src2 alu_src2;
    ctrl_inv alu_src2_inv;
    ctrl_alu_c_src alu_c_src;
    ctrl_alu_op alu_op;
    ucode_sp_src sp_src;
    ucode_pclo_src pclo_src;
    ucode_plhi_src pchi_src;
    ucode_status_src status_src;
    ucode_branch_depend inc_pc;
    ucode_instr_ctrl instr_ctrl;
    ucode_en start_fetch;
    ucode_branch_depend start_decode;
    ucode_en skip_line;
    ucode_branch_depend stop_ucode;
} ucode_ctrl_signals;