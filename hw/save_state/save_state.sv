`default_nettype none

module save_state_module(
    input logic clock, reset_n,
    input logic [15:0] state_read_data,
    input logic [15:0] mem_read_data,

    input logic begin_save_state, begin_load_state, 

    output logic stall, state_write_en, state_read_en, 
    output logic [`SAVE_STATE_BITS-1:0] state_addr,
    output logic [15:0] state_write_data,
    output logic mem_write_en, mem_read_en,
    output logic [`SAVE_STATE_BITS-1:0] mem_addr,
    output logic [15:0] mem_write_data);

    logic [`SAVE_STATE_BITS-1:0] next_state_addr, next_mem_addr;
    logic next_state_read_en, next_state_write_en;
    logic next_mem_read_en, next_mem_write_en;

    enum logic[1:0] {IDLE, SAVING, LOADING} state, next_state;

    always_comb begin
        stall = 1'b1;
        next_mem_addr = 'b0;
        next_mem_read_en = 1'b0;
        next_mem_write_en = 1'b0;
        next_state_addr = 'b0;
        next_state_read_en = 1'b0;
        next_state_write_en = 1'b0;
        next_state = IDLE;


        case (state)
            IDLE: begin 
                if (begin_save_state) begin
                    next_state = SAVING;
                    next_state_read_en = 1'b1;
                    next_state_addr = 'b0;
                end
                else if (begin_load_state) begin
                    next_state = LOADING;
                    next_mem_read_en = 1'b1;
                    next_mem_addr = 'b0;
                end
                else begin
                    stall = 1'b0;
                    next_state = IDLE;
                    next_state_read_en = 1'b0;
                    next_state_addr = 'b0;
                    next_mem_read_en = 1'b0;
                    next_mem_addr = 'b0;
                end
            end


            SAVING: begin
                next_state = SAVING;

                if (state_addr == 'b0 && !state_read_en) begin
                    next_state_read_en = 1'b0;
                    next_state_addr = 'b0;
                end
                else if (state_addr == `SAVE_STATE_LAST_ADDRESS) begin
                    next_state_read_en = 1'b0;
                    next_state_addr = 'b0;
                end
                else begin
                    next_state_read_en = 1'b1;
                    next_state_addr = state_addr + 'b1;
                end


                if (state_addr == 'b0 && state_read_en) begin
                    next_mem_addr = 'b0;
                    next_mem_write_en = 1'b0;
                end
                else if (state_addr == 'b1) begin
                    next_mem_addr = 'b0;
                    next_mem_write_en = 1'b1;
                end
                else if (mem_addr < `SAVE_STATE_LAST_ADDRESS) begin
                    next_mem_addr = mem_addr + 'b1;
                    next_mem_write_en = 1'b1;
                end
                else begin
                    // mem_addr == `SAVE_STATE_LAST_ADDRESS
                    next_state = IDLE;
                    next_mem_addr = 'b0;
                    next_mem_write_en = 1'b0;
                end
            end


            LOADING: begin
                next_state = LOADING;

                if (mem_addr == 'b0 && !mem_read_en) begin
                    next_mem_read_en = 1'b0;
                    next_mem_addr = 'b0;
                end
                else if (mem_addr == `SAVE_STATE_LAST_ADDRESS) begin
                    next_mem_read_en = 1'b0;
                    next_mem_addr = 'b0;
                end
                else begin
                    next_mem_read_en = 1'b1;
                    next_mem_addr = mem_addr + 'b1;
                end


                if (mem_addr == 'b0 && mem_read_en) begin
                    next_state_addr = 'b0;
                    next_state_write_en = 1'b0;
                end
                else if (mem_addr == 'b1) begin
                    next_state_addr = 'b0;
                    next_state_write_en = 1'b1;
                end
                else if (state_addr < `SAVE_STATE_LAST_ADDRESS) begin
                    next_state_addr = state_addr + 'b1;
                    next_state_write_en = 1'b1;
                end
                else begin
                    // state_addr == `SAVE_STATE_LAST_ADDRESS
                    next_state = IDLE;
                    next_state_addr = 'b0;
                    next_state_write_en = 1'b0;
                end
            end
        endcase

    end

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            state_write_data <= 16'b0;
            state_addr <= 'b0;
            state_read_en <= 1'b0;
            state_write_en <= 1'b0;
            mem_write_data <= 16'b0;
            mem_addr <= 'b0;
            mem_read_en <= 1'b0;
            mem_write_en <= 1'b0;

        end
        else begin
            state <= next_state;
            state_write_data <= mem_read_data;
            state_addr <= next_state_addr;
            state_read_en <= next_state_read_en;
            state_write_en <= next_state_write_en;
            mem_write_data <= state_read_data;
            mem_addr <= next_mem_addr;
            mem_read_en <= next_mem_read_en;
            mem_write_en <= next_mem_write_en;
        end
    end



endmodule : save_state_module
    

module save_data_router(
    input logic clock, reset_n,

    output logic[15:0] save_data,

    input  logic[15:0] cpu_save_data, mem_save_data,
    input  logic[`SAVE_STATE_BITS-1:0] state_addr);

    logic [`SAVE_STATE_BITS-1:0] prev_state_addr;

    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n) begin
            prev_state_addr <= 'b0;
        end
        else begin
            prev_state_addr <= state_addr;
        end
    end

    always_comb begin
        if (prev_state_addr <= `SAVE_STATE_CPU_ALU_N_OUT) save_data = cpu_save_data;
        else save_data = mem_save_data;
    end

endmodule : save_data_router