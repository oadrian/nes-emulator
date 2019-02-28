`default_nettype none

// inspired by ford seidel's vram module: 
// https://github.com/fseidel/PCE-HD/blob/master/src/rtl/HuC6270/VRAM.sv

`define vram_init

// vram is 2KB 8 bit words
`define WIDTH 11

module vram (
    input clk,    // Clock
    input clk_en, // Clock Enable (PPU clock = master clk/4)
    input rst_n,  // Asynchronous reset active low
    
    input logic [WIDTH-1:0] addr1, addr2,
    input logic we1, we2, // write enable
    input logic [7:0] data_in1, data_in2,
    output logic [7:0] data_out1, data_out2
);

    logic [7:0] mem[2**WIDTH-1:0]; //2KB 8-bit words

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            data_out1 <= 0;
            data_out2 <= 0;
            for (int i = 0; i < 2<<WIDTH; i++) begin
                mem[i] = 0;
            end
        `ifdef vram_init
            $readmemh("vram_init.hex", mem);
        `endif
        end else if(clk_en) begin
            if(we1) begin
                mem[addr1] <= data_in1;
            end 
            if(we2) begin
                mem[addr2] <= data_in2;
            end
        end 
    end

    assign data_out1 = mem[addr1];
    assign data_out2 = mem[addr2];

endmodule