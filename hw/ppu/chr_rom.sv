`default_nettype none

// inspired by ford seidel's vram module: 
// https://github.com/fseidel/PCE-HD/blob/master/src/rtl/HuC6270/VRAM.sv

`define chr_rom_init

`define SYNTH

// chr rom is 8KB 8 bit words
`define CHR_ROM_WIDTH 13

module chr_rom (
    input clk,    // Clock
    input clk_en, // Clock Enable (PPU clock = master clk/4)
    input rst_n,  // Asynchronous reset active low
    
    input logic [`CHR_ROM_WIDTH-1:0] addr1,
    input logic [`CHR_ROM_WIDTH-1:0] addr2,
    
    output logic [7:0] data_out1,
    output logic [7:0] data_out2
);
	`ifdef SYNTH
	rom r_bb(.address_a(addr1), .address_b(addr2), .clock(clk), .q_a(data_out1), .q_b(data_out2));
	`else

    logic [7:0] mem[2**`CHR_ROM_WIDTH-1:0]; //2KB 8-bit words

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
           for (int i = 0; i < 1<<`CHR_ROM_WIDTH; i++) begin
               mem[i] = 0;
           end
        `ifdef chr_rom_init
            $readmemh("init/chr_rom_init.txt", mem);
        `endif
        end
    end

    assign data_out1 = mem[addr1];
    assign data_out2 = mem[addr2];

	 `endif
endmodule