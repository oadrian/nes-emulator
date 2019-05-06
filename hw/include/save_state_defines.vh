
`define SAVE_STATE_BITS ($clog2(5187))

`define SAVE_STATE_LAST_ADDRESS 5187

`define SAVE_STATE_CPU_UCODE_INDEX 0
`define SAVE_STATE_CPU_INSTR_CTRL_INDEX 1
`define SAVE_STATE_CPU_STATE 2
`define SAVE_STATE_CPU_NMI_ACTIVE 3
`define SAVE_STATE_CPU_RESET_ACTIVE 4
`define SAVE_STATE_CPU_CURRENT_INTERRUPT 5
`define SAVE_STATE_CPU_A 6
`define SAVE_STATE_CPU_X 7
`define SAVE_STATE_CPU_Y 8
`define SAVE_STATE_CPU_SP 9
`define SAVE_STATE_CPU_N_FLAG 10
`define SAVE_STATE_CPU_V_FLAG 11
`define SAVE_STATE_CPU_D_FLAG 12
`define SAVE_STATE_CPU_I_FLAG 13
`define SAVE_STATE_CPU_Z_FLAG 14
`define SAVE_STATE_CPU_C_FLAG 15
`define SAVE_STATE_CPU_PC 16
`define SAVE_STATE_CPU_R_DATA_BUFFER 17
`define SAVE_STATE_CPU_ADDR 18
`define SAVE_STATE_CPU_ALU_OUT 19
`define SAVE_STATE_CPU_ALU_C_OUT 20
`define SAVE_STATE_CPU_ALU_V_OUT 21
`define SAVE_STATE_CPU_ALU_Z_OUT 22
`define SAVE_STATE_CPU_ALU_N_OUT 23
`define SAVE_STATE_CPU_MEM_CPU_RAM_LO 24
`define SAVE_STATE_CPU_MEM_CPU_RAM_HI 2071
`define SAVE_STATE_CPU_MEM_READ_DATA 2072
`define SAVE_STATE_CPU_MEM_PREV_REG_EN 2073
`define SAVE_STATE_CPU_MEM_PREV_BUT_RD 2074
`define SAVE_STATE_CPU_MEM_PREV_APU_RD 2075
`define SAVE_STATE_TOP_CPU_CYCLE_LO 2076
`define SAVE_STATE_TOP_CPU_CYCLE_HI 2079
`define SAVE_STATE_TOP_PPU_CYCLE_LO 2080
`define SAVE_STATE_TOP_PPU_CYCLE_HI 2083
`define SAVE_STATE_PPU_ROW 2084
`define SAVE_STATE_PPU_COL 2085
`define SAVE_STATE_PPU_HS_CURR_STATE 2086
`define SAVE_STATE_PPU_VS_CURR_STATE 2087
`define SAVE_STATE_PPU_PPU_BUF_IDX 2088
`define SAVE_STATE_PPU_PPU_BUFFER_LO 2089
`define SAVE_STATE_PPU_PPU_BUFFER_HI 2344
`define SAVE_STATE_PPU_VGA_BUFFER_LO 2345
`define SAVE_STATE_PPU_VGA_BUFFER_HI 2600
`define SAVE_STATE_PPU_TEMP_OAM_LO 2601
`define SAVE_STATE_PPU_TEMP_OAM_HI 2664
`define SAVE_STATE_PPU_TEMP_OAM_WR_IDX 2665
`define SAVE_STATE_PPU_TEMP_OAM_CNT 2666
`define SAVE_STATE_PPU_SEC_OAM_LO 2667
`define SAVE_STATE_PPU_SEC_OAM_HI 2730
`define SAVE_STATE_PPU_SEC_OAM_WR_IDX 2731
`define SAVE_STATE_PPU_SEC_OAM_CNT 2732
`define SAVE_STATE_REG_INTER_PPUCTRL_OUT 2733
`define SAVE_STATE_REG_INTER_PPUMASK_OUT 2734
`define SAVE_STATE_REG_INTER_OAMDMA_OUT 2735
`define SAVE_STATE_REG_INTER_OAMADDR_OUT 2736
`define SAVE_STATE_REG_INTER_WR_CURR_STATE 2737
`define SAVE_STATE_REG_INTER_REGDATA_OUT 2738
`define SAVE_STATE_REG_INTER_READ_BUF_CURR 2739
`define SAVE_STATE_REG_INTER_PPUSTATUS_OUT 2740
`define SAVE_STATE_REG_INTER_FORCE_VBLANK_CLR0 2741
`define SAVE_STATE_REG_INTER_FORCE_VBLANK_CLR1 2742
`define SAVE_STATE_REG_INTER_OAMDMA_CURR_STATE 2743
`define SAVE_STATE_REG_INTER_COUNTER 2744
`define SAVE_STATE_REG_INTER_FX 2745
`define SAVE_STATE_REG_INTER_TADDR 2746
`define SAVE_STATE_REG_INTER_VADDR 2747
`define SAVE_STATE_BG_PIXEL_NT 2748
`define SAVE_STATE_BG_PIXEL_AT 2749
`define SAVE_STATE_BG_PIXEL_BG_L 2750
`define SAVE_STATE_BG_PIXEL_BG_H 2751
`define SAVE_STATE_BG_PIXEL_BG_L_BOTH 2752
`define SAVE_STATE_BG_PIXEL_BG_H_BOTH 2753
`define SAVE_STATE_BG_PIXEL_AT_L_BOTH 2754
`define SAVE_STATE_BG_PIXEL_AT_H_BOTH 2755
`define SAVE_STATE_SP_EVAL_CURR_SPRITE 2756
`define SAVE_STATE_VGA_ROW_LO 2757
`define SAVE_STATE_VGA_ROW_HI 2766
`define SAVE_STATE_VGA_COL_LO 2767
`define SAVE_STATE_VGA_COL_HI 2776
`define SAVE_STATE_VGA_HS_CURR_STATE 2777
`define SAVE_STATE_VGA_VS_CURR_STATE 2778
`define SAVE_STATE_PPU_MEM_PAL_RAM_LO 2779
`define SAVE_STATE_PPU_MEM_PAL_RAM_HI 2810
`define SAVE_STATE_PPU_MEM_OAM_LO 2811
`define SAVE_STATE_PPU_MEM_OAM_HI 3066
`define SAVE_STATE_PPU_MEM_VRAM_LO 3067
`define SAVE_STATE_PPU_MEM_VRAM_HI 5114
`define SAVE_STATE_TRI_LEN_HALT 5115
`define SAVE_STATE_TRI_LIN_LOAD 5116
`define SAVE_STATE_TRI_LEN_LOAD 5117
`define SAVE_STATE_TRI_LIN_DATA 5118
`define SAVE_STATE_TRI_LEN_DATA 5119
`define SAVE_STATE_TRI_TIMER_PERIOD 5120
`define SAVE_STATE_TRI_SEQ_I 5121
`define SAVE_STATE_TRI_TIMER_COUNT 5122
`define SAVE_STATE_TRI_LIN_COUNT 5123
`define SAVE_STATE_TRI_LIN_RELOAD 5124
`define SAVE_STATE_TRI_LEN_COUNT 5125
`define SAVE_STATE_PUL0_ENV_LOAD 5126
`define SAVE_STATE_PUL0_SWEEP_LOAD 5127
`define SAVE_STATE_PUL0_SWEEP_SIGS 5128
`define SAVE_STATE_PUL0_DUTY 5129
`define SAVE_STATE_PUL0_LEN_HALT 5130
`define SAVE_STATE_PUL0_CONST_VOL 5131
`define SAVE_STATE_PUL0_VOLUME 5132
`define SAVE_STATE_PUL0_TIMER_PERIOD 5133
`define SAVE_STATE_PUL0_LEN_LOAD 5134
`define SAVE_STATE_PUL0_LEN_DATA 5135
`define SAVE_STATE_PUL0_SEQ_I 5136
`define SAVE_STATE_PUL0_TIMER_COUNT 5137
`define SAVE_STATE_PUL0_SWEEP_DIV_COUNT 5138
`define SAVE_STATE_PUL0_SWEEP_RELOAD 5139
`define SAVE_STATE_PUL0_ENV_DIV_COUNT 5140
`define SAVE_STATE_PUL0_ENV_DECAY_VOL 5141
`define SAVE_STATE_PUL0_ENV_START_FLAG 5142
`define SAVE_STATE_PUL0_LEN_COUNT 5143
`define SAVE_STATE_PUL1_ENV_LOAD 5144
`define SAVE_STATE_PUL1_SWEEP_LOAD 5145
`define SAVE_STATE_PUL1_SWEEP_SIGS 5146
`define SAVE_STATE_PUL1_DUTY 5147
`define SAVE_STATE_PUL1_LEN_HALT 5148
`define SAVE_STATE_PUL1_CONST_VOL 5149
`define SAVE_STATE_PUL1_VOLUME 5150
`define SAVE_STATE_PUL1_TIMER_PERIOD 5151
`define SAVE_STATE_PUL1_LEN_LOAD 5152
`define SAVE_STATE_PUL1_LEN_DATA 5153
`define SAVE_STATE_PUL1_SEQ_I 5154
`define SAVE_STATE_PUL1_TIMER_COUNT 5155
`define SAVE_STATE_PUL1_SWEEP_DIV_COUNT 5156
`define SAVE_STATE_PUL1_SWEEP_RELOAD 5157
`define SAVE_STATE_PUL1_ENV_DIV_COUNT 5158
`define SAVE_STATE_PUL1_ENV_DECAY_VOL 5159
`define SAVE_STATE_PUL1_ENV_START_FLAG 5160
`define SAVE_STATE_PUL1_LEN_COUNT 5161
`define SAVE_STATE_FC_NUM_CYCLES 5162
`define SAVE_STATE_FC_MODE 5163
`define SAVE_STATE_FC_INIHIBIT_INTERRUPT 5164
`define SAVE_STATE_FC_INTERRUPT 5165
`define SAVE_STATE_NOISE_ENV_DIV_COUNT 5166
`define SAVE_STATE_NOISE_ENV_DECAY_VOL 5167
`define SAVE_STATE_NOISE_ENV_START_FLAG 5168
`define SAVE_STATE_NOISE_SHIFT_DATA 5169
`define SAVE_STATE_NOISE_TIMER_COUNT 5170
`define SAVE_STATE_NOISE_LEN_COUNT 5171
`define SAVE_STATE_APU_STATUS 5172
`define SAVE_STATE_APU_REG_DATA_READ 5173
`define SAVE_STATE_MM_REG_REG_ARRAY_LO 5174
`define SAVE_STATE_MM_REG_REG_ARRAY_HI 5185
`define SAVE_STATE_MM_REG_REG_UPDATES_LO 5186
`define SAVE_STATE_MM_REG_REG_UPDATES_HI 5187