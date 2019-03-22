`default_nettype none

// inspired by ford seidel's vram module: 
// https://github.com/fseidel/PCE-HD/blob/master/src/rtl/HuC6270/VRAM.sv

`define pal_init

// pal_ram is 32 bytes
`define PAL_RAM_WIDTH 5

module pal_ram (
    input clk,    // Clock
    input clk_en, // Clock Enable (PPU clock = master clk/4)
    input rst_n,  // Asynchronous reset active low
    
    input logic [`PAL_RAM_WIDTH-1:0] addr,
    input logic we, // write enable
    input logic [7:0] data_in,
    output logic [7:0] data_out
);

    logic [7:0] mem[2**`PAL_RAM_WIDTH-1:0]; //32 8-bit words

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            for (int i = 0; i < 1<<`PAL_RAM_WIDTH; i++) begin
                mem[i] = 0;
            end
        `ifdef pal_init
            $readmemh("init/pal_init.txt", mem);
        `endif
        end else if(we && clk_en) begin
            mem[addr] <= data_in;
        end
    end

    assign data_out = mem[addr];

endmodule