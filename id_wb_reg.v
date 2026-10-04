`timescale 1ns / 1ps

module id_wb_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        reg_write_in,
    input  wire        mem_to_reg_in,
    input  wire [4:0]  rd_addr_in,
    input  wire [31:0] alu_result_in,
    output reg         reg_write_out,
    output reg         mem_to_reg_out,
    output reg  [4:0]  rd_addr_out,
    output reg  [31:0] alu_result_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_write_out  <= 1'b0;
            mem_to_reg_out <= 1'b0;
            rd_addr_out    <= 5'd0;
            alu_result_out <= 32'h00000000;
        end else begin
            reg_write_out  <= reg_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            rd_addr_out    <= rd_addr_in;
            alu_result_out <= alu_result_in;
        end
    end

endmodule