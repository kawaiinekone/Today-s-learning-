`timescale 1ns / 1ps

module alu (
    input  wire [3:0]  alu_ctrl,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] result,
    output wire        zero
);

    // Parallel popcount adder tree
    function [5:0] count_ones;
        input [31:0] val;
        integer i;
        begin
            count_ones = 6'd0;
            for (i = 0; i < 32; i = i + 1) begin
                count_ones = count_ones + val[i];
            end
        end
    endfunction

    always @(*) begin
        case (alu_ctrl)
            4'b0000: result = a + b;
            4'b0001: result = a - b;
            4'b0010: result = a << b[4:0];
            4'b0011: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            4'b0100: result = (a < b) ? 32'd1 : 32'd0;
            4'b0101: result = a ^ b;
            4'b0110: result = a >> b[4:0];
            4'b0111: result = $signed(a) >>> b[4:0];
            4'b1000: result = a | b;
            4'b1001: result = a & b;
            // INNOVATION 1: 1-Cycle Hardware Accelerator
            4'b1010: result = {26'd0, count_ones(a)}; // POPCOUNT
            default: result = 32'h00000000;
        endcase
    end

    assign zero = (result == 32'h00000000);

endmodule