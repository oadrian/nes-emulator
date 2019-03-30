`default_nettype none

// inspired by ford seidel's vram module: 
// https://github.com/fseidel/PCE-HD/blob/master/src/rtl/HuC6270/VRAM.sv

`define oam_init

// `define SYNTH

// oam is 256 bytes  (64 sprites each of 4 bytes)
`define OAM_WIDTH 8

module oam (
    input clk,    // Clock
    input clk_en, // Clock Enable (PPU clock = master clk/4)
    input rst_n,  // Asynchronous reset active low
    
    input logic [`OAM_WIDTH-1:0] addr,
    input logic we, // write enable
    input logic [7:0] data_in,
    output logic [7:0] data_out
);
    `ifdef SYNTH
    oam_synth o_sy(.address(addr), .clock(clk), .data(data_in), .wren(we), .q(data_out));
    `else 
    logic [7:0] mem[2**`OAM_WIDTH-1:0]; //64 sprites each 4 bytes 

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            for (int i = 0; i < 1<<`OAM_WIDTH; i++) begin
                mem[i] = 0;
            end
        `ifdef oam_init
            $readmemh("init/oam_init.txt", mem);
        `endif
        end else if(we && clk_en) begin
            mem[addr] <= data_in;
        end
    end

    assign data_out = mem[addr];

    `endif
endmodule