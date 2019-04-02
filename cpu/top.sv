`default_nettype none
`include "cpu-types.vh"
`include "ucode_ctrl.vh"

module top ();
    string logFile = "logs/cpu-out.log.txt";

    logic clock;
    logic reset_n;
    default clocking cb_main @(posedge clock); endclocking

    logic [15:0] addr;
    logic mem_r_en;
    logic [7:0] w_data;

    logic [7:0] r_data;
    logic clock_en;

    assign clock_en = 1'b1;

    core cpu(.*);
    cpu_memory mem(.addr, .r_en(mem_r_en), .w_data, 
                   .clock, .clock_en, .reset_n, .r_data);

    initial begin 
        clock = 1'b0;
        forever #5 clock = ~clock;
    end

    // Conduct a system reset
    task doReset;
        reset_n = 1'b1;
        reset_n <= 1'b0;

        #1 reset_n <= 1'b1;
    endtask : doReset

    int fd;
    int cnt;

    processor_state_t prev_state;

    always_ff @(posedge clock or negedge reset_n) begin
        if(~reset_n) begin
            prev_state <= STATE_NEITHER;
        end else begin
            prev_state <= cpu.state;
        end
    end

    logic [7:0] can_A, can_X, can_Y, can_status, can_SP;
    logic can_n, can_v, can_d, can_i, can_z, can_c;

    assign can_A = (cpu.A_en) ? cpu.next_A : cpu.A;
    assign can_X = (cpu.X_en) ? cpu.next_X : cpu.X;
    assign can_Y = (cpu.Y_en) ? cpu.next_Y : cpu.Y;
    assign can_SP = (cpu.SP_en) ? cpu.next_SP : cpu.SP;

    assign can_n = (cpu.n_flag_en) ? cpu.next_n_flag : cpu.n_flag;
    assign can_v = (cpu.v_flag_en) ? cpu.next_v_flag : cpu.v_flag;
    assign can_d = (cpu.d_flag_en) ? cpu.next_d_flag : cpu.d_flag;
    assign can_i = (cpu.i_flag_en) ? cpu.next_i_flag : cpu.i_flag;
    assign can_z = (cpu.z_flag_en) ? cpu.next_z_flag : cpu.z_flag;
    assign can_c = (cpu.c_flag_en) ? cpu.next_c_flag : cpu.c_flag;

    assign can_status = {can_n, can_v, 1'b1, 1'b0, 
                         can_d, can_i, can_z, can_c};
    initial begin
        fd = $fopen(logFile,"w");
        doReset;
        @(posedge clock);
        @(posedge clock);
        @(posedge clock);
        $display("%p",mem.cartridge_mem);
        cnt = 0;
        while(cnt < 26555) begin 
            if(cpu.state == STATE_DECODE) begin 
                $fwrite(fd,"%.4x %.2x", cpu.PC-1, r_data);
                $fwrite(fd,"A:%.2x X:%.2x Y:%.2x P:%.2x SP:%.2x CYC:%d\n",
                        can_A, can_X, can_Y, can_status, can_SP, cnt);
            end
            @(posedge clock);
            cnt++;
        end
        @(posedge clock);
        @(posedge clock);
        @(posedge clock);
        @(posedge clock);
        $finish;
    end

endmodule