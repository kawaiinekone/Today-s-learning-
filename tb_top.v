`timescale 1ns / 1ps

module tb_top;

    reg clk;
    reg rst_n;
    integer cycle_count;
    integer i;

    riscv_core uut (
        .clk(clk),
        .rst_n(rst_n)
    );

    // 10ns clock period (100 MHz)
    always #5 clk = ~clk;

    // Monitor register writes dynamically
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count = cycle_count + 1;
            
            // Log Register Writebacks (ignore writes to x0)
            if (uut.wb_reg_write && (uut.wb_rd_addr != 5'd0)) begin
                $display("[Cycle %0t ns] REG WRITE -> x%0d = %0d (0x%08h)", 
                         $time, uut.wb_rd_addr, uut.wb_wr_data, uut.wb_wr_data);
            end

            // Log Data Memory Writes
            if (uut.u_dmem.mem_write) begin
                $display("[Cycle %0t ns] MEM STORE -> RAM[%0d] = %0d (0x%08h)", 
                         $time, uut.u_dmem.addr, uut.u_dmem.wr_data, uut.u_dmem.wr_data);
            end
        end
    end

    initial begin
        $dumpfile("core_top.vcd");
        $dumpvars(0, tb_top);

        clk = 0;
        rst_n = 0;
        cycle_count = 0;

        #20 rst_n = 1;

        // Run execution window
        #250;

        $display("\n==================================================");
        $display("          FINAL REGISTER FILE DUMP                ");
        $display("==================================================");
        for (i = 0; i < 32; i = i + 1) begin
            if (uut.u_rf.rf[i] != 32'd0) begin
                $display("  x%02d = %0d (0x%08h)", i, uut.u_rf.rf[i], uut.u_rf.rf[i]);
            end
        end
        $display("==================================================\n");

        $finish;
    end

endmodule