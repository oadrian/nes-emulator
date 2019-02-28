`default_nettype none

// inspired by ford seidel's vram module: 
// https://github.com/fseidel/PCE-HD/blob/master/src/rtl/HuC6270/VRAM.sv

`define oam_init

// oam is 64 bytes
`define WIDTH 6

module oam (
    input clk,    // Clock
    input clk_en, // Clock Enable (PPU clock = master clk/4)
    input rst_n,  // Asynchronous reset active low
    
    input logic [WIDTH-1:0] addr,
    input logic we, // write enable
    input logic [7:0] data_in,
    output logic [7:0] data_out,
);

    logic [7:0] mem[2**WIDTH-1:0]; //64 8-bit words

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            data_out <= 0;
            for (int i = 0; i < 2<<WIDTH; i++) begin
                mem[i] = 0;
            end
        `ifdef oam_init
            $readmemh("oam_init.hex", mem);
        `endif
        end else if(we && clk_en) begin
            mem[addr] <= data_in;
        end
    end

    assign data_out = mem[addr];

endmodule