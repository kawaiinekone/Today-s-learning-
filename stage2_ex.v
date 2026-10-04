`timescale 1ns / 1ps

module stage2_ex (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] instr,
    input  wire [31:0] pc,
    // Feedback from Writeback Stage
    input  wire        wb_reg_write,
    input  wire [4:0]  wb_rd_addr,
    input  wire [31:0] wb_wr_data,
    // Outputs to Stage 3 Pipeline Register / Latch
    output wire [4:0]  rd_addr,
    output wire [31:0] alu_result,
    output wire [31:0] rs2_data,
    output wire        reg_write,
    output wire        mem_to_reg,
    output wire        mem_write,
    output wire        mem_read,
    output wire        branch_taken,
    output wire [31:0] branch_target
);

    wire [4:0]  rs1_addr = instr[19:15];
    wire [4:0]  rs2_addr = instr[24:20];
    assign      rd_addr  = instr[11:7];

    wire [31:0] rs1_data;
    wire [31:0] imm;
    wire [1:0]  alu_op;
    wire        alu_src;
    wire        branch;
    wire        jump;
    wire [3:0]  alu_ctrl;
    wire        zero;
    wire        cond_taken;

    // Brick 4: Register File
    reg_file u_rf (
        .clk(clk),
        .rst_n(rst_n),
        .we(wb_reg_write),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(wb_rd_addr),
        .wr_data(wb_wr_data),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    // Brick 5: Immediate Generator
    imm_gen u_imm (
        .instr(instr),
        .imm(imm)
    );

    // Brick 6: Control Unit
    control_unit u_cu (
        .opcode(instr[6:0]),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .alu_op(alu_op),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .branch(branch),
        .jump(jump)
    );

    // Brick 7: ALU Control Unit
    alu_ctrl_unit u_alu_cu (
        .alu_op(alu_op),
        .funct3(instr[14:12]),
        .funct7(instr[31:25]),
        .alu_ctrl(alu_ctrl)
    );

    // Operand B Selection (Register vs Immediate)
    wire [31:0] alu_operand_b = (alu_src) ? imm : rs2_data;

    // Brick 8: ALU
    alu u_alu (
        .alu_ctrl(alu_ctrl),
        .a(rs1_data),
        .b(alu_operand_b),
        .result(alu_result),
        .zero(zero)
    );

    // Brick 9: Branch Comparator
    branch_comp u_bc (
        .funct3(instr[14:12]),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .branch_taken(cond_taken)
    );

    assign branch_taken  = (branch && cond_taken) || jump;
    assign branch_target = pc + imm;

endmodule