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

---

## Stage 2: Instruction Decode & Execution (ID/EX)

The Decode and Execution stage decodes the 32-bit instruction, extracts sign-extended immediates, fetches register operands, and evaluates arithmetic, logical, and custom operations in a single cycle.

### RTL Modules

| Module | File | Description |
| :--- | :--- | :--- |
| `reg_file` | `rtl/reg_file.v` | 32x32-bit dual-read asynchronous, single-write synchronous register file with hardwired `x0 = 0` |
| `imm_gen` | `rtl/imm_gen.v` | Asynchronous immediate generator supporting I, S, B, U, and J formats |
| `control_unit` | `rtl/control_unit.v` | Primary instruction decoder generating datapath multiplexer and write-enable controls |
| `alu_ctrl_unit` | `rtl/alu_ctrl_unit.v` | Secondary decoder translating `funct3`, `funct7`, and custom opcodes into ALU operation codes |
| `alu` | `rtl/alu.v` | 32-bit arithmetic and logic unit integrated with the single-cycle parallel adder-tree `cpop` accelerator |
| `branch_comp` | `rtl/branch_comp.v` | Zero-latency branch comparator evaluating `beq`, `bne`, and signed/unsigned comparison flags |
| `id_wb_reg` | `rtl/id_wb_reg.v` | ID/WB Pipeline Register latching ALU results, memory controls, store data, and writeback addresses |

### Key Features Verified in Stage 2
- **Hardware `popcount` Acceleration**: Single-cycle resolution of 32-bit set-bit density via a 6-stage balanced parallel adder tree.
- **"Green-Heart" Eco-Gate Operand Isolation**: Dynamic clamping of ALU input buses to `32'h00000000` during non-compute cycles (bubbles, stores, branches) to suppress parasitic switching power.
- **x0 Ground Invariance**: Hardware enforcement ensuring register `x0` remains hardwired to zero under arbitrary write attempts.

### Simulation & Waveform Verification

Compile and simulate Stage 2 standalone:

```bash
iverilog -o sim_stage2 tb/tb_stage2.v rtl/reg_file.v rtl/imm_gen.v rtl/control_unit.v rtl/alu_ctrl_unit.v rtl/alu.v rtl/branch_comp.v
vvp sim_stage2
gtkwave stage2.vcd
```
#### Verification Waveform
<img width="1895" height="1018" alt="Screenshot 2026-10-03 162359" src="https://github.com/user-attachments/assets/7daf6a68-dfbf-43ea-9ad4-d826259150fc" />
<img width="897" height="645" alt="image" src="https://github.com/user-attachments/assets/87f57e9f-052b-4d82-bd73-1caf60e6e990" />

## Stage 3: Memory Access & Writeback (MEM/WB) & Full Core Integration

Stage 3 coordinates scratchpad memory accesses and commits computed or loaded results back to the register file, backed by dynamic hazard forwarding and branch flushing logic.


