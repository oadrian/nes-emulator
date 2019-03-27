`ifndef PPU_DEFINES_VH_
`define PPU_DEFINES_VH_

// Number of scanlines per frame
`define NUM_SCANLINES 262

// Number of cycles per scanline
`define CYCLES_IN_SL 341

// Active pixel screen size
`define SCREEN_WIDTH 256
`define SCREEN_HEIGHT 240

// Sprite Width
`define SPRITE_WIDTH 8

// Secondary OAM array size
`define SEC_OAM_SIZE 8

// PPU Vertical scanline states
typedef enum logic [1:0] {
    PRE_SL,  // 0
    VIS_SL,  // 1-240 
    POST_SL, // 241
    VBLANK_SL // 242-261
} vs_state_t;

// PPU Horizontal cycles states
typedef enum logic [2:0] {
    SL_PRE_CYC, // 0-255
    IDLE_CYC,    // 256
    SP_PRE_CYC,  // 257-320 
    TL_PRE_CYC,  // 321-336
    GARB_CYC     // 337-340
} hs_state_t;

// VGA vertical states 524 scanlines
typedef enum logic [2:0] {
    VGA_VS_PRE_SL,  // 0-3       4 sl of Back Porch
    VGA_VS_VIS_SL,  // 4-483     480 sl of visible screen
    VGA_VS_FP_SL,   // 484-493   10 sl of Front Porch
    VGA_VS_PULSE_SL,// 494-495   2 sl of Sync Pulse
    VGA_VS_BP_SL    // 496-523   28 sl of Back Porch
} vga_vs_states_t; 

// VGA horizontal states 341 cycles
typedef enum logic [2:0] {
    VGA_HS_VIS_CYC,  // 0-255    256 visible pixels
    VGA_HS_FP_CYC,   // 256-262  7 cycles of fp
    VGA_HS_PULSE_CYC,// 263-303  41 cycles of pulse
    VGA_HS_BP_CYC,   // 304-323  20 cycles of bp
    VGA_HS_IDLE_CYC  // 324-340  17 cycles of idle
} vga_hs_states_t;


// pattern table 
typedef enum logic {
    LEFT_TBL,  // 0x0000-0x0FFF
    RIGHT_TBL  // 0x1000-0x1FFF
} pattern_tbl_t;

// nametable 
typedef enum logic [1:0] {
    TOP_L_TBL,  // 0x2000
    TOP_R_TBL,  // 0x2400
    BOT_L_TBL,  // 0x2800
    BOT_R_TBL   // 0x2C00
} name_tbl_t;

typedef struct packed{
    logic active;
    logic [7:0] y_pos;
    logic [7:0] tile_idx;
    logic [7:0] attribute;
    logic [7:0] x_pos;
    logic [7:0] bitmap_hi;
    logic [7:0] bitmap_lo;
} second_oam_t;

typedef enum logic [3:0] {
    PPUCTRL,     // CPU's 0x2000
    PPUMASK,     // CPU's 0x2001
    PPUSTATUS,   // CPU's 0x2002
    OAMADDR,     // CPU's 0x2003
    OAMDATA,     // CPU's 0x2004
    PPUSCROLL,   // CPU's 0x2005
    PPUADDR,     // CPU's 0x2006
    PPUDATA,     // CPU's 0x2007
    OAMDMA       // CPU's 0x4014
} reg_t;

`endif