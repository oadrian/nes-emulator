`default_nettype none

module save_state_module(
    input logic clock, reset_n,
    input logic [15:0] state_read_data,
    input logic [15:0] mem_read_data,

    input logic begin_save_state, begin_load_state, 

    output logic stall, state_write_en, state_read_en, 
    output logic [`SAVE_STATE_BITS-1:0] state_addr,
    output logic [15:0] sate_write_data,
    output logic mem_write_en, mem_read_en
    output logic [`SAVE_STATE_BITS-1:0] mem_addr,
    output logic [15:0] mem_write_data);

    logic [`SAVE_STATE_BITS-1:0] next_state_addr, next_mem_addr;
    logic next_state_read_en, next_state_write_en;
    logic nexT_mem_read_en, next_mem_write_en;

    enum logic {IDLE, SAVING, LOADING} state, next_state;

    assign mem_write_data = state_read_data;
    assign state_write_data = mem_read_data;

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
                next_mem_addr = state_addr;
                next_mem_write_en = 1'b1;
                if (state_addr == `SAVE_STATE_LAST_ADDRESS) begin
                    next_state = IDLE;
                    next_state_read_en = 1'b0;
                    next_state_addr = 'b0;
                end
                else begin
                    next_state = SAVING;
                    next_state_read_en = 1'b1;
                    next_state_addr = state_addr + 'b1;
                end
            end
            LOADING: begin
                next_state_addr = mem_addr;
                next_state_write_en = 1'b1;
                if (state_addr == `SAVE_STATE_LAST_ADDRESS) begin
                    next_state = IDLE;
                    next_mem_read_en = 1'b0;
                    next_mem_addr = 'b0;
                end
                else begin
                    next_state = LOADING;
                    next_mem_read_en = 1'b0;
                    next_mem_addr = mem_addr + 'b1;
                end
            end
        endcase
    end

    always_ff @(posedge clock, negedge reset_n) begin
        if (reset_n) begin
            state <= IDLE;
            state_addr <= 'b0;
            state_read_en <= 1'b0;
            state_write_en <= 1'b0;
            mem_addr <= 'b0;
            mem_read_en <= 1'b0;
            mem_write_en <= 1'b0;
        end
        else begin
            state <= next_state;
            state_addr <= next_state_addr;
            state_read_en <= next_state_read_en;
            state_write_en <= next_state_write_en;
            mem_addr <= next_mem_addr;
            mem_read_en <= nexT_mem_read_en;
            mem_write_en <= next_mem_write_en;
        end
    end



endmodule : save_state_module