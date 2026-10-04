`timescale 1ns / 1ps

module dmem (
    input  wire        clk,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [31:0] addr,
    input  wire [31:0] wr_data,
    output wire [31:0] rd_data
);

    // 256-word (1 KB) synchronous write, asynchronous read RAM
    reg [31:0] ram [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            ram[i] = 32'h00000000;
        end
    end

    // Word-aligned addressing
    wire [7:0] word_addr = addr[9:2];

    assign rd_data = (mem_read) ? ram[word_addr] : 32'h00000000;

    always @(posedge clk) begin
        if (mem_write) begin
            ram[word_addr] <= wr_data;
        end
    end

endmodule