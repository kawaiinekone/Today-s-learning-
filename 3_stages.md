# 3-Stage RISC-V Core (`eco_riscv_core`)

A compact 3-stage pipelined RISC-V (RV32I) processor core implemented in Verilog.

## Directory Structure

- `rtl/`: Synthesizable Verilog RTL source files
- `tb/`: Verilog testbenches and simulation harnesses

## Stage 1: Instruction Fetch (IF) & Pipeline Register

The Fetch stage is responsible for sequential instruction addressing, instruction memory indexing, and pipeline isolation.

### RTL Modules

| Module | File | Description |
| :--- | :--- | :--- |
| `pc_reg` | `rtl/pc_reg.v` | Synchronous 32-bit Program Counter with active-low reset and stall support |
| `imem` | `rtl/imem.v` | Word-aligned asynchronous read Instruction Memory |
| `if_id_reg` | `rtl/if_id_reg.v` | IF/ID Pipeline Register supporting synchronous stall and flush (NOP injection) |

### Simulation & Waveform Verification

Compile and simulate Stage 1 with Icarus Verilog:

\`\`\`bash
iverilog -o sim_stage1 tb/tb_stage1.v rtl/pc_reg.v rtl/imem.v rtl/if_id_reg.v
vvp sim_stage1
gtkwave stage1.vcd
\`\`\`

#### Verification Waveform
<img width="1073" height="710" alt="Screenshot 2026-10-03 133001" src="https://github.com/user-attachments/assets/c18fe27e-d690-4407-b14f-0ed6b4b6b16c" />
