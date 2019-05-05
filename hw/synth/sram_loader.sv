`default_nettype none

`define HEADER_SIZE 16'd32
`define PRG_SIZE 16'd32768
`define CHR_SIZE 16'd8192

`define HEADER_OFFSET 16'd0
`define PRG_OFFSET 16'd32
`define CHR_OFFSET 16'd32800

module sram_loader (
    input clk,    // Clock
    input rst_n,  // Asynchronous reset active low

    input logic [4:0] game_select,
    input logic start_load,
    output logic done_load,

    // SRAM interface
    output logic [19:0] SRAM_ADDR,
    output logic SRAM_CE_N,
    inout  logic [15:0] SRAM_DQ,
    output logic SRAM_LB_N,
    output logic SRAM_OE_N,
    output logic SRAM_UB_N,
    output logic SRAM_WE_N,

    // PRG RAM
    output logic [14:0] prg_rom_addr,
    output logic prg_rom_we,
    output logic [7:0] prg_rom_wr_data,

    // CHR RAM
    output logic [12:0] chr_rom_addr,
    output logic chr_rom_we,
    output logic [7:0] chr_rom_wr_data,

    // HEADER RAM
    output logic [4:0] header_addr,
    output logic header_we,
    output logic [7:0] header_wr_data
);

    
    enum logic [2:0] {IDLE, WRITE_HEADER, WRITE_PRG, WRITE_CHR, DONE} 
                curr_state, next_state;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            curr_state <= IDLE;
        end else begin
            curr_state <= next_state;
        end
    end

    logic [14:0] addr;
    logic addr_clr, addr_inc;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            addr <= 14'd0;
        end else begin
            if(addr_clr)
                addr <= 14'd0;
            else if(addr_inc)
                addr <= addr + 14'd1;
        end
    end

    logic [15:0] full_addr, offset, offset_in;
    logic offset_ld;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            offset <= 0;
        end else begin
            if(offset_ld)
                offset <= offset_in;
        end
    end

    assign offset_in = (curr_state == IDLE) ? `HEADER_OFFSET :
                       (curr_state == WRITE_HEADER) ? `PRG_OFFSET : 
                       (curr_state == WRITE_PRG) ? `CHR_OFFSET : 16'd0;
 
    assign full_addr = {1'b0, addr} + offset;

    assign SRAM_ADDR = {game_select, full_addr[15:1]};
    assign SRAM_LB_N = ~(full_addr[0] == 1'b0);
    assign SRAM_UB_N = ~(full_addr[0] == 1'b1);
    assign SRAM_CE_N = (curr_state == IDLE);
    assign SRAM_OE_N = 1'b0; // output should always be enabled
    assign SRAM_WE_N = 1'b1; // just read the SRAM

    assign SRAM_DQ = 15'hz;

    assign header_addr = addr[4:0];
    assign prg_rom_addr = addr[14:0];
    assign chr_rom_addr = addr[12:0];

    logic [7:0] sram_rd_data;
    assign sram_rd_data = (full_addr[0]) ? SRAM_DQ[15:8] : SRAM_DQ[7:0];

    assign header_wr_data = sram_rd_data;
    assign prg_rom_wr_data = sram_rd_data;
    assign chr_rom_wr_data = sram_rd_data;

    always_comb begin
        // Address 
        addr_clr = 1'b0;
        addr_inc = 1'b0;

        // offset 
        offset_ld = 1'b0;

        // prg rom
        prg_rom_we = 1'b0;

        // chr rom
        chr_rom_we = 1'b0;

        // header rom
        header_we = 1'b0;

        // next state
        next_state = curr_state;

        // done
        done_load = 1'b0;

        case (curr_state)
            IDLE: begin
                next_state = (start_load) ? WRITE_HEADER : IDLE;
                offset_ld = (start_load) ? 1'b1 : 1'b0;
                addr_clr = (start_load) ? 1'b1 : 1'b0;
            end
            WRITE_HEADER: begin 
                addr_inc = 1'b1;

                addr_clr = (addr == `HEADER_SIZE - 16'd1) ? 1'b1 : 1'b0;
                next_state = (addr == `HEADER_SIZE - 16'd1) ? WRITE_PRG : WRITE_HEADER;
                offset_ld = (addr == `HEADER_SIZE - 16'd1) ? 1'b1 : 1'b0;

                header_we = 1'b1;
            end
            WRITE_PRG: begin 
                addr_inc = 1'b1;

                addr_clr = (addr == `PRG_SIZE - 16'd1) ? 1'b1 : 1'b0;
                next_state = (addr == `PRG_SIZE - 16'd1) ? WRITE_CHR : WRITE_PRG;
                offset_ld = (addr == `PRG_SIZE - 16'd1) ? 1'b1 : 1'b0;

                prg_rom_we = 1'b1;
            end
            WRITE_CHR: begin 
                addr_inc = 1'b1;
                
                addr_clr = (addr == `CHR_SIZE - 16'd1) ? 1'b1 : 1'b0;
                next_state = (addr == `CHR_SIZE - 16'd1) ? DONE : WRITE_CHR;
                offset_ld = (addr == `CHR_SIZE - 16'd1) ? 1'b1 : 1'b0;

                chr_rom_we = 1'b1;
            end
            DONE: begin 
                done_load = 1'b1;
            end
            default : /* default */;
        endcase
    end



endmodule