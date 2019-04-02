/* 

    Cycle Accurate Simulator of MOS 6502

    Nikolai Lenney

*/

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "cpu-types.h"
#include "ucode_ctrl.h"

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
#define SPARE_FLAG 5
#define B_FLAG 4
#define D_FLAG 3
#define I_FLAG 2
#define Z_FLAG 1
#define C_FLAG 0
#define DEFAULT_STATUS 0x34
#define DEFAULT_SP 0xFD
#define DEFAULT_PC 0x4020

#define DECODE_INC_PC 0
#define DECODE_START_FECTH 1

typedef union {
    uint16_t full;
    uint8_t half[2];
} mem_addr;

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
    ucode_en read_enable;
} memory_module;

typedef struct {
    uint8_t src1;
    uint8_t src2;
    uint8_t src2_invert;
    uint8_t alu_out;
    ctrl_alu_op op_sel;
    uint8_t c_in;
    uint8_t c_out;
    uint8_t v_out;
    uint8_t z_out;
    uint8_t n_out;
} alu_module;

// todo: figure out the actual start PC
cpu_core *init_cpu() {
    cpu_core *cpu = calloc(1, sizeof(cpu_core));
    cpu->status = DEFAULT_STATUS;
    cpu->SP = DEFAULT_SP;
    cpu->PC.full =  DEFAULT_PC;
    return cpu;
}

void print_cpu(cpu_core *cpu) {
    printf("PC:%4x A:%2x X:%2x Y:%2x SP:%2x Status:%2x\n",
           cpu->PC.full, cpu->A, cpu->X, cpu->Y, cpu->SP, cpu->status);
}

memory_module *init_memory(uint8_t *M) {
    memory_module *mem = calloc(1, sizeof(memory_module));
    mem->data_in = 1; // should not be writing 0s anywhere
    mem->read_enable = Enable_1;
    mem->M = M; //calloc(MEMSIZE, sizeof(uint8_t));
    return mem;
}

void print_mem(memory_module *mem) {
    printf("Addr:%4x DataOut:%2x DataOutBuf:%2x DataIn:%2x ",
           mem->addr.full, mem->data_out, mem->data_out_buffer, mem->data_in);
    if (mem->read_enable == Enable_1) {
        printf("R\n");
    }
    else {
        printf("W\n");
    }
}

alu_module *init_alu() {
    alu_module *alu = calloc(1, sizeof(alu_module));
    alu->op_sel = ALUOP_hold;
    return alu;
}

void print_alu(alu_module *alu) {
    /*
    uint8_t src1;
    uint8_t src2;
    uint8_t src2_invert;
    uint8_t alu_out;
    ctrl_alu_op op_sel;
    uint8_t c_in;
    uint8_t c_out;
    uint8_t v_out;
    uint8_t z_out;
    uint8_t n_out;
    */
    printf("src1:%2x src2:%2x ", alu->src1, alu->src2);
    if (alu->src2_invert == Invert_1) {
        printf("inv:1 ");
    }
    else {
        printf("inv:0 ");
    }
    printf("cin:%x ", alu->c_in);
    switch (alu->op_sel) {
        //ALUOP_hold, ALUOP_add, ALUOP_and, ALUOP_or, ALUOP_xor, ALUOP_shift_left, ALUOP_shift_right
        case ALUOP_hold: {printf("op:h  "); break;}
        case ALUOP_add: {printf("op:+  "); break;}
        case ALUOP_and: {printf("op:&  "); break;}
        case ALUOP_or: {printf("op:|  "); break;}
        case ALUOP_xor: {printf("op:^  "); break;}
        case ALUOP_shift_left: {printf("op:<< "); break;}
        case ALUOP_shift_right: {printf("op:>> "); break;}
    }
    printf("out:%2x\n", alu->alu_out);
}

void copy_mem_module(memory_module *src_mem, memory_module *dst_mem) {
    dst_mem->M = src_mem->M;
    dst_mem->addr.full = src_mem->addr.full;
    dst_mem->data_out = src_mem->data_out;
    dst_mem->data_out_buffer = src_mem->data_out_buffer;
    dst_mem->data_in = src_mem->data_in;
    dst_mem->read_enable = src_mem->read_enable;
}

void copy_alu_module(alu_module *src_alu, alu_module *dst_alu) {
    dst_alu->src1 = src_alu->src1;
    dst_alu->src2 = src_alu->src2;
    dst_alu->src2_invert = src_alu->src2_invert;
    dst_alu->alu_out = src_alu->alu_out;
    dst_alu->op_sel = src_alu->op_sel;
    dst_alu->c_in = src_alu->c_in;
    dst_alu->c_out = src_alu->c_out;
    dst_alu->v_out = src_alu->v_out;
    dst_alu->z_out = src_alu->z_out;
    dst_alu->n_out = src_alu->n_out;
}

void copy_cpu_module(cpu_core* src_cpu, cpu_core *dst_cpu) {
    dst_cpu->PC.full = src_cpu->PC.full;
    dst_cpu->A = src_cpu->A;
    dst_cpu->X = src_cpu->X;
    dst_cpu->Y = src_cpu->Y;
    dst_cpu->SP = src_cpu->SP;
    dst_cpu->status = src_cpu->status;
}

uint8_t get_flag_bit(uint8_t status, uint8_t bit_position) {
    return (status >> bit_position) & 1;
}

uint8_t set_flag_bit(uint8_t status, uint8_t bit_position, uint8_t bit_value) {
    uint8_t mask;
    if (bit_value == 1) {
        mask = 1 << bit_position;
        return status | mask;
    }
    else {
        mask = ~(1 << bit_position);
        return status & mask;
    }
}

uint8_t get_branch_bit(ctrl_branch_bit branch_bit, ctrl_inv branch_inv, uint8_t status) {
    uint8_t bit_pos = 0;
    switch (branch_bit) {
        //Branch_C, Branch_Z, Branch_N, Branch_V
        case Branch_C: {bit_pos = C_FLAG; break;}
        case Branch_Z: {bit_pos = Z_FLAG; break;}
        case Branch_N: {bit_pos = N_FLAG; break;}
        case Branch_V: {bit_pos = V_FLAG; break;} 
    }

    uint8_t flag_bit = get_flag_bit(status, bit_pos);

    if (branch_inv == Invert_1) {
        return 1^flag_bit;
    }
    else {
        return flag_bit;
    }
}

uint8_t get_decode_signal(uint8_t decode_ctrl_vector, uint8_t bit_position) {
    return (decode_ctrl_vector >> bit_position) & 1;
}

void get_new_alu_values(alu_module* alu, alu_module* next_alu, cpu_core* cpu, memory_module* mem, 
                        processor_state state, uint8_t ucode_index, uint8_t instr_ctrl_index) {

    // this doesn't check if ucode is active?
    // not sure if it's necessarily a problem though

    ucode_ctrl_signals ucode_vector = ucode_ctrl_signals_rom[ucode_index];
    instr_ctrl_signals instr_ctrl_vector = instr_ctrl_signals_rom[instr_ctrl_index];

    switch (ucode_vector.alu_op) {
        case ALUOP_add: {
            
            next_alu->op_sel = ALUOP_add;
            
            switch (ucode_vector.alu_src1) {
                // SRC1_A, SRC1_X, SRC1_Y, SRC1_RMEM, SRC1_SP, SRC1_PCHI, SRC1_PCLO, SRC1_ALUOUT
                // can be SP, X, Y, RMEM, PCLO, PCHI, ALUOUT
                case SRC1_X: {next_alu->src1 = cpu->X; break;}
                case SRC1_Y: {next_alu->src1 = cpu->Y; break;}
                case SRC1_RMEM: {next_alu->src1 = mem->data_out; break;}
                case SRC1_SP: {next_alu->src1 = cpu->SP; break;}
                case SRC1_PCLO: {next_alu->src1 = cpu->PC.half[0]; break;}
                case SRC1_PCHI: {next_alu->src1 = cpu->PC.half[1]; break;}
                case SRC1_ALUOUT: {next_alu->src1 = alu->alu_out; break;}
                default: { /* BOOM */ }
            }

            switch (ucode_vector.alu_src2) {
                // SRC2_RMEM, SRC2_0
                // can be both
                case SRC2_0: {next_alu->src2 = 0; break;}
                case SRC2_RMEM: {next_alu->src2 = mem->data_out; break;}
            }

            switch (ucode_vector.alu_c_src) {
                // ALUC_C, ALUC_0, ALUC_1, ALUC_ALUCOUT
                // can only be 0, 1, or ALUCOUT
                case ALUC_0: {next_alu->c_in = 0; break;}
                case ALUC_1: {next_alu->c_in = 1; break;}
                case ALUC_ALUCOUT: {next_alu->c_in = alu->c_out; break;}
                default: { /* BOOM */ }
            }

            next_alu->src2_invert = ucode_vector.alu_src2_inv;

            break; 
        }

        case ALUOP_hold: {
            // if ucode holds, but is in instr_ctrl phase 1, we case on their alu_op too
            switch (ucode_vector.instr_ctrl) {
                // INSTR_CTRL_0, INSTR_CTRL_1, INSTR_CTRL_2
                // can be all of them
                case INSTR_CTRL_1: {
    
                    // set src1, src2, c_in here

                    switch (instr_ctrl_vector.alu_src1) {
                        // SRC1_A, SRC1_X, SRC1_Y, SRC1_RMEM, SRC1_SP, SRC1_PCHI, SRC1_PCLO, SRC1_ALUOUT
                        // can be SP, X, Y, RMEM, A
                        case SRC1_A: {next_alu->src1 = cpu->A; break;}
                        case SRC1_X: {next_alu->src1 = cpu->X; break;}
                        case SRC1_Y: {next_alu->src1 = cpu->Y; break;}
                        case SRC1_RMEM: {next_alu->src1 = mem->data_out; break;}
                        case SRC1_SP: {next_alu->src1 = cpu->SP; break;}
                        default: { /* BOOM */ }
                    }

                    switch (instr_ctrl_vector.alu_src2) {
                        // SRC2_RMEM, SRC2_0
                        // can be both
                        case SRC2_0: {next_alu->src2 = 0; break;}
                        case SRC2_RMEM: {next_alu->src2 = mem->data_out; break;}
                    }

                    switch (instr_ctrl_vector.alu_c_src) {
                        // ALUC_C, ALUC_0, ALUC_1, ALUC_ALUCOUT
                        // can only be 0, 1, or ALUC
                        case ALUC_C: {next_alu->c_in = get_flag_bit(cpu->status, C_FLAG); break;}
                        case ALUC_0: {next_alu->c_in = 0; break;}
                        case ALUC_1: {next_alu->c_in = 1; break;}
                        default: { /* BOOM */ }
                    }

                    next_alu->src2_invert = instr_ctrl_vector.alu_src2_inv;

                    next_alu->op_sel = instr_ctrl_vector.alu_op;

                    break;

                }
                default: {
                    next_alu->op_sel = ALUOP_hold;
                }
            }
        }

        default: { /* BOOM */ }

    }

    // now we operate over the alu_op of next alu
    // if hold, do nothing?
    // if any other op, carry out the operation, setting the output and 3 bits

    switch (next_alu->op_sel) {
        // ALUOP_hold, ALUOP_add, ALUOP_and, ALUOP_or, ALUOP_xor, ALUOP_shift_left, ALUOP_shift_right
        case ALUOP_hold: {
            // basically just copy stuff over
            copy_alu_module(alu, next_alu);
            next_alu->op_sel = ALUOP_hold;
            break;
        }
        // now check each of the other cases!
        case ALUOP_add: {

            uint8_t src2_fixed;
            if (next_alu->src2_invert == Invert_1) {
                src2_fixed = ~next_alu->src2;
            }
            else {
                src2_fixed = next_alu->src2;
            }

            uint8_t  alu_out_temp;
            uint16_t alu_out_16;
            uint16_t alu_src1_16 = (uint16_t) next_alu->src1;
            uint16_t alu_src2_16 = (uint16_t) src2_fixed;
            uint16_t alu_c_in_16 = (uint16_t) next_alu->c_in;

            alu_out_temp = (next_alu->src1 & 0x7F) + (src2_fixed & 0x7F) + next_alu->c_in;
            alu_out_16 = alu_src1_16 + alu_src2_16 + alu_c_in_16;

            next_alu->alu_out = (uint8_t) alu_out_16;
            next_alu->c_out = (uint8_t) ((alu_out_16 >> 8) & 1);
            next_alu->v_out = next_alu->c_out ^ (alu_out_temp >> 7);

            break;
        }
        case ALUOP_and: {
            next_alu->alu_out = next_alu->src1 & next_alu->src2;
            break;
        }
        case ALUOP_or: {
            next_alu->alu_out = next_alu->src1 | next_alu->src2;
            break;
        }
        case ALUOP_xor: {
            next_alu->alu_out = next_alu->src1 ^ next_alu->src2;
            break;
        }
        case ALUOP_shift_left: {
            next_alu->c_out = next_alu->src1 >> 7;
            next_alu->alu_out = (next_alu->src1 << 1) + next_alu->c_in;
            break;
        }
        case ALUOP_shift_right: {
            next_alu->c_out = next_alu->src1 & 1;
            next_alu->alu_out = (next_alu->src1 >> 1) + (next_alu->c_in << 7);
            break;
        }

    }

    if (next_alu->alu_out == 0) {
        next_alu->z_out = 1;
    }
    else {
        next_alu->z_out = 0;
    }

    if ((next_alu->alu_out & 0x80) == 0x80) {
        next_alu->n_out = 1;
    }
    else {
        next_alu->n_out = 0;
    }

}


// memory mapping for cpu
/*

 0x0000 - 0x07ff 2KB ram
 0x0800 - 0x17ff mirrors of 2KB ram

 0x2000 - 0x2007 ppu registers
 0x2008 - 0x3fff mirrors of ppu registers

 0x4000 - 0x4017 apu/io regs
 0x4018 - 0x401f disbaled io and apu functionality

 0x4020 - 0xffff cartridge space

*/

uint16_t get_nes_cpu_addr(uint16_t addr) {


    if (addr < 0x2000) {
        // in 2KB ram
        return addr % 0x800;
    }
    else if (addr < 0x4000) {
        // in 8 PPU regs
        return (addr % 0x8) + 0x2000;
    }

    // APU/IO/ROM - addr is the same
    return addr;

}


void get_new_memory_values(alu_module* alu, cpu_core* cpu, memory_module* mem, memory_module* next_mem, 
                        processor_state state, processor_ucode_activity ucode_active, uint8_t ucode_index, uint8_t instr_ctrl_index) {

    ucode_ctrl_signals ucode_vector = ucode_ctrl_signals_rom[ucode_index];
    instr_ctrl_signals instr_ctrl_vector = instr_ctrl_signals_rom[instr_ctrl_index];

    // they will share the same memory, for efficiency
    // since the memory itself is hidden from other modules, it is okay to modify
    // it in this phase, as long as the other values in this module are updated correctly
    next_mem->M = mem->M;

    // if in fetch or decode, addr is pc, R/W is R
    // if state is neither, and ucode is active, address and R/W is determined by ucode
    // else addr is hold and R/W is R?
    switch (state) {
        // State_fetch, State_decode, State_neither
        // could be all 3, but do the same things in decode and fetch
        case State_neither: {
            switch (ucode_active) {
                // State_ucode_active, State_ucode_inactive
                case State_ucode_active: {

                    switch(ucode_vector.addr_lo_src) {
                    // ADDRLO_FF, ADDRLO_FE, ADDRLO_FD, ADDRLO_FC, ADDRLO_FB, ADDRLO_FA, ADDRLO_PCLO, ADDRLO_RMEMBUFFER, ADDRLO_RMEM, ADDRLO_ALUOUT, ADDRLO_SP, ADDRLO_hold
                        case ADDRLO_FF: {next_mem->addr.half[0] = 0xFF; break;}
                        case ADDRLO_FE: {next_mem->addr.half[0] = 0xFE; break;}
                        case ADDRLO_FD: {next_mem->addr.half[0] = 0xFD; break;}
                        case ADDRLO_FC: {next_mem->addr.half[0] = 0xFC; break;}
                        case ADDRLO_FB: {next_mem->addr.half[0] = 0xFB; break;}
                        case ADDRLO_FA: {next_mem->addr.half[0] = 0xFA; break;}
                        case ADDRLO_PCLO: {next_mem->addr.half[0] = cpu->PC.half[0]; break;}
                        case ADDRLO_RMEMBUFFER: {next_mem->addr.half[0] = mem->data_out_buffer; break;}
                        case ADDRLO_RMEM: {next_mem->addr.half[0] = mem->data_out; break;}
                        case ADDRLO_ALUOUT: {next_mem->addr.half[0] = alu->alu_out; break;}
                        case ADDRLO_SP: {next_mem->addr.half[0] = cpu->SP; break;}
                        case ADDRLO_hold: {next_mem->addr.half[0] = mem->addr.half[0]; break;}
                    }

                    switch(ucode_vector.addr_hi_src) {
                    // ADDRHI_1, ADDRHI_0, ADDRHI_FF, ADDRHI_PCHI, ADDRHI_RMEM, ADDRHI_ALUOUT, ADDRHI_hold
                        case ADDRHI_1: {next_mem->addr.half[1] = 1; break;}
                        case ADDRHI_0: {next_mem->addr.half[1] = 0; break;}
                        case ADDRHI_FF: {next_mem->addr.half[1] = 0xFF; break;}
                        case ADDRHI_PCHI: {next_mem->addr.half[1] = cpu->PC.half[1]; break;}
                        case ADDRHI_RMEM: {next_mem->addr.half[1] = mem->data_out; break;}
                        case ADDRHI_ALUOUT: {next_mem->addr.half[1] = alu->alu_out; break;}
                        case ADDRHI_hold: {next_mem->addr.half[1] = mem->addr.half[1]; break;}
                    }

                    switch(ucode_vector.r_en) {
                    // ReadEn_R, ReadEn_W, ReadEn_none
                        case ReadEn_R: {next_mem->read_enable = Enable_1; break;}
                        case ReadEn_W: {next_mem->read_enable = Enable_0; break;}
                        default: { /* BOOM */ }
                    }

                    break;

                }

                case State_ucode_inactive: {
                    next_mem->addr.full = mem->addr.full;
                    next_mem->read_enable = Enable_1;
                }
            }
            break;
        }
        default: {
            if (ucode_vector.pchi_src == PCHISRC_RMEM) {
                next_mem->addr.half[0] = cpu->PC.half[0];
                next_mem->addr.half[1] = mem->data_out;
            }
            else {
                next_mem->addr.full = cpu->PC.full;
            }      
            next_mem->read_enable = Enable_1;
        }
    }


    // now if R/W is R, 
        // move value in data_out to data_out_buffer
        // move value in M[addr.full] into data.out
        // copy data_in or 0 it
    if (next_mem->read_enable == Enable_1) {
        next_mem->data_out_buffer = mem->data_out;
        uint16_t real_addr = get_nes_cpu_addr(next_mem->addr.full);
        next_mem->data_out = next_mem->M[real_addr];
        next_mem->data_in = mem->data_in;
    }

    // else if R/W is W,
        // find value of data_in
        // copy that value into data_in
        // change M[addr.full] to data_in
        // copy both data_out and data_out_buffer from old mem
    else {

        // if the instr ctrl is writing a value to wmem, we need to use alu out as wmem
        if (ucode_vector.instr_ctrl == INSTR_CTRL_2 && 
            instr_ctrl_vector.alu_out_dst == ALUDST_WMEM) {
            next_mem->data_in = alu->alu_out;
        }
        else {

            switch (ucode_vector.write_mem_src) {
                // WMEMSRC_PCHI, WMEMSRC_PCLO, WMEMSRC_status_bs, WMEMSRC_status_bc, WMEMSRC_instr_store, WMEMSRC_RMEM
                case WMEMSRC_PCHI: {next_mem->data_in = cpu->PC.half[1]; break;}
                case WMEMSRC_PCLO: {next_mem->data_in = cpu->PC.half[0]; break;}
                //need to make sure the pushed status bits have proper flag set
                case WMEMSRC_status_bc: {next_mem->data_in = set_flag_bit(cpu->status, B_FLAG, 0); break;}
                case WMEMSRC_status_bs: {next_mem->data_in = set_flag_bit(cpu->status, B_FLAG, 1); break;}
                case WMEMSRC_RMEM: {next_mem->data_in = mem->data_out; break;}
                case WMEMSRC_instr_store: {
                    switch (instr_ctrl_vector.store_reg) {
                        // Store_A, Store_X, Store_Y, Store_status
                        case Store_A: {next_mem->data_in = cpu->A; break;}
                        case Store_X: {next_mem->data_in = cpu->X; break;}
                        case Store_Y: {next_mem->data_in = cpu->Y; break;}
                        case Store_status: {next_mem->data_in = set_flag_bit(cpu->status, B_FLAG, 1); break;}
                    }
                    break;
                }
            }
        }

        uint16_t real_addr = get_nes_cpu_addr(next_mem->addr.full);
        next_mem->M[real_addr] = next_mem->data_in;
        next_mem->data_out = mem->data_out;
        next_mem->data_out_buffer = mem->data_out_buffer;

    }

}

void get_new_cpu_values(alu_module* alu, cpu_core* cpu, cpu_core* next_cpu, memory_module* mem, 
                        processor_state state, processor_ucode_activity ucode_active, 
                        uint8_t ucode_index, uint8_t instr_ctrl_index, uint8_t decode_ctrl_index) {

    ucode_ctrl_signals ucode_vector = ucode_ctrl_signals_rom[ucode_index];
    instr_ctrl_signals instr_ctrl_vector = instr_ctrl_signals_rom[instr_ctrl_index];
    uint8_t decode_ctrl_vector = decode_ctrl_signals_rom[decode_ctrl_index];

    // first put new values into PC if needed
    switch (ucode_active) {
        // State_ucode_active, State_ucode_inactive
        case State_ucode_active: {
            switch (ucode_vector.pclo_src) {
                // PCLOSRC_RMEM, PCLOSRC_ALUOUT, PCLOSRC_RMEM_BUFFER, PCLOSRC_none
                case PCLOSRC_RMEM: {next_cpu->PC.half[0] = mem->data_out; break;}
                case PCLOSRC_ALUOUT: {next_cpu->PC.half[0] = alu->alu_out; break;}
                case PCLOSRC_RMEM_BUFFER: {next_cpu->PC.half[0] = mem->data_out_buffer; break;}
                case PCLOSRC_none: {next_cpu->PC.half[0] = cpu->PC.half[0]; break;}
            }
            switch (ucode_vector.pchi_src) {
                // PCHISRC_RMEM, PCHISRC_ALUOUT, PCHISRC_none
                case PCHISRC_RMEM: {next_cpu->PC.half[1] = mem->data_out; break;}
                case PCHISRC_ALUOUT: {next_cpu->PC.half[1] = alu->alu_out; break;}
                case PCHISRC_none: {next_cpu->PC.half[1] = cpu->PC.half[1]; break;}
            }
            break;
        }
        case State_ucode_inactive: {
            next_cpu->PC.full = cpu->PC.full;
            break;
        }

    }

    // now increment PC if needed
    switch (state) {
        //State_fetch, State_decode, State_neither
        case State_fetch: {next_cpu->PC.full++; break;}
        case State_decode: {
            if (get_decode_signal(decode_ctrl_vector, DECODE_INC_PC) == 1) {
                next_cpu->PC.full++;
            }
            break;
        }
        case State_neither: {
            if (ucode_active == State_ucode_active)
                switch (ucode_vector.inc_pc) {
                    // Branch_Depend_0, Branch_Depend_1, Branch_Depend_branch_bit, Branch_Depend_not_c_out
                    case Branch_Depend_0: {break;}
                    case Branch_Depend_1: {next_cpu->PC.full++; break;}
                    case Branch_Depend_branch_bit: {
                        uint8_t branch_bit = get_branch_bit(instr_ctrl_vector.branch_bit, instr_ctrl_vector.branch_inv, cpu->status);
                        if (branch_bit == 0) {
                            next_cpu->PC.full++;   
                        }
                        break;
                    }
                    case Branch_Depend_not_c_out: {
                        if (alu->c_out == 0) {
                            next_cpu->PC.full++;   
                        }
                        break;
                    }
                }
            break;
        }
    }

    // now we've got PC!

    // write A, X, Y
    if (ucode_active == State_ucode_active &&
        ucode_vector.instr_ctrl == INSTR_CTRL_2 &&
        instr_ctrl_vector.alu_out_dst == ALUDST_A) {
        next_cpu->A = alu->alu_out;
    }
    else {
        next_cpu->A = cpu->A;
    }

    if (ucode_active == State_ucode_active &&
        ucode_vector.instr_ctrl == INSTR_CTRL_2 &&
        instr_ctrl_vector.alu_out_dst == ALUDST_X) {
        next_cpu->X = alu->alu_out;
    }
    else {
        next_cpu->X = cpu->X;
    }

    if (ucode_active == State_ucode_active &&
        ucode_vector.instr_ctrl == INSTR_CTRL_2 &&
        instr_ctrl_vector.alu_out_dst == ALUDST_Y) {
        next_cpu->Y = alu->alu_out;
    }
    else {
        next_cpu->Y = cpu->Y;
    }

    // write out SP
    if (ucode_active == State_ucode_active &&
        ((ucode_vector.instr_ctrl == INSTR_CTRL_2 && instr_ctrl_vector.alu_out_dst == ALUDST_SP) ||
         (ucode_vector.sp_src == SPSRC_ALUOUT))) {
        next_cpu->SP = alu->alu_out;
    }
    else {
        next_cpu->SP = cpu->SP;
    }

    // figure out status
    // decode status src can be rmem
    // elif instr ctrl 2:
        // if alu_out_src == status
            // status just becomes alu out
        // else
        // check each of the 7 bits
        // for the bit operation, copy bits from RMEM_BUFFER

    if (ucode_active == State_ucode_active && ucode_vector.status_src == Status_SRC_RMEM) {
        next_cpu->status = mem->data_out;
    } 
    else if (ucode_active == State_ucode_active && ucode_vector.instr_ctrl == INSTR_CTRL_2) {
        if (instr_ctrl_vector.alu_out_dst == ALUDST_status) {
            next_cpu->status = alu->alu_out;
        }

        else {
            // now we gotta check each of the 8 bits
            // NV-BDIZC

            // N
            uint8_t n_bit_value = 0;
            switch (instr_ctrl_vector.n_src) {
                // Flag_alu, Flag_0, Flag_1, Flag_RMEM_BUFFER, Flag_none
                case Flag_alu: {n_bit_value = alu->n_out; break;}
                case Flag_RMEM_BUFFER: {n_bit_value = get_flag_bit(mem->data_out_buffer, N_FLAG); break;}
                case Flag_none: {n_bit_value = get_flag_bit(cpu->status, N_FLAG); break;}
                default: { /* BOOM */ }
            }

            // V
            uint8_t v_bit_value = 0;
            switch (instr_ctrl_vector.v_src) {
                // Flag_alu, Flag_0, Flag_1, Flag_RMEM_BUFFER, Flag_none
                case Flag_alu: {v_bit_value = alu->v_out; break;}
                case Flag_RMEM_BUFFER: {v_bit_value = get_flag_bit(mem->data_out_buffer, V_FLAG); break;}
                case Flag_0: {v_bit_value = 0; break;}
                case Flag_none: {v_bit_value = get_flag_bit(cpu->status, V_FLAG); break;}
                default: { /* BOOM */ }
            }

            // Spare
            uint8_t spare_bit_value = 1; //get_flag_bit(cpu->status, SPARE_FLAG);


            // B
            uint8_t b_bit_value = 0;
            // b-bit doesn't actually exist in the register
            // we just put enable it on some pushes to the stack
            //get_flag_bit(cpu->status, B_FLAG);

            // D
            uint8_t d_bit_value = 0;
            switch (instr_ctrl_vector.d_src) {
                // Flag_alu, Flag_0, Flag_1, Flag_RMEM_BUFFER, Flag_none
                case Flag_0: {d_bit_value = 0; break;}
                case Flag_1: {d_bit_value = 1; break;}
                case Flag_none: {d_bit_value = get_flag_bit(cpu->status, D_FLAG); break;}
                default: { /* BOOM */ }
            }

            // I
            uint8_t i_bit_value = 0;
            switch (instr_ctrl_vector.i_src) {
                // Flag_alu, Flag_0, Flag_1, Flag_RMEM_BUFFER, Flag_none
                case Flag_0: {i_bit_value = 0; break;}
                case Flag_1: {i_bit_value = 1; break;}
                case Flag_none: {i_bit_value = get_flag_bit(cpu->status, I_FLAG); break;}
                default: { /* BOOM */ }
            }

            // Z
            uint8_t z_bit_value = 0;
            switch (instr_ctrl_vector.z_src) {
                // Flag_alu, Flag_0, Flag_1, Flag_RMEM_BUFFER, Flag_none
                case Flag_alu: {z_bit_value = alu->z_out; break;}
                case Flag_none: {z_bit_value = get_flag_bit(cpu->status, Z_FLAG); break;}
                default: { /* BOOM */ }
            }

            // C
            uint8_t c_bit_value = 0;
            switch (instr_ctrl_vector.c_src) {
                // Flag_alu, Flag_0, Flag_1, Flag_RMEM_BUFFER, Flag_none
                case Flag_alu: {c_bit_value = alu->c_out; break;}
                case Flag_0: {c_bit_value = 0; break;}
                case Flag_1: {c_bit_value = 1; break;}
                case Flag_none: {c_bit_value = get_flag_bit(cpu->status, C_FLAG); break;}
                default: { /* BOOM */ }
            }

            
            // putting it all together
            // NV-BDIZC
            uint8_t next_status = (n_bit_value << N_FLAG) +
                                  (v_bit_value << V_FLAG) +
                                  (spare_bit_value << SPARE_FLAG) +
                                  (b_bit_value << B_FLAG) +
                                  (d_bit_value << D_FLAG) +
                                  (i_bit_value << I_FLAG) +
                                  (z_bit_value << Z_FLAG) +
                                  (c_bit_value << C_FLAG);

            next_cpu->status = next_status;
        }

    }
    else {
        next_cpu->status = cpu->status;
    }

    next_cpu->status = set_flag_bit(next_cpu->status, B_FLAG, 0);
    next_cpu->status = set_flag_bit(next_cpu->status, SPARE_FLAG, 1);

}

processor_state get_next_state(cpu_core *cpu, alu_module *alu, processor_state state, 
                               uint8_t ucode_index, uint8_t instr_ctrl_index, uint8_t decode_ctrl_index,
                               processor_ucode_activity ucode_active) {

    ucode_ctrl_signals ucode_vector = ucode_ctrl_signals_rom[ucode_index];
    instr_ctrl_signals instr_ctrl_vector = instr_ctrl_signals_rom[instr_ctrl_index];
    uint8_t decode_ctrl_vector = decode_ctrl_signals_rom[decode_ctrl_index];


    switch (state) {
        // State_fetch, State_decode, State_neither
        case State_fetch: {
            return State_decode;
        }
        case State_decode: {
            if (get_decode_signal(decode_ctrl_vector, DECODE_START_FECTH) == 1) {
                return State_fetch;
            }
            else {
                return State_neither;
            }
        }
        case State_neither: {
            if (ucode_active == State_ucode_inactive) {
                // should probably not be able to reach here
                return State_neither;
            }
            else if (ucode_vector.start_fetch == Enable_1) {
                return State_fetch;
            }
            else if (ucode_vector.skip_line == Enable_1 &&
                     alu->c_out == 0) {
                return State_fetch;
            }
            switch (ucode_vector.start_decode) {
                // Branch_Depend_0, Branch_Depend_1, Branch_Depend_branch_bit, Branch_Depend_not_c_out
                case Branch_Depend_0: {
                    return State_neither;
                }
                case Branch_Depend_1: {
                    return State_decode;
                }
                case Branch_Depend_branch_bit: {
                    uint8_t branch_bit = get_branch_bit(instr_ctrl_vector.branch_bit, instr_ctrl_vector.branch_inv, cpu->status);
                    if (branch_bit == 0) {
                        return State_decode;
                    }
                    else {
                        return State_neither;
                    }
                }
                case Branch_Depend_not_c_out: {
                    if (alu->c_out == 0) {
                        return State_decode;
                    }
                    else {
                        return State_neither;
                    }
                }
            }
        }
    }
}

/*
processor_ucode_activity get_next_ucode_active(cpu_core *cpu, alu_module *alu, memory_module *mem, 
                                               processor_state state, processor_ucode_activity ucode_active, 
                                               uint8_t ucode_index, uint8_t instr_ctrl_index) {

    ucode_ctrl_signals ucode_vector = ucode_ctrl_signals_rom[ucode_index];
    instr_ctrl_signals instr_ctrl_vector = instr_ctrl_signals_rom[instr_ctrl_index];

}
*/

uint8_t get_next_ucode_index(cpu_core *cpu, alu_module *alu, memory_module *mem, 
                              processor_state state, processor_ucode_activity ucode_active, 
                              uint8_t ucode_index, uint8_t instr_ctrl_index) {

    ucode_ctrl_signals ucode_vector = ucode_ctrl_signals_rom[ucode_index];
    instr_ctrl_signals instr_ctrl_vector = instr_ctrl_signals_rom[instr_ctrl_index];

    // if ucode index is 0, then only decode can change it
    // if ucode index is not zero, check the line and see what is says to do

    // no matter what, if we're in decode, the next ucode index is based on the opcode
    if (state == State_decode) {
        return ucode_ctrl_signals_indices[mem->data_out];
    }

    // if c-skip is enabled
    else if (ucode_vector.skip_line == Enable_1) {
        // if there is a carry out, increment by 1!
        if (alu->c_out == 1) {
            return ucode_index + 1;
        }
        else {
            return ucode_index + 2;
        }
        
    }

    // if stopu_code is enabled - return 0
    switch (ucode_vector.stop_ucode) {
        //Branch_Depend_0, Branch_Depend_1, Branch_Depend_branch_bit, Branch_Depend_not_c_out
        case Branch_Depend_0: {
            return ucode_index + 1;
        }
        case Branch_Depend_1: {
            return 0;
        }
        case Branch_Depend_branch_bit: {
            uint8_t branch_bit = get_branch_bit(instr_ctrl_vector.branch_bit, instr_ctrl_vector.branch_inv, cpu->status);
            if (branch_bit == 0) {
                return 0;
            }
            else {
                return ucode_index + 1;
            }
        }
        case Branch_Depend_not_c_out: {
            if (alu->c_out == 0) {
                return 0;
            }
            else {
                return ucode_index + 1;
            }
        }
    }
}

void run_program(cpu_core *cpu, memory_module *mem) {

    FILE *fptr;
    fptr = fopen("logs\\cpu-out.log.txt","w");

    alu_module *alu = init_alu();

    int ct = 7;

    alu_module *next_alu = calloc(1, sizeof(alu_module));
    memory_module *next_mem = calloc(1, sizeof(memory_module));
    cpu_core *next_cpu = calloc(1, sizeof(cpu_core));

    processor_state state = State_fetch; //State_neither;
    processor_ucode_activity ucode_active = State_ucode_active;

    cpu->PC.full = 0xC000;
    //cpu->status = set_flag_bit(cpu->status, I_FLAG, 1);
    cpu->status = 0x24;

    uint8_t ucode_index = 0;//reset_ucode_index;
    uint8_t instr_ctrl_index = 0;
    uint8_t decode_ctrl_index = 0;

    processor_state next_state;
    //processor_ucode_activity next_ucode_active;

    uint8_t next_ucode_index;
    uint8_t next_instr_ctrl_index;

    // 26555
    while (ct < 26555) {

        //printf("%d\n", ct);

        if (state == State_decode) {
            decode_ctrl_index = mem->data_out;
            next_instr_ctrl_index = instr_ctrl_signals_indices[mem->data_out];
        }

        /*if (1) {
            printf("---------cycle: %d--------------------------------------------------\n", ct);
            switch (state) {
                case State_fetch: {printf("Fetch\n"); break;}
                case State_decode: {printf("Decode\n"); break;}
                case State_neither: {printf("Neither\n"); break;}
            }
            printf("ucode_index:%3d instr_ctrl_index:%3d decode_ctrl_index:%2x\n",
                   ucode_index, instr_ctrl_index, decode_ctrl_index);
            print_cpu(cpu);
            print_mem(mem);
            print_alu(alu);
            //printf("%d, %x\n", ucode_index, mem->data_out);
        }*/

        //C000  4C F5 C5  JMP $C5F5                       A:00 X:00 Y:00 P:24 SP:FD PPU:  0,  0 CYC:7

       //uint8_t p_sp = cpu->SP;
        processor_state p_state = state;
        if (state == State_decode) {
            fprintf(fptr, "%.4x %.2x ", 
                   cpu->PC.full-1, mem->data_out);
        }
        
        get_new_alu_values(alu, next_alu, cpu, mem, state, ucode_index, instr_ctrl_index);
        get_new_memory_values(alu, cpu, mem, next_mem, state, ucode_active, ucode_index, instr_ctrl_index);
        get_new_cpu_values(alu, cpu, next_cpu, mem, state, ucode_active, ucode_index, instr_ctrl_index, decode_ctrl_index);

        // now we update the following:
            // ucode_active, ucode_index, instr_ctrl_index

        next_state = get_next_state(cpu, alu, state, ucode_index, instr_ctrl_index, decode_ctrl_index, ucode_active);
        //if (next_state == State_decode) {
        //    printf("(nani?\n" );
        //}
        //next_ucode_active = get_next_ucode_active(cpu, alu, mem, state, ucode_active, ucode_index, instr_ctrl_index);

        next_ucode_index = get_next_ucode_index(cpu, alu, mem, state, ucode_active, ucode_index, instr_ctrl_index);

        copy_alu_module(next_alu, alu);
        copy_mem_module(next_mem, mem);
        copy_cpu_module(next_cpu, cpu);

        state = next_state;
        ucode_index = next_ucode_index;
        instr_ctrl_index = next_instr_ctrl_index;

        if (p_state == State_decode) {
            fprintf(fptr, "A:%.2x X:%.2x Y:%.2x P:%.2x SP:%.2x CYC:%d\n", 
                   cpu->A, cpu->X, cpu->Y, cpu->status, cpu->SP, ct-1);
        }

        ct++;

    }

    fclose(fptr);

    free(alu);
    free(next_alu);
    free(next_mem);
    free(next_cpu);
}


uint8_t *init_memory_bytes() {
    uint8_t *M = calloc(MEMSIZE, sizeof(uint8_t));

    FILE *fptr;

    if ((fptr = fopen("tests\\nestest.nes","rb")) == NULL){
       printf("Error! opening file");

       // Program exits if the file pointer returns NULL.
       exit(1);
    }

    // base address is C000, goes to FFFF

    uint8_t num;

    for(int n = 0; n < 16; n++) {
      fread(&num, sizeof(uint8_t), 1, fptr); 
      //printf("n: %d, val: %c\n", n, num);
    }

    uint16_t base_addr = 0xC000;
    
    for (uint16_t offset = 0; offset < 0x4000; offset++) {
        fread(&num, sizeof(uint8_t), 1, fptr);
        M[base_addr + offset] = num;
    }

    //M[0xFFFC] = 0x00;
    //M[0xFFFD] = 0xC0;

    //printf("%x%x %x%x %x%x", M[0xFFFA], M[0xFFFB], M[0xFFFC], M[0xFFFD], M[0xFFFE], M[0xFFFF]);

    fclose(fptr);

    return M;
}


int main() {
    cpu_core *cpu = init_cpu();
    uint8_t *M = init_memory_bytes();
    memory_module *mem = init_memory(M);
    // open file from command line args and run it


    run_program(cpu, mem);

    free(cpu);
    free(mem);
    free(M);

    return 0;
}


// how to actually run this bad boy?
// polling for interupts?