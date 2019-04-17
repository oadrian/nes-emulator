`default_nettype none

`define SYNTH
`ifdef NO_SYNTH
`undef SYNTH
`endif

`define chr_rom_init
`define oam_init
`define vram_init
`define pal_init

// chr rom is 8KB 8 bit words
`define CHR_ROM_WIDTH 13
// oam is 256 bytes  (64 sprites each of 4 bytes)
`define OAM_WIDTH 8
// vram is 2KB 8 bit words
`define VRAM_WIDTH 11
// pal_ram is 32 bytes
`define PAL_RAM_WIDTH 5

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
            $readmemh("../init/chr_rom_init.txt", mem);
        `endif
        end
    end

    assign data_out1 = mem[addr1];
    assign data_out2 = mem[addr2];

     `endif
endmodule

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
            $readmemh("../init/oam_init.txt", mem);
        `endif
        end else if(we && clk_en) begin
            mem[addr] <= data_in;
        end
    end

    assign data_out = mem[addr];

    `endif
endmodule

module vram (
    input clk,    // Clock
    input clk_en, // Clock Enable (PPU clock = master clk/4)
    input rst_n,  // Asynchronous reset active low
    
    input logic [`VRAM_WIDTH-1:0] addr1, addr2,
    input logic we1, we2, // write enable
    input logic [7:0] data_in1, data_in2,
    output logic [7:0] data_out1, data_out2
);
    `ifdef SYNTH
    vram_synth v_sy(.address_a(addr1), .address_b(addr2), .clock(clk), 
                    .data_a(data_in1), .data_b(data_in2), 
                    .wren_a(we1), .wren_b(we2),
                    .q_a(data_out1), .q_b(data_out2));
    `else 
    logic [7:0] mem[2**`VRAM_WIDTH-1:0]; //2KB 8-bit words

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            for (int i = 0; i < 1<<`VRAM_WIDTH; i++) begin
                mem[i] = 0;
            end
        `ifdef vram_init
            $readmemh("../init/vram_init.txt", mem);
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

    `endif
endmodule

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
            $readmemh("../init/pal_init.txt", mem);
        `endif
        end else if(clk_en && we) begin
            mem[addr] <= data_in;
        end
    end

    assign data_out = mem[addr];

endmodule