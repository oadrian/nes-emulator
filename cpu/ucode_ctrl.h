
#include <stdint.h>
#include "cpu-types.h"

uint8_t reset_ucode_index;
uint8_t nmi_ucode_index;
uint8_t irq_ucode_index;

uint8_t instr_ctrl_signals_indices[256];
instr_ctrl_signals instr_ctrl_signals_rom[55];
uint8_t ucode_ctrl_signals_indices[256];
uint8_t decode_ctrl_signals_rom[148];
ucode_ctrl_signals ucode_ctrl_signals_rom[256];