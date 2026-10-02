# Day 1: Ground-Up Foundations & Execution Anatomy

## 1. What I Thought vs. What Is Actually True

| Concept | My Previous (Flawed) Assumption | Ground Truth & Hardware Reality |
| :--- | :--- | :--- |
| **Digital `1` and `0`** | Abstract mathematical numbers floating inside chips. | Continuous **electrical voltage levels**. A `1` is a high potential ($V_{DD}$, e.g., 3.3V or 1.2V), and a `0` is ground ($GND$, 0V). Intermediate voltages cause **signal contention** or **metastable states**. |
| **Registers** | Fast temporary RAM or software variables. | **Edge-triggered D Flip-Flops** built from cross-coupled CMOS logic gates. They capture electrical values strictly on a **clock edge** and hold them static. |
| **Decode Phase** | Software parsing strings or checking `if/else` statements. | Purely passive **combinational wire splitting** and decoding logic. Bits from the instruction word are routed simultaneously to the register file address ports and control decoder. |
| **Where ALU Output Goes** | "ALU output goes directly to RAM or registers." | The ALU output goes onto a physical **shared bus/wire** connected to both the Data Memory address lines **and** a Writeback Multiplexer. The control unit determines where it lands at the clock edge. |
| **Writeback** | A software confirmation or logging step. | The physical routing of execution results (from either the ALU or Data Memory) back to the Register File write port (`rd`), gated by the `RegWrite` enable wire on the **rising clock edge**. |

---

## 2. Core Hardware Glossary & First Principles

### Silicon & The Transistor Level
* **Silicon Lattice:** Pure silicon atoms covalently bonded in a crystalline matrix with 4 valence electrons. At absolute zero, it acts as an **insulator** because no free charge carriers exist.
* **Doping (N-type vs. P-type):** Introducing impurities to alter electrical conductivity:
  * **N-type (Negative):** Doped with Group 15 elements (e.g., Phosphorus) to supply free mobile **conduction electrons**.
  * **P-type (Positive):** Doped with Group 13 elements (e.g., Boron) to create electron deficiencies, termed **holes**.
* **MOSFET (Metal-Oxide-Semiconductor Field-Effect Transistor):** A **voltage-controlled solid-state switch** with three operational terminals: Gate ($G$), Drain ($D$), and Source ($S$).
  * **NMOS:** Conducts when the Gate voltage is High ($V_{GS} > V_{th}$). Pulls the output down to **Ground (`0`)**.
  * **PMOS:** Conducts when the Gate voltage is Low ($V_{GS} < -\vert{}V_{th}\vert{}$). Pulls the output up to **$V_{DD}$ (`1`)**.
* **CMOS (Complementary MOS):** A design paradigm pairing complementary NMOS and PMOS networks. A valid CMOS gate draws **negligible static current** because one network is always open (off) when the other is closed (on).

### Microarchitecture & Logic Elements
* **Propagation Delay ($t_{pd}$):** The finite time required for an electrical signal to transition from input to output across physical semiconductor gates.
* **Clock Period ($T_{clk}$):** The minimum time allocated for a single execution cycle. In a single-cycle processor, $T_{clk}$ is bounded strictly by the **critical path**:
  $$T_{clk} \ge t_{PC\_clk\_to\_q} + t_{IMem} + t_{Decode} + t_{ALU} + t_{DMem} + t_{Mux} + t_{setup}$$
* **Multiplexer (MUX):** A hardware **steering switch**. It selects one of several data inputs and routes it to a single output based on binary control select lines.
* **Arithmetic Logic Unit (ALU):** A purely **combinational block** capable of performing arithmetic (addition, subtraction) and bitwise operations (AND, OR, XOR, shifts) based on an ALU operation code (`ALUOp`).
* **Register File:** A centralized bank of 32 general-purpose 32-bit registers (`x0` to `x31`). It features **two asynchronous read ports** (allowing simultaneous reading of `rs1` and `rs2`) and **one synchronous write port** (`rd`).
* **Hardwired Zero (`x0`):** In RISC-V, register 0 is physically tied to **Ground ($GND$)**. Any write attempt to `x0` is dropped, ensuring reads from `x0` always evaluate to `0x00000000`.

---

## 3. The RISC-V RV32I Execution Cycle (Wire-by-Wire)

A single-cycle core completes one instruction per clock period across 5 functional phases:


| PC | --> | I-MEM | --> | DECODE | --> | ALU | --> | D-MEM | --> | WB |



### Phase 1: Instruction Fetch (IF)
1. The **Program Counter (PC)** holds the current 32-bit memory address of the instruction.
2. The address travels over the address bus into **Instruction Memory (I-Mem)**.
3. After memory access latency, the 32-bit raw machine instruction appears on the output lines: `instruction[31:0]`.
4. Simultaneously, a dedicated adder computes the next sequential PC: **$\text{PC} + 4$**.

### Phase 2: Instruction Decode & Register Fetch (ID)
1. Bits are routed directly by **physical copper wires** without runtime software overhead:
   * `instruction[6:0]`: **Opcode** (identifies instruction class).
   * `instruction[19:15]`: **`rs1`** (Read Register 1 index, 5 bits).
   * `instruction[24:20]`: **`rs2`** (Read Register 2 index, 5 bits).
   * `instruction[11:7]`: **`rd`** (Destination Register index, 5 bits).
   * `instruction[14:12]`: **`funct3`** (Operation modifier, 3 bits).
   * `instruction[31:25]`: **`funct7`** (Operation modifier, 7 bits).
2. The **Register File** decodes the 5-bit indices and places the 32-bit values of `rs1` and `rs2` onto internal read data buses (`ReadData1`, `ReadData2`).
3. The **Immediate Generator** extracts designated bit slices and sign-extends them into a uniform 32-bit immediate value (`ImmExt`).
4. The **Control Unit** evaluates the opcode, `funct3`, and `funct7` to assert control lines:
   * **`ALUSrc`:** Selects whether ALU operand B comes from `ReadData2` or `ImmExt`.
   * **`MemtoReg`:** Selects whether writeback data comes from the ALU or Data Memory.
   * **`RegWrite`:** Enables writing to the destination register.
   * **`MemRead` / `MemWrite`:** Controls data memory access.
   * **`Branch` / `Jump`:** Flags PC override conditions.

### Phase 3: Execute / Address Calculation (EX)
1. The **ALU** receives Operand A (from `ReadData1`) and Operand B (selected by the `ALUSrc` MUX: either `ReadData2` or `ImmExt`).
2. The ALU executes the operation commanded by the control decoder:
   * **R-type (e.g., `add`):** Computes `rs1 + rs2`.
   * **I-type load (e.g., `lw`):** Computes the base-plus-offset memory address: `rs1 + ImmExt`.
   * **S-type store (e.g., `sw`):** Computes target memory address: `rs1 + ImmExt`.
   * **B-type branch (e.g., `beq`):** Subtracts `rs1 - rs2` and asserts the **`Zero` flag** if the difference is zero.
3. A branch adder concurrently calculates the target PC: **$\text{Target} = \text{PC} + \text{ImmExt}$**.

### Phase 4: Memory Access (MEM)
1. If the instruction is a **Store** (`sw`), **`MemWrite`** is asserted. The 32-bit value on `ReadData2` is written into Data Memory at the address generated by the ALU.
2. If the instruction is a **Load** (`lw`), **`MemRead`** is asserted. The 32-bit word at the ALU-generated address is read from Data Memory onto the `ReadData` bus.
3. For non-memory instructions (e.g., `add`, `sub`, `addi`), memory control lines remain unasserted (`MemRead=0`, `MemWrite=0`), and Data Memory is inactive.

### Phase 5: Writeback (WB)
1. The **Writeback Multiplexer** chooses the final result source using **`MemtoReg`**:
   * **Path 0 (ALU Result):** For computational instructions (`add`, `addi`, `and`, etc.).
   * **Path 1 (Memory Read Data):** For load instructions (`lw`).
2. The selected 32-bit value arrives at the **`WriteData`** port of the Register File.
3. If **`RegWrite`** is high and **`rd != 0`**, the value is latched into destination register `rd` at the exact **rising edge** of the system clock.
---
# Hardware Execution, Bit Slicing, and Control Signals


---

## 1. What Does "Bits are routed directly by physical copper wires" Actually Mean?

In high-level programming (C, Python, Java), reading data feels like calling a function or accessing an array index (`data[0]`). In CPU hardware, there is no operating system and no parser running. 

When Instruction Memory outputs a 32-bit instruction, it is literally **32 parallel metal traces** (copper wires on silicon) carrying electrical voltages:
* High voltage (~1.2V) = binary `1`
* Low voltage (~0V) = binary `0`

We number these wires from right to left: `0` to `31`.

#
"Routing" means we physically split this bundle of 32 copper wires and solder them to different sub-circuits:
* Wires 0 through 6 (`instruction[6:0]`) run straight into the **Control Unit**.
* Wires 7 through 11 (`instruction[11:7]`) run straight into the **Write Register address input** of the Register File.
* Wires 15 through 19 (`instruction[19:15]`) run straight into **Read Address Port 1** of the Register File.
* Wires 20 through 24 (`instruction[24:20]`) run straight into **Read Address Port 2** of the Register File.

**Key takeaway:** Decode takes virtually zero execution time because no code is running. The moment voltages stabilize on those 32 wires, the voltages immediately travel down the branches of copper into each component.

---

## 2. Breaking Down the Instruction Bit Fields

### `opcode` (`instruction[6:0]` — 7 wires)
* **Analogy:** The family surname.
* **Technical Meaning:** Tells the CPU the broad category of the operation.
* **How it works:** All integer arithmetic (`add`, `sub`, `and`) shares opcode `0110011`. All immediate math (`addi`, `andi`) shares opcode `0010011`. Load instructions (`lw`) share opcode `0000011`. The control unit looks at these 7 wires first to figure out what kind of instruction is executing.

### `rs1` (`instruction[19:15]` — 5 wires)
* **Name:** Register Source 1.
* **Analogy:** The locker number for your first input operand.
* **Why 5 bits?** RISC-V has 32 registers ($x0$ through $x31$). In binary, 5 bits can represent exactly 32 distinct numbers ($2^5 = 32$, from `00000` to `11111`).
* **How it works:** If `rs1` has the bit pattern `00010` (decimal 2), it tells the Register File: "Read the 32-bit value currently stored in register $x2$ and place it onto the output wires."

### `rs2` (`instruction[24:20]` — 5 wires)
* **Name:** Register Source 2.
* **Analogy:** The locker number for your second input operand.
* **How it works:** Works identically to `rs1`. It addresses the second read port of the Register File so the CPU can fetch two operands simultaneously in a single cycle.

### `rd` (`instruction[11:7]` — 5 wires)
* **Name:** Register Destination.
* **Analogy:** The locker number where the final result must be delivered.
* **How it works:** If an instruction computes $x1 + x2 \to x3$, `rd` holds `00011` (decimal 3). At the end of the clock cycle, the result is saved into register $x3$.

### `funct3` (`instruction[14:12]` — 3 wires) & `funct7` (`instruction[31:25]` — 7 wires)
* **Analogy:** The first name and middle name that distinguish siblings.
* **Technical Meaning:** Fine-grained operation modifiers.
* **How it works:** `add` and `sub` perform basic math, so they share the exact same `opcode` (`0110011`) and the same `funct3` (`000`). How does the CPU know whether to add or subtract? It checks wire 30 inside `funct7`:
  * If `funct7[5]` is `0`, perform **Addition**.
  * If `funct7[5]` is `1`, perform **Subtraction**.

---

## 3. How the Register File Reads Data

The Register File contains thirty-two 32-bit registers. It has two read address inputs (each 5 bits wide) and two 32-bit data output buses (`ReadData1` and `ReadData2`).

Inside the Register File sits an internal electronic selector (a decoder + multiplexer tree):
1. `instruction[19:15]` brings the 5-bit address of `rs1`.
2. The internal circuit immediately connects the 32 flip-flops of that specific register to the 32 output wires of `ReadData1`.
3. Simultaneously, `instruction[24:20]` connects the 32 flip-flops of `rs2` to `ReadData2`.
4. This read is **asynchronous** (purely combinational). You do not need to wait for a clock tick to read; the data appears on the output wires as soon as the address wires stabilize.

---

## 4. What is the Immediate Generator (`ImmExt`)?

* **Immediate:** A constant, hardcoded number inside the instruction itself (e.g., the `4` in `addi x1, x1, 4`).
* **The Problem:** In an instruction like `addi`, the immediate number is only 12 bits wide (`instruction[31:20]`), but our ALU is a 32-bit calculation engine. You cannot feed a 12-bit number into a 32-bit adder directly without filling in the missing 20 bits.
* **The Solution (Sign-Extension):**
  * The Immediate Generator takes those 12 bits and expands them to 32 bits.
  * To preserve whether the number is positive or negative (two's complement), it duplicates the highest bit (the sign bit, wire 31) across all the upper 20 positions.
  * If the number was positive (sign bit `0`), the top 20 bits become `000...000`.
  * If the number was negative (sign bit `1`), the top 20 bits become `111...111`.
* The resulting 32-bit output is named `ImmExt`.

---

## 5. Control Signals Explained: The CPU's Traffic Police

The Control Unit evaluates the 7 bits of the opcode and outputs 1-bit or 2-bit electrical control signals that open or close paths throughout the datapath.


### `ALUSrc` (ALU Source Select)
* **Where it sits:** Controls a Multiplexer located right at the second input (Operand B) of the ALU.
* **The Choice:**
  * **Input 0:** `ReadData2` (the value from register `rs2`).
  * **Input 1:** `ImmExt` (the sign-extended constant number).
* **Why it matters:**
  * For `add x3, x1, x2`, we want to add two registers, so `ALUSrc = 0`.
  * For `addi x3, x1, 10`, we want to add a register to the immediate number 10, so `ALUSrc = 1`.

---

### `MemtoReg` & The Writeback Multiplexer (Path 0 vs. Path 1)

At the very end of the datapath sits the **Writeback Multiplexer**. The Register File only has a single 32-bit write port (`WriteData`). However, two completely different components might have the answer we want to save into register `rd`:
1. The **ALU** (if we just performed a calculation like `add` or `addi`).
2. The **Data Memory** (if we just loaded a value from RAM using `lw`).



* **Path 0 (`MemtoReg = 0`):** The multiplexer selects the ALU's calculation result and forwards it to `WriteData`. Used by arithmetic and logical instructions (`add`, `sub`, `addi`, `or`).
* **Path 1 (`MemtoReg = 1`):** The multiplexer selects the data retrieved from RAM and forwards it to `WriteData`. Used by load instructions (`lw`).

---

### `RegWrite` (Register Write Enable)
* **Analogy:** The safety switch on a nail gun.
* **Technical Meaning:** Even if data is waiting at the Register File's `WriteData` port, the register file will **not** save anything unless `RegWrite` is set to `1`.
* **Why it matters:**
  * For `add x3, x1, x2`, we want to store the result, so `RegWrite = 1`.
  * For store instructions (`sw x2, 0(x1)`) or branch comparisons (`beq x1, x2, label`), we are saving data into RAM or changing the PC; we do **not** want to overwrite any registers. Therefore, `RegWrite = 0`.

---

### `MemRead` and `MemWrite` (RAM Access Controls)
* **`MemWrite = 1`:** Tells Data Memory: "Take the 32-bit value on `ReadData2` and write it into the memory address pointed to by the ALU." (Used solely by `sw`).
* **`MemRead = 1`:** Tells Data Memory: "Read the 32-bit value at the address pointed to by the ALU and place it on the memory output bus." (Used solely by `lw`).
* For normal math like `add`, both `MemRead = 0` and `MemWrite = 0`, keeping Data Memory completely inactive and preserving power.

---

### `Branch` / `Jump`
* Controls whether the Program Counter updates sequentially ($\text{PC} + 4$) or jumps to a new location ($\text{PC} + \text{ImmExt}$).
* For `beq` (Branch if Equal): If the Control Unit's `Branch` signal is asserted AND the ALU outputs `Zero = 1` (meaning $rs1 - rs2 = 0$), the PC multiplexer selects the branch target address instead of $\text{PC} + 4$.

---

## 6. Complete Trace: Walking `addi x3, x1, 5` Through the Wires

Let us trace how the CPU executes `addi x3, x1, 5` (which means: read register $x1$, add 5 to it, and store the result in register $x3$).

1. **Fetch:** The PC outputs `0x00000000`. Instruction memory delivers the 32 bits corresponding to `addi x3, x1, 5`.
2. **Wire Splitting:**
   * `instruction[6:0]` (Opcode) goes to the Control Unit $\to$ Control Unit sets `ALUSrc = 1`, `MemtoReg = 0`, `RegWrite = 1`, `MemRead = 0`, `MemWrite = 0`.
   * `instruction[19:15]` (`rs1` = 1) routes to Read Port 1 $\to$ Register File places the contents of register $x1$ onto `ReadData1`.
   * `instruction[11:7]` (`rd` = 3) routes to the Register File write destination address.
   * `instruction[31:20]` (Immediate = 5) routes to the Immediate Generator $\to$ sign-extended to 32-bit value `0x00000005` on `ImmExt`.
3. **Execute:**
   * ALU Operand A receives value from $x1$ via `ReadData1`.
   * ALU Operand B receives `0x00000005` because `ALUSrc = 1` steered the immediate value through the multiplexer.
   * ALU computes: $\text{Result} = \text{Value of } x1 + 5$.
4. **Memory:**
   * Both `MemRead` and `MemWrite` are 0. Data Memory sits idle.
5. **Writeback:**
   * The ALU result arrives at Input 0 of the Writeback MUX.
   * Because `MemtoReg = 0`, the MUX selects Input 0 and places the result on `WriteData`.
   * At the rising edge of the clock, because `RegWrite = 1`, the value is latched into register $x3$. The operation is complete.
---

## 4. Key Architectural Questions Answered

### Q1: Where does data go after execution—RAM or Register? Why?
**Answer:** It depends strictly on the instruction opcode.
* In a **Load/Store Architecture** (the core design principle of RISC-V), arithmetic and logic instructions **never touch RAM directly**. Their outputs route back to the **Register File** via the Writeback MUX.
* Only explicit **Store instructions (`sw`, `sb`, `sh`)** write data to RAM.
* This separation minimizes memory latency bottlenecks, eliminates complex addressing modes, and keeps datapath control deterministic.

### Q2: Why does Writeback exist, and what does its multiplexer select?
**Answer:** Without Writeback, computation results would vanish when the clock cycle finishes. Writeback is the physical bus connection that preserves output in persistent architectural state (`rd`).

Its multiplexer resolves a **structural conflict**: the register file has only one write port, but results can originate from multiple places:
* The **ALU** (arithmetic/logical operations),
* **Data Memory** (load instructions), or
* The **PC Adder** ($\text{PC} + 4$, used by `jal`/`jalr` return addresses).

### Q3: Why is single-cycle processor clock frequency inherently limited?
**Answer:** Because every single phase (Fetch $\to$ Decode $\to$ Execute $\to$ Memory $\to$ Writeback) must complete within a **single clock period**.

The clock period cannot be faster than the **slowest possible instruction** through the datapath (the critical path, typically `lw`, which traverses Instruction Memory, the Register File, the ALU, Data Memory, and the Writeback MUX sequentially). Even if an `add` instruction finishes earlier, the clock cannot tick until the entire worst-case window has elapsed.

---

---

## 1. Can Pipelining, Superscalar, and Out-of-Order Coexist?

### Can a pipelined core be superscalar?
**Yes.** In fact, almost every modern high-performance core (from Apple M-series and Intel Core to high-end RISC-V cores like SiFive P550/P670) is both.
* **Pipelining** overlaps instructions across *time* (depth). If a 5-stage pipeline processes one instruction per stage, instructions move along a conveyor belt one behind another.
* **Superscalar** duplicates hardware to overlap instructions across *space* (width). Instead of fetching, decoding, and executing 1 instruction per cycle, an $N$-way superscalar core fetches, decodes, and executes $N$ instructions per clock cycle ($CPI < 1$, or $IPC > 1$).
* **Together:** A 4-way superscalar pipelined core has 4 parallel pipelines running concurrently. At peak throughput, a 5-stage 4-way core can have up to $5 \times 4 = 20$ instructions in flight at various stages of completion.

### Can an out-of-order (OoO) core be pipelined?
**Yes—OoO requires pipelining.** Out-of-order execution is an advanced control technique layered *on top* of a pipelined engine.
* In a basic **in-order** pipeline, if instruction $B$ depends on instruction $A$ (which is stalled waiting for memory), instruction $C$ behind $B$ must also freeze, even if $C$ is completely independent.
* An **out-of-order** core still fetches and decodes in program order, but sends instructions to an **Issue Queue / Reservation Station**. Independent instructions bypass stalled ones and execute as soon as their input operands are ready. Once executed, results are held temporarily and retired **in order** using a **Reorder Buffer (ROB)** to maintain architectural correctness.

---

## 2. Limitations & Drawbacks of Superscalar and OoO

Moving from single-cycle to in-order pipelining yields major speedups with manageable complexity. Going beyond that to Superscalar and Out-of-Order incurs steep exponential penalties:

| Metric / Concern | In-Order Single-Cycle | In-Order Pipelined | Superscalar (In-Order) | Superscalar + Out-of-Order |
| :--- | :--- | :--- | :--- | :--- |
| **Logic Complexity** | Minimal (simple combinational paths) | Moderate (registers between stages, forwarding muxes) | High ($N^2$ dependency checking across multiple decode lanes) | Extreme (ROB, register renaming, issue queues, CAM lookups) |
| **Area ($mm^2$)** | Tiny | Small | Medium | Massive |
| **Power & Thermal** | Low | Low to Moderate | Moderate | High (quadratic scaling due to continuous dependency searches) |
| **Clock Frequency** | Poor (bounded by critical path) | High (shorter combinational paths) | High to Moderate (multi-issue routing adds wire delay) | Moderate (complex bypass networks limit maximum cycle time) |
| **Diminishing Returns** | Baseline | High return per gate | Return depends heavily on compiler ILP | Heavy silicon cost for fractional IPC gains |

### The Real Limitations:
1. **$N^2$ Bypass Network Explosion:** In an $N$-way superscalar pipeline, every execution unit's output might need to forward to every execution unit's input. The required bypass routing and comparator circuits scale roughly as $O(N^2)$, degrading physical wire routing and cycle time.
2. **Instruction-Level Parallelism (ILP) Walls:** If software code has long serial dependency chains (e.g., each instruction relies directly on the previous one's output), a 4-wide or 8-wide machine will still execute instructions one by one. The extra execution units sit idle.
3. **Register File Port Pressure:** A 4-way superscalar machine may need to read up to 8 operands and write up to 4 results in a single cycle. Building an 8-read, 4-write port register file requires huge silicon area and introduces significant capacitive loading delay.
4. **Branch Misprediction Penalty:** A deep (e.g., 14-stage), wide (e.g., 6-way) OoO processor might have over 100 instructions in flight. A single mispredicted branch requires squashing all speculative work in the ROB, discarding dozens of cycles of spent energy.

---
### *"Can forwarding/bypassing eliminate every Data Hazard (Read-After-Write) in a classical 5-stage pipeline?"*

**The Answer:** **No.** Forwarding eliminates RAW hazards between consecutive ALU operations (e.g., `add` followed immediately by `sub`), but it **cannot** eliminate the **Load-Use Hazard**.

* **Why it physically fails:** The load instruction does not receive the data from RAM until the **end of its MEM stage (Cycle 4)**. However, the subsequent instruction needs that data at the **start of its EX stage (Cycle 3)**. Forwarding back in physical time is impossible.
* **The hardware fix:** A **Hazard Detection Unit** must detect `MemRead == 1` in the execute stage targeting the source register of the decode stage. It inserts a **1-cycle stall (bubble)** into the pipeline, delaying the `sub`'s EX stage to Cycle 4 so data can be forwarded directly from the MEM/WB boundary.

---

### Scenario B: WAR and WAW in Pipelined vs. Out-of-Order
> **Interviewer asks:** *"Can a Write-After-Read (WAR) or Write-After-Write (WAW) hazard ever occur in a standard in-order 5-stage pipeline? What about Out-of-Order?"*

**The Answer:**
* **In an in-order 5-stage pipeline:** **WAR and WAW hazards are physically impossible.**
  * In-order reads always occur in stage 2 (ID) and writes always occur in stage 5 (WB). Because instructions flow strictly in order, an earlier instruction will *always* read before a later instruction reaches writeback (no WAR), and instructions will *always* commit writes to the register file in program order (no WAW).
* **In an Out-of-Order pipeline:** **WAR and WAW are major hazards.**
  * If instruction $B$ finishes before instruction $A$, it could overwrite a register before $A$ reads it (WAR), or overwrite a destination register ahead of $A$, leaving stale data in the architectural register file (WAW).
  * **The hardware fix:** **Register Renaming.** Hardware maps architectural register names (`x1`, `x2`) to a much larger pool of physical registers (`p1`, `p2`, `p64`), converting false storage dependencies into unique physical locations.

---

### Scenario C: The "Self-Forwarding" Register File Edge Case
> **Interviewer asks:** *"What happens in a single-cycle or pipelined processor if Stage 2 (Decode) reads register `x5` in the exact same clock cycle that Stage 5 (Writeback) writes to `x5`? Do we get stale data or new data?"*

**The Answer:**
* By default, in basic flip-flops, an internal write commits on the clock edge, while an asynchronous read during that cycle would observe the **old (stale) value**.
* This creates an internal structural data collision: the instruction in Decode reads the outdated state of `x5`.
* **The hardware solutions (Two valid industry approaches):**
  1. **Split-Phase Clocking:** The Register File writes on the *falling edge* (middle of the cycle) and reads on the *rising edge* (or combinational throughout the second half of the cycle).
  2. **Internal Register Bypassing (Write-First RegFile):** A small comparator circuit inside the register file checks:
     $$\text{if } (RegWrite == 1 \text{ and } rd_{wb} == rs_{id} \text{ and } rd_{wb} \ne 0)$$
     If true, the register file internally multiplexes the incoming `WriteData` directly onto the `ReadData` output bus, bypassing the storage cells entirely.

---

### Scenario D: The Branch in a Branch Shadow
> **Interviewer asks:** *"In a standard 5-stage pipeline without a branch predictor, branch decisions are resolved in EX (Stage 3). What happens if another branch instruction is located immediately in the branch delay slot / fetch pipeline?"*

**The Answer:**
* If the first branch evaluates as **taken** during its EX stage:
  1. The target address is computed ($\text{PC} + \text{ImmExt}$) and written into the PC.
  2. The two younger instructions already fetched behind it (in Stage 1 IF and Stage 2 ID) belong to the discarded path.
* Even if the instruction in Stage 2 (ID) is itself a branch, it must be **flushed** (cleared to an operational `NOP` or bubble) along with any other instructions in the branch shadow.
* **Hardware mechanism:** The Control Unit asserts synchronous reset / clear wires on the `IF/ID` and `ID/EX` pipeline registers. The speculative second branch is erased before it ever reaches the ALU or updates the Program Counter.

---

### Scenario E: Structural Hazards with Single-Ported Memory
> **Interviewer asks:** *"Why do we use separate Instruction Memory (I-Mem) and Data Memory (D-Mem) or separate L1 I-Cache and D-Cache? What exact hazard occurs if we combine them into a single Unified RAM?"*

**The Answer:**
* A **Structural Hazard** occurs (hardware resource conflict).
* In a 5-stage pipeline, the **Fetch (IF)** stage must access memory every single cycle to fetch the next instruction.
* In that exact same cycle, a `lw` or `sw` instruction currently traversing the **Memory (MEM)** stage must access memory to read or write data.
* If memory has only a single access port, both stages cannot access it simultaneously. The pipeline must stall the Fetch stage for one cycle whenever any memory instruction hits the MEM stage, introducing CPI degradation. 
* Separate caches (Harvard Architecture at L1) eliminate this contention entirely.
