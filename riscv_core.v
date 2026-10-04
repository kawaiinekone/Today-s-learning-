`timescale 1ns / 1ps

module riscv_core (
    input  wire        clk,
    input  wire        rst_n
);

    // --- STAGE 1: FETCH WIRES ---
    wire [31:0] if_pc;
    wire [31:0] if_instr;
    wire [31:0] next_pc;
    wire        stall;
    wire        flush;

    // --- PIPELINE REGISTER 1 (IF/ID) WIRES ---
    wire [31:0] id_pc;
    wire [31:0] id_instr;

    // --- STAGE 2: DECODE & EXECUTE WIRES ---
    wire [4:0]  rs1_addr = id_instr[19:15];
    wire [4:0]  rs2_addr = id_instr[24:20];
    wire [4:0]  id_rd_addr = id_instr[11:7];

    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] imm;
    wire [1:0]  alu_op;
    wire        alu_src;
    wire        id_reg_write;
    wire        id_mem_read;
    wire        id_mem_write;
    wire        id_mem_to_reg;
    wire        branch;
    wire        jump;
    wire [3:0]  alu_ctrl;
    wire [31:0] alu_result;
    wire        zero;
    wire        branch_taken_cond;
    wire        pc_src;
    wire [31:0] branch_target;

    // --- PIPELINE REGISTER 2 (ID/WB) WIRES ---
    wire        wb_reg_write;
    wire        wb_mem_to_reg;
    wire        wb_mem_read;
    wire        wb_mem_write;
    wire [4:0]  wb_rd_addr;
    wire [31:0] wb_alu_result;
    wire [31:0] wb_rs2_data;

    // --- STAGE 3: WRITEBACK WIRES ---
    wire [31:0] mem_rdata;
    wire [31:0] wb_wr_data;

    // ========================================================
    // BRICK 1: Program Counter
    // ========================================================
    pc_reg u_pc (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .next_pc(next_pc),
        .pc(if_pc)
    );

   // ========================================================
    // BRICK 2: Instruction Memory
    // ========================================================
    imem u_imem (
        .pc(if_pc),
        .instr(if_instr)
    );

    // ========================================================
    // BRICK 3: IF/ID Pipeline Register
    // ========================================================
    if_id_reg u_if_id (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .flush(flush),
        .if_pc(if_pc),
        .if_instr(if_instr),
        .id_pc(id_pc),
        .id_instr(id_instr)
    );

    // ========================================================
    // BRICK 4: Register File
    // ========================================================
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

    // ========================================================
    // BRICK 5: Immediate Generator
    // ========================================================
    imm_gen u_imm (
        .instr(id_instr),
        .imm(imm)
    );

    // ========================================================
    // BRICK 6: Control Unit
    // ========================================================
    control_unit u_cu (
        .opcode(id_instr[6:0]),
        .reg_write(id_reg_write),
        .alu_src(alu_src),
        .alu_op(alu_op),
        .mem_read(id_mem_read),
        .mem_write(id_mem_write),
        .mem_to_reg(id_mem_to_reg),
        .branch(branch),
        .jump(jump)
    );

    // ========================================================
    // BRICK 7: ALU Control Unit
    // ========================================================
    alu_ctrl_unit u_alu_cu (
        .alu_op(alu_op),
        .funct3(id_instr[14:12]),
        .funct7(id_instr[31:25]),
        .alu_ctrl(alu_ctrl)
    );

   // ========================================================
    // FORWARDING UNIT (1-Cycle RAW Hazard Resolution)
    // ========================================================
    wire forward_a = wb_reg_write && (wb_rd_addr != 5'd0) && (wb_rd_addr == rs1_addr);
    wire forward_b = wb_reg_write && (wb_rd_addr != 5'd0) && (wb_rd_addr == rs2_addr);

    wire [31:0] fwd_rs1_data = (forward_a) ? wb_wr_data : rs1_data;
    wire [31:0] fwd_rs2_data = (forward_b) ? wb_wr_data : rs2_data;
    wire [31:0] raw_op_b     = (alu_src)   ? imm         : fwd_rs2_data;

    // ========================================================
    // INNOVATION 2: GREEN-HEART ECO-GATE (Operand Isolation)
    // Clamps ALU inputs when ALU calculation is not needed (NOPs, Branches, Jumps)
    // ========================================================
    wire is_alu_active = (id_instr != 32'h00000013) && (id_reg_write || id_mem_read || id_mem_write);

    wire [31:0] gated_alu_a = (is_alu_active) ? fwd_rs1_data : 32'h00000000;
    wire [31:0] gated_alu_b = (is_alu_active) ? raw_op_b     : 32'h00000000;

    // ========================================================
    // BRICK 8: ALU (With Innovation 1: Popcount Accelerator)
    // ========================================================
    alu u_alu (
        .alu_ctrl(alu_ctrl),
        .a(gated_alu_a),
        .b(gated_alu_b),
        .result(alu_result),
        .zero(zero)
    );

   // ========================================================
    // BRICK 9: Branch Comparator
    // ========================================================
    branch_comp u_bc (
        .funct3(id_instr[14:12]),
        .rs1_data(fwd_rs1_data),
        .rs2_data(fwd_rs2_data),
        .branch_taken(branch_taken_cond)
    );

    assign pc_src        = (branch && branch_taken_cond) || jump;
    assign branch_target = id_pc + imm;
    assign next_pc       = (pc_src) ? branch_target : (if_pc + 32'd4);

    // Pipeline Hazards: flush on taken branch/jump
    assign flush = pc_src;
    assign stall = 1'b0; // Minimal hazard stall logic

    // ========================================================
    // BRICK 10: ID/WB Pipeline Register
    // ========================================================
    reg        r_wb_reg_write;
    reg        r_wb_mem_to_reg;
    reg        r_wb_mem_read;
    reg        r_wb_mem_write;
    reg [4:0]  r_wb_rd_addr;
    reg [31:0] r_wb_alu_result;
    reg [31:0] r_wb_rs2_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_wb_reg_write  <= 1'b0;
            r_wb_mem_to_reg <= 1'b0;
            r_wb_mem_read   <= 1'b0;
            r_wb_mem_write  <= 1'b0;
            r_wb_rd_addr    <= 5'd0;
            r_wb_alu_result <= 32'h0;
            r_wb_rs2_data   <= 32'h0;
        end else begin
            r_wb_reg_write  <= id_reg_write;
            r_wb_mem_to_reg <= id_mem_to_reg;
            r_wb_mem_read   <= id_mem_read;
            r_wb_mem_write  <= id_mem_write;
            r_wb_rd_addr    <= id_rd_addr;
            r_wb_alu_result <= alu_result;
           r_wb_rs2_data   <= fwd_rs2_data;
        end
    end

    assign wb_reg_write  = r_wb_reg_write;
    assign wb_mem_to_reg = r_wb_mem_to_reg;
    assign wb_mem_read   = r_wb_mem_read;
    assign wb_mem_write  = r_wb_mem_write;
    assign wb_rd_addr    = r_wb_rd_addr;
    assign wb_alu_result = r_wb_alu_result;
    assign wb_rs2_data   = r_wb_rs2_data;

    // ========================================================
    // BRICK 11: Data Memory
    // ========================================================
    dmem u_dmem (
        .clk(clk),
        .mem_read(wb_mem_read),
        .mem_write(wb_mem_write),
        .addr(wb_alu_result),
        .wr_data(wb_rs2_data),
        .rd_data(mem_rdata)
    );

    // ========================================================
    // BRICK 12: Writeback Mux
    // ========================================================
    wb_mux u_wb_mux (
        .mem_to_reg(wb_mem_to_reg),
        .alu_result(wb_alu_result),
        .mem_rdata(mem_rdata),
        .wb_data(wb_wr_data)
    );

endmodule