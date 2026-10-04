# Eco_riscV-Core: An Application-Specific 3-Stage Low-Power RV32I Embedded Processor

Eco-Core is an open-source, energy-efficient 32-bit RISC-V processor implementing the unprivileged RV32I Base Integer Instruction Set, integrated with a custom hardware-accelerated instruction extension (`cpop`) and architectural operand isolation gating ("Green-Heart" Eco-Gate). 

It is engineered specifically for deeply embedded, energy-harvesting edge systems—such as wearable continuous health monitors, biosignal anomaly trackers, and precision agricultural soil sensor nodes—where processing autonomy and battery longevity over years are critical constraints.

---



---

## Architectural Philosophy & Motivation

Classical 5-stage RISC pipelines (IF $\to$ ID $\to$ EX $\to$ MEM $\to$ WB) maximize clock frequency through aggressive pipelining. However, in deeply embedded edge applications operating at moderate clock rates (10 MHz to 100 MHz), a 5-stage depth introduces significant overhead:
- **Control Hazard Penalties**: Branch mispredictions incur a 2-to-3 cycle flush penalty, penalizing short, branch-heavy sensor evaluation loops.
- **Dynamic Gating Overhead**: Additional inter-stage pipeline registers increase flip-flop count, leakage, and dynamic clock-tree switching power.

Eco-Core adopts a **balanced 3-stage pipeline (IF $\to$ ID/EX $\to$ MEM/WB)**. This design provides:
1. **Single-Cycle Branch Resolution**: Branches are decided directly in Stage 2, bounding the taken-branch penalty to exactly **1 clock cycle bubble**.
2. **Deterministic Single-Cycle ALU Throughput**: Back-to-back dependent arithmetic instructions execute with zero stall bubbles via register forwarding.
3. **Targeted Acceleration**: Hardware offloading of Hamming distance and bit-density calculations via a 1-cycle `popcount` instruction, bypassing multi-cycle software iteration.

4. ++
|                                      TAKSHAKA-CORE DATAPATH TOPOLOGY                                   |


| STAGE 1: FETCH | STAGE 2: DECODE & EXECUTE | STAGE 3: MEM & WRITEBACK |
| :--- | :--- | :--- |
| **PC Reg** (Program Counter) | **Register File** (32x32) | **Data Memory** (`dmem`) |
| **imem** (Instruction Memory ROM) | **Eco-Gate** (Operand Isolation MUX `[B-03]`) | **Writeback MUX** `[B-10]` |
| | **1-Cycle ALU & Parallel Popcnt** | |
| **Buses & Feedback Loops:** | ── **RAW Forwarding Bus** ──> | (Feeds from Stage 3 back to Stage 2) |
| <── **Branch Target Redirect** ── | (Feeds from Stage 2 back to Stage 1) | |

---

## Microarchitecture & Pipeline Specification

### Stage 1: Instruction Fetch (IF)
- **Program Counter (`pc_reg`)**: Operates on a synchronous active-low reset (`rst_n`). Increments by $+4$ sequentially during normal operation or redirects to `branch_target` when a control branch is taken.
- **Instruction Memory (`imem`)**: Configured as a 64-word (256-byte) internal array with word-aligned addressing (`pc[31:2]`). It dynamically initialises via `$readmemh("program.hex", mem)`.
- **Pipeline Interstage Register (`if_id_reg`)**: Latches the fetched 32-bit instruction and current PC. It contains synchronous `flush` control logic: when asserted by Stage 2, it converts the incoming instruction into an architectural bubble (`NOP = 32'h00000013`, equivalent to `addi x0, x0, 0`).

### Stage 2: Instruction Decode & Execution (ID/EX)
- **Register File (`reg_file`)**: 32 general-purpose 32-bit registers ($x_0$ to $x_{31}$) with asynchronous dual-read ports and a synchronous single-write port. Register $x_0$ is hardwired to ground (`32'h00000000`); write attempts to $x_0$ are discarded.
- **Immediate Generator (`imm_gen`)**: Parses instruction bitfields combinatorially to produce sign-extended 32-bit immediates for I-type, S-type, B-type, U-type, and J-type instructions.
- **Control & ALU Control Units (`control_unit`, `alu_ctrl_unit`)**: Decode opcodes, `funct3`, and `funct7` bitfields to generate datapath steering signals: `reg_write`, `mem_to_reg`, `mem_read`, `mem_write`, `alu_src`, and `alu_op`.
- **Branch Comparator (`branch_comp`)**: Evaluates branch equality (`beq`), inequality (`bne`), and signed/unsigned magnitude comparisons directly against forwarded register operands.
- **Execution ALU (`alu`)**: Executes single-cycle integer arithmetic (`ADD`, `SUB`), bitwise logic (`AND`, `OR`, `XOR`), barrel shifts, set-less-than comparisons (`SLT`, `SLTU`), and the custom single-cycle `popcount` parallel tree.
- **Pipeline Interstage Register (`id_wb_reg`)**: Captures ALU computation results, memory control signals, writeback register addresses (`rd`), and forwarded store data (`fwd_rs2_data`).

### Stage 3: Memory Access & Writeback (MEM/WB)
- **Data Memory (`dmem`)**: A synchronous write, asynchronous read RAM block representing the local scratchpad / sensor buffer. Writes commit on the rising clock edge when `mem_write` is active.
- **Writeback Multiplexer (`wb_mux`)**: Selects between the ALU execution output and incoming memory data (`mem_to_reg`), driving the final `wb_wr_data` bus back to the Register File write port and the forward bypass unit.

---

## The 12-Brick Modular RTL Topology

The RTL implementation is partitioned into 12 standalone modules:

| Brick # | Source File | Pipeline Stage | Logic Category | Function & Design Detail |
| :--- | :--- | :--- | :--- | :--- |
| **01** | `rtl/pc_reg.v` | Stage 1 (IF) | Sequential | 32-bit Program Counter with synchronous clear and parallel target load. |
| **02** | `rtl/imem.v` | Stage 1 (IF) | Combinational | Byte-addressed, word-aligned instruction memory loaded via `$readmemh`. |
| **03** | `rtl/if_id_reg.v` | Pipeline Reg | Sequential | Latches instruction and PC; injects `NOP` bubbles on `flush`. |
| **04** | `rtl/reg_file.v` | Stage 2 (ID/EX) | Mixed | Dual-read asynchronous, single-write synchronous array with invariant $x_0 = 0$. |
| **05** | `rtl/imm_gen.v` | Stage 2 (ID/EX) | Combinational | Full RV32 sign-extension logic for I, S, B, U, and J instruction formats. |
| **06** | `rtl/control_unit.v` | Stage 2 (ID/EX) | Combinational | Primary instruction decoder asserting pipeline datapath control vectors. |
| **07** | `rtl/alu_ctrl_unit.v`| Stage 2 (ID/EX) | Combinational | Translates primary ALU opcodes, `funct3`, and `funct7` into 4-bit ALU control codes. |
| **08** | `rtl/alu.v` | Stage 2 (ID/EX) | Combinational | 32-bit integer arithmetic, logic, comparison, and parallel adder-tree popcount. |
| **09** | `rtl/branch_comp.v` | Stage 2 (ID/EX) | Combinational | Zero-latency branch comparator driving PC branch-target multiplexers. |
| **10** | `rtl/id_wb_reg.v` | Pipeline Reg | Sequential | Pipeline boundary latching ALU output, store data, and WB register addresses. |
| **11** | `rtl/dmem.v` | Stage 3 (MEM/WB)| Mixed | Synchronous-write, asynchronous-read local data memory array. |
| **12** | `rtl/wb_mux.v` | Stage 3 (MEM/WB)| Combinational | Selects final register writeback value between ALU result and loaded memory word. |

---
## Custom Hardware Innovations

### 1. Single-Cycle Population Count Accelerator (`cpop`)

#### The Problem
In edge-sensing applications (e.g., electrocardiogram R-peak feature extraction, soil-salinity thresholding, bit-error rate monitoring), computing the Hamming weight (number of active 1s in a bitmask) is frequent. Standard RV32I cores without the Zbb extension must execute iterative software routines:

```c
// Conventional RV32I Software Popcount: 30 - 50 clock cycles
int count = 0;
while (val != 0) {
    count += (val & 1);
    val >>= 1;
}
```
This loop burns clock cycles, increases instruction cache traffic, and drains energy.

The Architectural Solution
Takshaka-Core implements cpop as a dedicated instruction executing in 1 clock cycle:

Instruction Encoding: R-type format (opcode = 7'b0110011, funct3 = 3'b001, funct7 = 7'b0110000).

Hardware Architecture: Implemented inside rtl/alu.v as a 6-stage balanced parallel adder tree:


<img width="813" height="530" alt="Screenshot 2026-10-03 200533" src="https://github.com/user-attachments/assets/88a72e72-7ae4-4bcf-9941-1080a0e87e7b" />

This requires zero pipeline stalls and completes within the standard ID/EX cycle timing budget.

## 🟢 Green Heart: Echo Gate Operand Isolation

### The Problem
Dynamic CMOS power dissipation is governed by the following formula:

$\[P_{\text{dynamic}} = \alpha \cdot C_L \cdot V_{DD}^2 \cdot f_{\text{clk}}\]$

Where:
* **$\(\alpha\)$** is the switching activity factor.
* **$\(C_L\)$** is the load capacitance.
* **$\(V_{DD}\)$** is the supply voltage.
* **$\(f_{\text{clk}}\)$** is the clock frequency.

In standard pipelined designs, register read buses toggle into the execution ALU regardless of whether the current instruction performs arithmetic. During memory stores (`sw`), branches (`beq`), jumps (`jal`), and pipeline bubbles (`NOP`), transitions on register output buses cause parasitic switching inside the ALU's carry chains, logic trees, and adders.

**The Architectural Solution**
Takshaka-Core incorporates an active operand isolation barrier within rtl/riscv_core.v. When id_alu_op indicates a non-ALU operation or pipeline idle state, the inputs to the execution unit are clamped to ground:
```
// Green-Heart Eco-Gate Operand Isolation Logic
wire alu_active = (id_alu_op != 2'b00);

assign gated_alu_a = alu_active ? fwd_rs1_data   : 32'h00000000;
assign gated_alu_b = alu_active ? alu_b_mux_out  : 32'h00000000;
```
By clamping internal ALU nets to zero, switching activity $\alpha$ inside the arithmetic datapath drops to zero during non-compute cycles, reducing unnecessary dynamic power.


**Hazard Handling & Data Path Forwarding**


**RAW Arithmetic Bypass**


When an instruction reads a register updated by the instruction immediately preceding it, a Read-After-Write (RAW) hazard occurs:
```
addi x1, x0, 10      ; Stage 3 (MEM/WB) -> Calculating/Writing x1
add  x2, x1, x5      ; Stage 2 (ID/EX)  -> Needs x1 immediately
```
The internal forwarding unit detects this condition:

```
assign fwd_rs1_data = (r_wb_reg_write && (r_wb_rd_addr != 5'd0) && (r_wb_rd_addr == id_rs1_addr)) 
                      ? wb_wr_data : rf_rd_data1;
```
If matched, wb_wr_data is routed directly to the ALU operand input without inserting stall bubbles.

**Store Data Hazard Forwarding**


A subtle hazard arises when storing a value computed in the cycle immediately prior:

```
addi x2, x0, 255     ; Value generated
sw   x2, 0(x1)       ; Store depends on x2
```
If the pipeline latches the raw register file output rs2_data, it reads stale data because x2 has not yet committed. Takshaka-Core routes the forwarded bus into the pipeline register:

```
r_wb_rs2_data <= fwd_rs2_data; // Latches dynamically forwarded value
```

This guarantees that data memory receives the up-to-date calculation.
