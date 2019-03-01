`ifndef PPU_DEFINES_VH_
`define PPU_DEFINES_VH_

// Number of scanlines per frame
`define NUM_SCANLINES 262

// Number of cycles per scanline
`define CYCLES_IN_SL 341

// Active pixel screen size
`define SCREEN_WIDTH 256
`define SCREEN_HEIGHT 240


// Vertical scanline states
typedef enum logic [1:0] {
    PRE_SL,  // 0
    VIS_SL,  // 1-240 
    POST_SL, // 241
    VBLANK_SL // 242-261
} vs_state_t;

// Horizontal cycles states
typedef enum logic [2:0] {
    SL_PRE_CYC, // 0-255
    IDLE_CYC,    // 256
    SP_PRE_CYC,  // 257-320 
    TL_PRE_CYC,  // 321-336
    GARB_CYC     // 337-340
} hs_state_t;


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

`endif