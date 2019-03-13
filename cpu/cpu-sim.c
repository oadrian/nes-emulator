/* 

    Cycle Accurate Simulator of MOS 6502

    Nikolai Lenney

*/

#include <stdint.h>
#include <stdio.h>

/* 

State viewable to the programmer:
A, X, Y, SP, PC, M, CC

open questions:
does incrementing the pc take 1 or 2 cycles if it crosses a boundary?

 change chars and shorts to uints bc im a good boy

*/

// how many bytes of memory we have (whole 16 bit address space)
#define MEMSIZE 0x10000

/* define bit positions of our 8 flags (NV-BDIZC) 
   Negative, Overflow, Always Set, Break,
   Decimal, Interrupt Disable, Zero, Carry
   since bit 5 is alway set we default the status register to 0x20 */
#define N_FLAG 7
#define V_FLAG 6
// the 5th bit is always 1
#define B_FLAG 4
#define D_FLAG 3
#define I_FLAG 2
#define Z_FLAG 1
#define C_FLAG 0
#define DEFAULT_STATUS 0x34
#define DEFAULT_SP 0xFD
#define DEFAULT_PC 0x4020

typedef union {
    uint16_t full;
    uint8_t half[2];
} mem_addr;

// enums used for instr ctrl signals

typedef enum {ALUOP_hold, ALUOP_add, ALUOP_and, ALUOP_or, ALUOP_xor, ALUOP_shift_left, ALUOP_shift_right} ctrl_alu_op;

typedef enum {ALUDST_A, ALUDST_X, ALUDST_Y, ALUDST_WMEM, ALUDST_status, ALUDST_SP, ALUDST_none} ctrl_alu_out_dst;

typedef enum {SRC1_A, SRC1_X, SRC1_Y, SRC1_RMEM, SRC1_SP, SRC1_PCHI, SRC1_PCLO, SRC1_ALUOUT} ctrl_alu_src1;

typedef enum {SRC2_RMEM, SRC2_0} ctrl_alu_src2;

typedef enum {Invert_1, Invert_0} ctrl_inv;

typedef enum {ALUC_C, ALUC_0, ALUC_1, ALUC_ALUCOUT} ctrl_alu_c_src;

typedef enum {Flag_alu, Flag_0, Flag_1, Flag_none} ctrl_flag_src;

typedef enum {Branch_C, Branch_Z, Branch_N, Branch_V} ctrl_branch_bit;

typedef enum {Store_A, Store_X, Store_Y, Store_status} ctrl_store_reg;

// enums used for addressing mode ucode

typedef enum {ADDRLO_1, ADDRLO_FF, ADDRLO_PCLO, ADDRLO_RMEMBUFFER, ADDRLO_0, ADDRLO_ALUOUT, ADDRLO_HOLD} ucode_addr_lo_src;

typedef enum {ADDRHI_SP, ADDRHI_FE, ADDRHI_FF, ADDRHI_PCHI, ADDRHI_RMEM, ADDRHI_ALUOUT, ADDRHI_HOLD} ucode_addr_hi_src;

typedef enum {ReadEn_read, ReadEn_write, ReadEn_none} ucode_r_en;

typedef enum {WMEMSRC_PCHI, WMEMSRC_PCLO, WMEMSRC_status, WMEMSRC_instr_store, WMEMSRC_RMEM} ucode_write_mem_src;

typedef enum {SPSRC_ALUOUT, SPSRC_none} ucode_sp_src;

typedef enum {PCLOSRC_RMEM, PCLOSRC_ALUOUT, PCLOSRC_RMEM_BUFFER, PCLOSRC_none} ucode_pclo_src;

typedef enum {PCHISRC_RMEM, PCHISRC_ALUOUT, PCHISRC_none} ucode_pchi_src;

typedef enum {Status_SRC_RMEM, Status_SRC_none} ucode_status_src;

typedef enum {Branch_Depend_0, Branch_Depend_1, Branch_Depend_branch_bit, Branch_Depend_not_c_out} ucode_branch_depend;

typedef enum {INSTR_CTRL_0, INSTR_CTRL_1, INSTR_CTRL_2} ucode_instr_ctrl;

typedef enum {Enable_1, Enable_0} ucode_en;

// enum for the state of the processor overall

typedef enum {State_fetch, State_decode, State_ucode} processor_state;

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
    ctrl_alu_src2_inv alu_src2_inv;
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

typedef struct {
    mem_addr PC;
    uint8_t A;
    uint8_t X;
    uint8_t Y;
    uint8_t SP;
    uint8_t status;
} cpu_core;

typedef struct {
    uint8_t *M;
    mem_addr addr;
    uint8_t data_out;
    uint8_t data_out_buffer;
    uint8_t data_in;
    uint8_t read_enable;
} memory_module;

typedef struct {
    uint8_t src1;
    uint8_t src2;
    uint8_t alu_out;
    alu_op op_sel;
    uint8_t c_in;
    uint8_t c_out;
    uint8_t v_out;
} alu_module;

// todo: figure out the actual start PC
cpu_state *init_cpu() {
    cpu = calloc(sizeof(cpu_state));
    cpu->status = DEFAULT_STATUS;
    cpu->SP = DEFAULT_SP;
    cpu->PC.full =  DEFAULT_PC;
    return cpu;
}

memory_module *init_memory() {
    mem = calloc(sizeof(memory_module));
    mem->data_in = 1; // should not be writing 0s anywhere
    mem->M = calloc(sizeof(uint8_t) * MEMSIZE);
    return mem;
}

alu_module *init_alu() {
    alu = calloc(sizeof(alu_module));
    alu->op_sel = ALU_hold;
    return alu;
}

void run_program(cpu_state *cpu, memory_module *mem) {
    alu_module *alu = init_alu();
    while (1) {

    }
}

int main() {
    cpu_state *cpu = init_cpu();
    memory_module *mem = init_memory();
    // open file from command line args and run it
    run_program(cpu, mem);
    return 0;
}