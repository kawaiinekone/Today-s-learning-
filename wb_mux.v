`timescale 1ns / 1ps

module wb_mux (
    input  wire        mem_to_reg,   // 0 = ALU result, 1 = Memory read data
    input  wire [31:0] alu_result,
    input  wire [31:0] mem_rdata,
    output wire [31:0] wb_data
);

    assign wb_data = (mem_to_reg) ? mem_rdata : alu_result;

endmodule