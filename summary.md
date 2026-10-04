---

## Modular Verilog RTL Implementation (The 12 Bricks)

All 12 architecture bricks are maintained as isolated, synthesizable Verilog modules inside the [`rtl/`](./rtl/) directory:

<details>
<summary><b>Click to expand full RTL Brick Architecture Directory</b></summary>

### Stage 1: Instruction Fetch (IF)
- **Brick 01: [`rtl/pc_reg.v`](./rtl/pc_reg.v)**
  - *Ports*: `clk`, `rst_n`, `stall`, `next_pc[31:0]`, `pc[31:0]`
  - *Role*: Synchronous 32-bit Program Counter register.
- **Brick 02: [`rtl/imem.v`](./rtl/imem.v)**
  - *Ports*: `addr[31:0]`, `instr[31:0]`
  - *Role*: Word-aligned instruction memory loaded via `$readmemh`.
- **Brick 03: [`rtl/if_id_reg.v`](./rtl/if_id_reg.v)**
  - *Ports*: `clk`, `rst_n`, `stall`, `flush`, `if_pc[31:0]`, `if_instr[31:0]`, `id_pc[31:0]`, `id_instr[31:0]`
  - *Role*: Pipeline interstage register with bubble insertion.

### Stage 2: Instruction Decode & Execution (ID/EX)
- **Brick 04: [`rtl/reg_file.v`](./rtl/reg_file.v)**
  - *Ports*: `clk`, `rst_n`, `wr_en`, `rd1_addr[4:0]`, `rd2_addr[4:0]`, `wr_addr[4:0]`, `wr_data[31:0]`, `rd1_data[31:0]`, `rd2_data[31:0]`
  - *Role*: 32x32-bit dual-read asynchronous, single-write synchronous register array ($x_0 = 0$).
- **Brick 05: [`rtl/imm_gen.v`](./rtl/imm_gen.v)**
  - *Ports*: `instr[31:0]`, `imm[31:0]`
  - *Role*: Asynchronous immediate extraction for I, S, B, U, J types.
- **Brick 06: [`rtl/control_unit.v`](./rtl/control_unit.v)**
  - *Ports*: `opcode[6:0]`, `reg_write`, `mem_to_reg`, `mem_read`, `mem_write`, `alu_src`, `alu_op[1:0]`, `branch`
  - *Role*: Primary instruction opcode decoder.
- **Brick 07: [`rtl/alu_ctrl_unit.v`](./rtl/alu_ctrl_unit.v)**
  - *Ports*: `alu_op[1:0]`, `funct3[2:0]`, `funct7[6:0]`, `alu_ctrl[3:0]`
  - *Role*: Secondary ALU operation and custom opcode mapping.
- **Brick 08: [`rtl/alu.v`](./rtl/alu.v)**
  - *Ports*: `a[31:0]`, `b[31:0]`, `alu_ctrl[3:0]`, `result[31:0]`, `zero`
  - *Role*: 32-bit ALU with integrated 6-stage parallel adder-tree `cpop`.
- **Brick 09: [`rtl/branch_comp.v`](./rtl/branch_comp.v)**
  - *Ports*: `rs1_data[31:0]`, `rs2_data[31:0]`, `funct3[2:0]`, `branch_taken`
  - *Role*: Combinational branch evaluation logic.
- **Brick 10: [`rtl/id_wb_reg.v`](./rtl/id_wb_reg.v)**
  - *Ports*: `clk`, `rst_n`, `id_reg_write`, `id_mem_to_reg`, `id_mem_read`, `id_mem_write`, `id_rd_addr[4:0]`, `alu_result[31:0]`, `rs2_data[31:0]`, and WB pipeline outputs
  - *Role*: Interstage latch connecting execution to writeback.

### Stage 3: Memory Access & Writeback (MEM/WB)
- **Brick 11: [`rtl/dmem.v`](./rtl/dmem.v)**
  - *Ports*: `clk`, `mem_write`, `mem_read`, `addr[31:0]`, `wr_data[31:0]`, `rd_data[31:0]`
  - *Role*: Local scratchpad RAM block.
- **Brick 12: [`rtl/wb_mux.v`](./rtl/wb_mux.v)**
  - *Ports*: `alu_result[31:0]`, `mem_data[31:0]`, `mem_to_reg`, `wb_data[31:0]`
  - *Role*: Multiplexer routing ALU output vs loaded memory data.

### Top-Level Integration
- **Datapath Core: [`rtl/riscv_core.v`](./rtl/riscv_core.v)**
  - *Role*: Structural module connecting all 12 bricks, Green-Heart operand isolation, and RAW forwarding.

</details>
