`timescale 1ns / 1ps

module imem (
    input  wire [31:0] pc,
    output wire [31:0] instr
);

    reg [31:0] mem [0:63];
    integer i;

    initial begin
        for (i = 0; i < 64; i = i + 1) begin
            mem[i] = 32'h00000013;
        end
        $readmemh("program.hex", mem);
    end

    assign instr = mem[pc[31:2]];

endmodule