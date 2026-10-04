`timescale 1ns / 1ps

module alu_ctrl_unit (
    input  wire [1:0] alu_op,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg  [3:0] alu_ctrl
);

    always @(*) begin
        case (alu_op)
            2'b00: alu_ctrl = 4'b0000; // ADD for Load/Store
            2'b01: alu_ctrl = 4'b0001; // SUB for Branch
            2'b10: begin               // ALU instructions
                if (funct7 == 7'b0110000 && funct3 == 3'b100) begin
                    alu_ctrl = 4'b1010; // Custom 1-cycle POPCOUNT
                end else begin
                    case (funct3)
                        3'b000: alu_ctrl = (funct7[5]) ? 4'b0001 : 4'b0000; // SUB : ADD
                        3'b001: alu_ctrl = 4'b0010;                         // SLL
                        3'b010: alu_ctrl = 4'b0011;                         // SLT
                        3'b011: alu_ctrl = 4'b0100;                         // SLTU
                        3'b100: alu_ctrl = 4'b0101;                         // XOR
                        3'b101: alu_ctrl = (funct7[5]) ? 4'b0111 : 4'b0110; // SRA : SRL
                        3'b110: alu_ctrl = 4'b1000;                         // OR
                        3'b111: alu_ctrl = 4'b1001;                         // AND
                        default: alu_ctrl = 4'b0000;
                    endcase
                end
            end
            default: alu_ctrl = 4'b0000;
        endcase
    end

endmodule