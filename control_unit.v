`timescale 1ns / 1ps

module control_unit (
    input  wire [6:0] opcode,
    output reg        reg_write,
    output reg        alu_src,    // 0 = rs2, 1 = imm
    output reg  [1:0] alu_op,     // 00: Load/Store, 01: Branch, 10: R/I-type
    output reg        mem_read,
    output reg        mem_write,
    output reg        mem_to_reg,
    output reg        branch,
    output reg        jump
);

    always @(*) begin
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        alu_op     = 2'b00;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;

        case (opcode)
            7'b0110011: begin // R-type
                reg_write = 1'b1;
                alu_src   = 1'b0;
                alu_op    = 2'b10;
            end
            7'b0010011: begin // I-type ALU
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b10;
            end
            7'b0000011: begin // Load
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
                alu_op     = 2'b00;
            end
            7'b0100011: begin // Store
                alu_src   = 1'b1;
                mem_write = 1'b1;
                alu_op    = 2'b00;
            end
            7'b1100011: begin // Branch
                branch = 1'b1;
                alu_op = 2'b01;
            end
            7'b1101111: begin // JAL
                reg_write = 1'b1;
                jump      = 1'b1;
            end
            default: begin end
        endcase
    end

endmodule
