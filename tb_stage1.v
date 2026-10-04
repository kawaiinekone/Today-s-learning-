`timescale 1ns / 1ps

module tb_stage1;

    reg         clk;
    reg         rst_n;
    reg         stall;
    reg         flush;
    reg  [31:0] next_pc;

    wire [31:0] if_pc;
    wire [31:0] if_instr;
    wire [31:0] id_pc;
    wire [31:0] id_instr;

    pc_reg u_pc (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .next_pc(next_pc),
        .pc(if_pc)
    );

    imem u_imem (
        .pc(if_pc),
        .instr(if_instr)
    );

    if_id_reg u_pipe_reg (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .flush(flush),
        .if_pc(if_pc),
        .if_instr(if_instr),
        .id_pc(id_pc),
        .id_instr(id_instr)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("stage1.vcd");
        $dumpvars(0, tb_stage1);

        u_imem.mem[0] = 32'h00500093; // addi x1, x0, 5
        u_imem.mem[1] = 32'h00a00113; // addi x2, x0, 10
        u_imem.mem[2] = 32'h002081b3; // add  x3, x1, x2
        u_imem.mem[3] = 32'h00000013; // nop

        clk     = 0;
        rst_n   = 0;
        stall   = 0;
        flush   = 0;
        next_pc = 32'h0;

        #15 rst_n = 1;

        #10 next_pc = if_pc + 4;
        #10 next_pc = if_pc + 4;
        #10 next_pc = if_pc + 4;

        #10 stall = 1;
        #20 stall = 0;
            next_pc = if_pc + 4;

        #10 flush = 1;
        #10 flush = 0;

        #30;
        $finish;
    end

endmodule