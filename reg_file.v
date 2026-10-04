`timescale 1ns / 1ps

module reg_file (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        we,
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] wr_data,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data
);

    reg [31:0] rf [0:31];
    integer i;

    // Register x0 is hardwired to zero
    assign rs1_data = (rs1_addr == 5'd0) ? 32'h00000000 : rf[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'h00000000 : rf[rs2_addr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                rf[i] <= 32'h00000000;
            end
        end else if (we && (rd_addr != 5'd0)) begin
            rf[rd_addr] <= wr_data;
        end
    end

endmodule