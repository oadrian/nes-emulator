`default_nettype none
`include "../include/cpu_types.vh"
`include "../include/ucode_ctrl.vh"
`include "../include/ppu_defines.vh"

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

    logic nmi;
    assign nmi = 1'b1;

    assign clock_en = 1'b1;

    logic irq_n;
    assign irq_n = 1'b1;

    logic [15:0] PC_debug;

    reg_t reg_sel;
    logic reg_en;
    logic reg_rw;
    logic [7:0] reg_data_wr;
    logic [7:0] reg_data_rd; 
    logic up, down, start, select, left, right, A, B;
    logic [7:0] read_prom;

    core cpu(.*);
    cpu_memory mem(.addr, .r_en(mem_r_en), .w_data, 
                   .clock, .clock_en, .reset_n, .r_data, .*);

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

    logic check_07ff;

    processor_state_t prev_state;

    always_ff @(posedge clock or negedge reset_n) begin
        if(~reset_n) begin
            prev_state <= STATE_FETCH;
            check_07ff <= 0;
        end else begin
            prev_state <= cpu.state;
            check_07ff <= addr == 16'h07FF;
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
        //@(posedge clock);
        //$display("%p",mem.cartridge_mem);
        cnt = 0;
        // should be 26555
        while(cnt+7 < 26555) begin
            //$display("lol"); 

            if (addr == 16'h07FF) begin
                //$display("d addr: 0x07FF, r:%b, r_data:%.2x, w_data:%.2x, CYC:%1.d", mem_r_en, r_data, w_data, cnt+7);
                //$strobe("s addr: 0x07FF, r:%b, r_data:%.2x, w_data:%.2x, CYC:%1.d", mem_r_en, r_data, w_data, cnt+7);
            end

            if (check_07ff) begin
                //$display("data 0x07FF:%.2x, r_data:%.2x CYC:%1.d", mem.ram[2047], r_data, cnt+7);
            end

            if(cpu.state == STATE_DECODE) begin 
                $fwrite(fd,"%.4x %.2x ", cpu.PC-16'b1, r_data);
                $fwrite(fd,"A:%.2x X:%.2x Y:%.2x P:%.2x SP:%.2x CYC:%1.d\n",
                        can_A, can_X, can_Y, can_status, can_SP, cnt+7);
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