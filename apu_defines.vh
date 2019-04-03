`ifndef APU_DEFINES_VH_
`define APU_DEFINES_VH_

typedef struct packed {
  logic [1:0] pulse_en;
  logic triangle_en;
  logic noise_en;
  logic dmc_en;
} status_t;

typedef struct packed {
  logic [6:0] linear_load_data;
  logic length_halt;
  logic [10:0] timer_load_data;
  logic [4:0] length_load_data;
} triangle_t;

typedef struct packed {
  logic inhibit_interrupt;
  logic mode;
} frame_counter_t;
`endif
