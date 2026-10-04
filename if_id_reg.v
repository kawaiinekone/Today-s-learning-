`timescale 1ns / 1ps

module if_id_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,
    input  wire        flush,
    input  wire [31:0] if_pc,
    input  wire [31:0] if_instr,
    output reg  [31:0] id_pc,
    output reg  [31:0] id_instr
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_pc    <= 32'h00000000;
            id_instr <= 32'h00000013; // NOP (addi x0, x0, 0)
        end else if (flush) begin
            id_pc    <= 32'h00000000;
            id_instr <= 32'h00000013;
        end else if (!stall) begin
            id_pc    <= if_pc;
            id_instr <= if_instr;
        end
    end

endmodule