`timescale 1ns / 1ps

module tb_stage2;

    reg         clk;
    reg         rst_n;
    reg  [31:0] instr;
    reg  [31:0] pc;
    reg         wb_reg_write;
    reg  [4:0]  wb_rd_addr;
    reg  [31:0] wb_wr_data;

    wire [4:0]  rd_addr;
    wire [31:0] alu_result;
    wire [31:0] rs2_data;
    wire        reg_write;
    wire        mem_to_reg;
    wire        mem_write;
    wire        mem_read;
    wire        branch_taken;
    wire [31:0] branch_target;

    stage2_ex dut (
        .clk(clk),
        .rst_n(rst_n),
        .instr(instr),
        .pc(pc),
        .wb_reg_write(wb_reg_write),
        .wb_rd_addr(wb_rd_addr),
        .wb_wr_data(wb_wr_data),
        .rd_addr(rd_addr),
        .alu_result(alu_result),
        .rs2_data(rs2_data),
        .reg_write(reg_write),
        .mem_to_reg(mem_to_reg),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .branch_taken(branch_taken),
        .branch_target(branch_target)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("stage2.vcd");
        $dumpvars(0, tb_stage2);

        clk          = 0;
        rst_n        = 0;
        instr        = 32'h00000013; // nop
        pc           = 32'h0;
        wb_reg_write = 0;
        wb_rd_addr   = 0;
        wb_wr_data   = 0;

        #15 rst_n = 1;

        // Test 1: addi x1, x0, 15 (0x00f00093)
        #10 instr = 32'h00f00093;
        #10 wb_reg_write = 1; wb_rd_addr = 5'd1; wb_wr_data = alu_result;

        // Test 2: addi x2, x0, 25 (0x01900113)
        #10 wb_reg_write = 0; instr = 32'h01900113;
        #10 wb_reg_write = 1; wb_rd_addr = 5'd2; wb_wr_data = alu_result;

        // Test 3: add x3, x1, x2 (0x002081b3) -> Result should be 40 (0x28)
        #10 wb_reg_write = 0; instr = 32'h002081b3;
        #10 wb_reg_write = 1; wb_rd_addr = 5'd3; wb_wr_data = alu_result;

        // Test 4: sub x4, x3, x1 (0x40118233) -> Result should be 25 (0x19)
        #10 wb_reg_write = 0; instr = 32'h40118233;
        #10 wb_reg_write = 1; wb_rd_addr = 5'd4; wb_wr_data = alu_result;

        #20;
        $finish;
    end

endmodule