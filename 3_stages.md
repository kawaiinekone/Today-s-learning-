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



**The Program: Sum of Natural Numbers ($1 + 2 + 3 + 4 + 5 = 15$)**
**The Assembly Routine:**
```
; Initialize
addi x1, x0, 5       ; Counter N = 5
addi x2, x0, 0       ; Accumulator Sum = 0

loop:
add  x2, x2, x1      ; Sum = Sum + N
addi x1, x1, -1      ; N = N - 1
bne  x1, x0, loop    ; If N != 0, jump back to loop

; Finish
addi x3, x0, 1       ; Done flag = 1
```
## Verification
<img width="1062" height="782" alt="image" src="https://github.com/user-attachments/assets/44e28391-b612-4126-9c5d-1bd919dd77b0" />

**The Program: Control Flow (Branch & Pipeline Flush)**
## To test conditional branching (beq) to verify pipeline flush behavior when a branch condition is met.
**The Program:**
```
addi x1, x0, 10 $\to$ x1 = 10
addi x2, x0, 10 $\to$ x2 = 10
beq  x1, x2, skip $\to$ Since $10 == 10$, the branch is taken and jumps ahead by $+8$ bytes.
addi x3, x0, 99 $\to$ Trap instruction: If the pipeline flush fails, x3 will be written with 99. If flushing works, this instruction gets discarded.
skip:
addi x4, x0, 77 $\to$ Success flag: x4 = 77.
```
<img width="1002" height="397" alt="image" src="https://github.com/user-attachments/assets/774477bf-2e5a-4f02-9d38-3fa3c06c1f99" />


## To verify: Immediate & Register Arithmetic (addi, add, sub)

Logic Operations (and, or, xor)

1-Cycle Popcount Accelerator (cpop)

Hardwired x0 Zero-Check (ensuring writing to x0 never changes its value):
```
addi x1, x0, 12 $\to$ x1 = 12 (0x0000000C, binary ...1100)
addi x2, x0, 5  $\to$ x2 = 5  (0x00000005, binary ...0101)
and  x3, x1, x2 $\to$ x3 = 12 & 5 = 4 (0x00000004)
or   x4, x1, x2 $\to$ x4 = 12 | 5 = 13 (0x0000000D)
xor  x5, x1, x2 $\to$ x5 = 12 ^ 5 = 9 (0x00000009)
sub  x6, x1, x2 $\to$ x6 = 12 - 5 = 7 (0x00000007)
cpop x7, x3     $\to$ x7 = popcount(4) = 1 (4 is 0b0100, exactly one set bit)
addi x0, x0, 50 $\to$ Attempt to corrupt x0 with 50 (must remain 0)
```
**VERIFICATION**
<img width="582" height="452" alt="Screenshot 2026-10-03 223045" src="https://github.com/user-attachments/assets/5f682250-80d6-4c84-88e3-997939e40be9" />


## Running Load/Store Test

<img width="992" height="512" alt="image" src="https://github.com/user-attachments/assets/3cbdf620-760a-481e-a6c7-59c4d86b5e0d" />


