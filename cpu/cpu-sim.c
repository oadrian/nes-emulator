/* 

    Cycle Accurate Simulator of MOS 6502

    Nikolai Lenney

*/

#include <stdint.h>
#include <stdio.h>
#include "cpu-types.h"

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
    cpu = calloc(sizeof(cpu_core));
    cpu->status = DEFAULT_STATUS;
    cpu->SP = DEFAULT_SP;
    cpu->PC.full =  DEFAULT_PC;
    return cpu;
}

memory_module *init_memory() {
    mem = calloc(sizeof(memory_module));
    mem->data_in = 1; // should not be writing 0s anywhere
    mem->read_enable = Enable_1;
    mem->M = calloc(sizeof(uint8_t) * MEMSIZE);
    return mem;
}

alu_module *init_alu() {
    alu = calloc(sizeof(alu_module));
    alu->op_sel = ALU_hold;
    return alu;
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
}

uint8_t get_flag_bit(uint8_t status, uint8_t bit_position) {
    return (status >> bit_position) & 1;
}

void get_new_alu_values(alu_module* alu, alu_module* next_alu, cpu_core* cpu, memory_module* mem, 
                        processor_state* state, uint8_t ucode_index, uint8_t instr_ctrl_index) {

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
                        // can only be 0, 1, or ALUCOUT
                        case ALU_C: {next_alu->c_in = get_flag_bit(cpu->status, C_FLAG); break;}
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

            uint8_t  alu_out_temp;
            uint16_t alu_out_16;
            uint16_t alu_src1_16 = (uint16_t) next_alu->alu_src1;
            uint16_t alu_src2_16 = (uint16_t) next_alu->alu_src2;
            uint16_t alu_c_in_16 = (uint16_t) next_alu->c_in;

            if (next_alu->alu_src2_inv == Invert_1) {
                alu_out_temp = (next_alu->alu_src1 & 0x7F) + ((~next_alu->alu_src2) & 0x7F) + next_alu->c_in;
                alu_out_16 = alu_src1_16 + ~alu_src2_16 + alu_c_in_16;
            }
            else {
                alu_out_temp = (next_alu->alu_src1 & 0x7F) + (next_alu->alu_src2 & 0x7F) + next_alu->c_in;
                alu_out_16 = alu_src1_16 + alu_src2_16 + alu_c_in_16;
            }

            next_alu->alu_out = (uint8_t) alu_out_16;
            next_alu->c_out = (uint8_t) ((alu_out_16 >> 8) & 1);
            next_alu->v_out = next_alu->c_out ^ (alu_out_temp >> 7);

            break;
        }
        case ALUOP_and: {
            next_alu->alu_out = next_alu->alu_src1 & next_alu->alu_src2;
            break;
        }
        case ALUOP_or: {
            next_alu->alu_out = next_alu->alu_src1 | next_alu->alu_src2;
            break;
        }
        case ALUOP_xor: {
            next_alu->alu_out = next_alu->alu_src1 ^ next_alu->alu_src2;
            break;
        }
        case ALUOP_shift_left: {
            next_alu->c_out = next_alu->src1 >> 7;
            next_alu->alu_out = (next_alu->src1 << 1) + next_alu->alu_c_in;
            break;
        }
        case ALUOP_shift_right: {
            next_alu->c_out = next_alu->src1 & 1;
            next_alu->alu_out = (next_alu->src1 >> 1) + (next_alu->alu_c_in << 7);
            break;
        }

    }

    if (next_alu.alu_out == 0) {
        next_alu.z_out = 1;
    }
    else {
        next_alu.z_out = 0;
    }

    if (next_alu.alu_out >= 0x80) {
        next_alu.n_out = 1;
    }
    else {
        next_alu.n_out = 0;
    }

}

void get_new_mem_values(alu_module* alu, cpu_core* cpu, memory_module* mem, memory_module* next_mem, 
                        processor_state* state, uint8_t ucode_index, uint8_t instr_ctrl_index) {

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
            switch (ucode_vector.processor_ucode_activity) {
                // State_ucode_active, State_ucode_inactive
                case State_ucode_active: {

                    switch(ucode_vector.addr_lo_src) {
                    // ADDRLO_1, ADDRLO_FF, ADDRLO_PCLO, ADDRLO_RMEMBUFFER, ADDRLO_0, ADDRLO_ALUOUT, ADDRLO_hold
                        case ADDRLO_1: {next_mem->addr.half[0] = 1; break;}
                        case ADDRLO_FF: {next_mem->addr.half[0] = 0xFF; break;}
                        case ADDRLO_PCLO: {next_mem->addr.half[0] = cpu->PC.half[0]; break;}
                        case ADDRLO_RMEMBUFFER: {next_mem->addr.half[0] = mem->data_out_buffer; break;}
                        case ADDRLO_0: {next_mem->addr.half[0] = 0; break;}
                        case ADDRLO_ALUOUT: {next_mem->addr.half[0] = alu->alu_out; break;}
                        case ADDRLO_hold: {next_mem->addr.half[0] = mem->addr.half[0]; break;}
                    }

                    switch(ucode_vector.addr_hi_src) {
                    // ADDRHI_SP, ADDRHI_FE, ADDRHI_FF, ADDRHI_PCHI, ADDRHI_RMEM, ADDRHI_ALUOUT, ADDRHI_hold
                        case ADDRHI_SP: {next_mem->addr.half[1] = cpu->SP; break;}
                        case ADDRHI_FE: {next_mem->addr.half[1] = 0xFE; break;}
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
            next_mem->addr.full = cpu->PC.full;
            next_mem->read_enable = Enable_1;
        }
    }


    // now if R/W is R, 
        // move value in data_out to data_out_buffer
        // move value in M[addr.full] into data.out
        // copy data_in or 0 it
    if (next_mem->read_enable == Enable_1) {
        next_mem->data_out_buffer = mem->data_out;
        next_mem->data_out = next_mem->M[next_mem->addr.full];
        next_mem->data_in = mem->data_in;
    }

    // else if R/W is W,
        // find value of data_in
        // copy that value into data_in
        // change M[addr.full] to data_in
        // copy both data_out and data_out_buffer from old mem
    else {

        switch (ucode_vector.write_mem_src) {
            // WMEMSRC_PCHI, WMEMSRC_PCLO, WMEMSRC_status, WMEMSRC_instr_store, WMEMSRC_RMEM
            case WMEMSRC_PCHI: {next_mem->data_in = cpu->PC.half[1]; break;}
            case WMEMSRC_PCLO: {next_mem->data_in = cpu->PC.half[0]; break;}
            case WMEMSRC_status: {next_mem->data_in = cpu->status; break;}
            case WMEMSRC_RMEM: {next_mem->data_in = mem->data_out; break;}
            case WMEMSRC_instr_store: {
                switch (instr_ctrl_vector.store_reg) {
                    // Store_A, Store_X, Store_Y, Store_status
                    case Store_A: {next_mem->data_in = cpu->A; break;}
                    case Store_X: {next_mem->data_in = cpu->X; break;}
                    case Store_Y: {next_mem->data_in = cpu->Y; break;}
                    case Store_status: {next_mem->data_in = cpu->status; break;}
                }
                break;
            }
        }

        next_mem->M[next_mem->addr.full] = next_mem->data_in;
        next_mem->data_out = mem->data_out;
        next_mem->data_out_buffer = mem->data_out_buffer;

    }

}

void run_program(cpu_core *cpu, memory_module *mem) {
    alu_module *alu = init_alu();

    alu_module next_alu = calloc(sizeof(alu_module));
    memory_module next_mem = calloc(sizeof(memory_module));
    // need to make a decoder struct?
    // need to make a ROM struct to keep track of ucode activity and current line
    processor_state state = State_fetch;

    uint8_t ucode_index = 0;
    uint8_t instr_ctrl_index = 0;

    while (1) {
        
        get_new_alu_values(alu, next_alu, cpu, mem, state, ucode_index, instr_ctrl_index);
        get_new_memory_values(alu, cpu, mem, next_mem, state, ucode_index, instr_ctrl_index);


        // update the other arch regs
            // find new values for pc, A, X, Y, SP, flags
        // update the internal state
            // based on ucode or decode signals if in decode, or go to decode if in fetch
        // update ucode
            // if in decode set it to a brand new line

        copy_alu_module(next_alu, alu);
        copy_mem_module(next_mem, mem);

    }
}

int main() {
    cpu_core *cpu = init_cpu();
    memory_module *mem = init_memory();
    // open file from command line args and run it
    run_program(cpu, mem);
    return 0;
}