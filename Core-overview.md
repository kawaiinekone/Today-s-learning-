#  Eco-Cheat RISC-V Core

### An Eco-Friendly, Hardware-Accelerated 3-Stage RISC-V Processor, Built From Scratch

---

## 1.  The Big Picture: Why Are We Doing This?

Have you ever wondered what actually happens when you click a button on your phone, run a line of Python code, or play a video game?

Most people think computers understand English words, variables, or functions. **They do not.**

A computer is fundamentally a collection of billions of microscopic electronic switches called **transistors**, carved out of polished beach sand (silicon). Those switches only understand one physical reality: **high electrical voltage (roughly 1.2 V, which we call binary `1`)** and **no voltage (0 V or Ground, which we call binary `0`)**.

```text
High-Level Code (Python, C, Java)
│
▼ (The compiler translates code into numbers)
32-Bit Instruction Numbers (e.g., 0x00500093)
│
▼ (These numbers travel as electrical voltages on copper wires)
┌─────────────────────────────────────────────────────────────┐
│                    THE PROCESSOR CORE                       │
│                                                             │
│  [ FETCH ]       ──►  [ DECODE ]      ──►  [ EXECUTE ]      │
│  Read numbers         Decide which         Flick switches   │
│  from memory          wires turn on        and do math      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

A **Processor Core** is the beating mechanical heart of a computer. It runs an endless three-step loop billions of times every second:

1. **Fetch:** Pull a 32-bit number (an instruction) from memory.
2. **Decode:** Look at the pattern of 1s and 0s to figure out which switches need to be turned on.
3. **Execute:** Run the electricity through math units or memory storage, save the answer, and move to the next instruction.

---

## 2.  What Makes Our Core Unique?

Most beginner processors operate like a brute-force light switch: they waste massive amounts of battery power and take 40 to 50 clock cycles to complete basic bit-counting operations.

We are designing an **Application-Specific Embedded Edge Core** tailored for devices that run on tiny coin-cell batteries for years, such as smart medical patches, agricultural soil sensors, or smartwatch health monitors.

### Our Two Architectural Innovations

###  Innovation 1: The "Cheat-Code" Hardware Accelerator

In real-world health sensors and network communication, processors constantly need to count how many binary `1`s are inside a number. This is called **Population Count** (`popcount`).

- **The normal way:** A standard processor runs an assembly loop that shifts the number bit by bit, checks for a 1, adds to a counter, and repeats 32 times. This burns **30 to 50 wasted clock cycles**.
- **Our cheat-code way:** We etched a custom parallel adder tree directly into the math unit and added a custom hardware instruction:

```assembly
popcount rd, rs1
```

It counts all the 1s across 32 bits simultaneously in exactly **one clock cycle**.

### Innovation 2: The "Green-Heart" Eco-Gate (Operand Isolation)

In modern chips, electricity is wasted every time a wire flips from 0 to 1.

- Even when a program is just loading a value from memory or checking an `if/else` condition, standard processors leave their big math units connected to active, bouncing data lines. Those unused gates flicker and burn battery power for no reason.
- **Our eco solution:** We built an electronic gate right in front of the Arithmetic Logic Unit (ALU). If the current instruction is not doing math, the Eco-Gate clamps the ALU input wires to zero. The internal transistors stop flickering, suppressing wasted dynamic switching power.

---

## 3.  The Laundry Analogy: Why a 3-Stage Pipeline?

To understand how our core functions, consider doing laundry.

**Non-pipelined (single-cycle):**

```text
Load 1: [ Wash (30m) ──► Dry (30m) ──► Fold (30m) ] = 90 mins
Load 2:                                              [ Wash (30m) ──► Dry (30m) ──► Fold (30m) ] = 90 mins

Total: 180 minutes for 2 loads. The machines sit empty most of the time.
```

**Our 3-stage pipeline:**

```text
Time:     0 min           30 min          60 min          90 min
Stage 1:  [Load 1: Wash]  [Load 2: Wash]  [Load 3: Wash]
Stage 2:                  [Load 1: Dry ]  [Load 2: Dry ]  [Load 3: Dry ]
Stage 3:                                  [Load 1: Fold]  [Load 2: Fold]  [Load 3: Fold]

At steady state, an entire load of laundry finishes every 30 minutes.
```

### Architecture Comparison

| Design Style | How It Operates | Why It's Great | The Hidden Catch |
|---|---|---|---|
| **Single-Cycle** | One instruction runs through the entire chip in one giant clock tick. | Easiest to write; no data collisions. | Painfully slow clock speed. The clock must wait for the slowest circuit on the chip. |
| **5-Stage Pipeline** | Chops the chip into 5 tiny rooms. | High theoretical clock speeds. | Complex to debug. You must handle memory stalls (load-use hazards), branch stalls, and multi-cycle forwarding. |
| **Our 3-Stage Design** | Chops the chip into 3 balanced rooms: Fetch, Decode, and Execute/Memory. | Zero memory stall hazards. Branch penalty drops to only 1 cycle. Clean and synthesizes reliably. | Slightly lower peak frequency than a 5-stage core. |

---

## 4.  The 12 Hardware Bricks

A processor core is assembled like a Lego set. Here is the blueprint of every module we build.

```text
=============================== COMPLETE CORE ARCHITECTURE ===============================

  STAGE 1: FETCH              STAGE 2: DECODE              STAGE 3: EXECUTE / COMMIT
 ┌────────────────────┐      ┌─────────────────────┐      ┌──────────────────────────┐
 │ Brick 1: pc_reg    │      │ Brick 4: control_unit│      │ Brick 8:  eco_gate       │
 │ Brick 2: imem      │      │ Brick 5: regfile    │      │ Brick 9:  alu_top        │
 └─────────┬──────────┘      │ Brick 6: imm_gen    │      │ Brick 10: branch_unit    │
           │                 └──────────┬──────────┘      │ Brick 11: dmem           │
           ▼                            │                 │ Brick 12: forwarding_unit│
   ┌───────────────┐                    ▼                 └──────────────────────────┘
   │ Barrier 1:    │            ┌───────────────┐
   │ Brick 3:      │            │ Barrier 2:    │
   │ if_id_reg     │            │ Brick 7:      │
   └───────────────┘            │ id_ex_reg     │
                                └───────────────┘
==========================================================================================
```

### Stage 1: Instruction Fetch (IF)

#### Brick 1: Program Counter Register (`pc_reg.v`)
- **What it is:** A 32-bit hardware register made of 32 microscopic memory cells (D flip-flops).
- **What it does:** Holds the address of the instruction currently being read. It has a built-in adder that calculates `PC + 4` on every clock beat (each instruction takes 4 bytes). If a branch or jump evaluates to true, it overrides the `+4` and jumps to the target address instead.
-------------------------------------------------------------------------------------------
  - **In Hardware Terms (How Your Core Actually Does It)**
Look at what feeds into your pc_reg: it has a 2-to-1 multiplexer right in front of its input (next_pc):
```
                  +-------------+
   PC + 4 ------->| 0           |
                  |     MUX     |-------> [ PC Register ]
Target Address -->| 1           |
(e.g., 0x0010)    +-------------+
                         ^
                         |
                   branch_taken
```

- **When branch_taken == 0 (Normal operation):**
The MUX selects input 0 (PC + 4). The PC points to the very next sequential instruction.

- **When branch_taken == 1 (Branch is TRUE or a Jump happens):**
The MUX flips to input 1 (branch_target). It overrides the +4 adder and loads the branch destination into the PC, so the CPU begins executing from that new location on the very next clock cycle.


#### Brick 2: Instruction Memory (`imem.v`)
- **What it is:** The library where the program's compiled instructions live.
- **What it does:** Receives the address from the Program Counter, looks inside its storage table, and outputs the raw 32-bit instruction word at that slot.
- **Special trick:** Memory is organized in words (groups of 4 bytes). We drop the lowest two address bits (`addr[31:2]`) so we index cleanly without skipping lines.

### Barrier 1: The First Airlock

#### Brick 3: IF/ID Pipeline Register (`if_id_reg.v`)
- **What it is:** A wall of flip-flops placed between Stage 1 and Stage 2.
- **What it does:** Captures the fetched instruction on the clock tick and holds it steady so Stage 2 can study it, while Stage 1 moves forward to fetch the next instruction.
- **Safety valve (flush):** If a branch is taken in Stage 3, this register has a flush wire that wipes its stored instruction to zero (NOP, "do nothing") so the wrong speculative instruction is discarded.

### Stage 2: Instruction Decode & Operand Fetch (ID)

#### Brick 4: Control Unit (`control_unit.v`)
- **What it is:** The central traffic controller of the processor.
- **What it does:** Reads the opcode (the first 7 bits of the instruction) and asserts or clears control signals:
  - `RegWrite`: "Get ready to save an answer into a register."
  - `ALUSrc`: "ALU, do math with another register or with a hardcoded constant?"
  - `MemRead` / `MemWrite`: "Turn data RAM on or off."
  - `is_cheat`: "This is our custom opcode. Turn on the PopCount accelerator."
  - `is_alu_op`: "This is standard math. Tell the Eco-Gate to wake up the ALU."

#### Brick 5: Register File (`regfile.v`)
- **What it is:** The fast-access scratchpad of the CPU: 32 registers (`x0` through `x31`), each 32 bits wide.
- **What it does:**
  - Reads two source values (`rs1` and `rs2`) simultaneously at any moment, without waiting for a clock tick.
  - Writes results back to the destination register (`rd`) strictly on the clock tick.
- **The golden rule of RISC-V:** Register `x0` is hardwired to ground. It always evaluates to `0x00000000`. Any attempt to overwrite `x0` is discarded by hardware.

#### Brick 6: Immediate Generator (`imm_gen.v`)
- **What it is:** An un-scrambler and sign-extension circuit.
- **What it does:** Often an instruction includes a hardcoded number inside itself (like the `5` in `addi x1, x0, 5`). RISC-V stores these numbers across different bit positions depending on the instruction format (I, S, B, U, J). This module extracts the bits, puts them back in numeric order, and extends them to a full 32-bit signed number.

### Barrier 2: The Second Airlock

#### Brick 7: ID/EX Pipeline Register (`id_ex_reg.v`)
- **What it is:** A very wide barrier register (over 150 flip-flops side by side).
- **What it does:** Takes all the decoded control wires, register data values, register addresses, and immediate numbers from Stage 2 and holds them static for Stage 3. It also has a flush pin to erase incorrect instructions when a branch misprediction occurs.

### Stage 3: Execute, Memory & Writeback (EX / MEM / WB)

#### Brick 8: Eco-Gate Unit (`eco_gate.v`)
- **What it is:** An array of 2-to-1 multiplexers (electronic switches) guarding the ALU inputs.
- **What it does:** Monitors the `is_alu_op` wire. If the instruction is a memory access (`lw`, `sw`) or a branch comparison (`beq`), it forces the ALU inputs to flat 0s. The internal adder transistors stay still, preventing wasted dynamic switching power.

#### Brick 9: Master ALU + Cheat-Code Accelerator (`alu_top.v`)
- **What it is:** The mathematical engine of the core.
- **What it does:**
  - Runs standard arithmetic: `add`, `sub`, bitwise `and`, `or`, `xor`, shifts (`sll`, `srl`, `sra`), and comparisons (`slt`, `sltu`).
  - Houses our custom **PopCount engine**: an optimized hardware adder tree that counts all set bits in a register within one clock cycle.
  - Outputs a `zero` flag that tells the branch unit whether two compared numbers were equal.

#### Brick 10: Branch Resolution Unit (`branch_unit.v`)
- **What it is:** The decision-making unit for loops and `if/else` checks.
- **What it does:** Checks whether a condition was met (e.g., branch if equal). If true:
  - Asserts `branch_taken = 1`.
  - Calculates the destination address: `Target = PC + Immediate`.
  - Overrides the Program Counter in Stage 1 and flushes the pipeline barriers.

#### Brick 11: Data Memory (`dmem.v`)
- **What it is:** The RAM workspace of the processor, where program variables, arrays, and buffers live.
- **What it does:**
  - On a store (`sw`), saves a 32-bit register value into a memory slot.
  - On a load (`lw`), retrieves a 32-bit value from a memory slot so it can be committed back into a register.

#### Brick 12: Forwarding Unit (`forwarding_unit.v`)
- **What it is:** An intelligent bypass circuit that eliminates execution stalls.
- **What it does:** Suppose instruction 1 calculates `x1 = 5 + 2`, and instruction 2 immediately needs `x3 = x1 + 10`. Without forwarding, instruction 2 would have to wait for instruction 1 to write its result back into the register file. The forwarding unit detects this hazard, grabs the calculated answer directly off the ALU output wire, and feeds it into the ALU input for the next cycle.
- **Critical safety guard:** It strictly verifies `ex_rd != 0`, ensuring it never forwards non-zero values intended for register `x0`.

---

## 5.  Wiring the Blocks: How They Talk to Each Other

All 12 bricks are placed inside a top-level container file called `core_top.v`. Here is how data and control signals flow between them:

```text
                      ┌───────────────────────────────────────────────┐
                      │              BRANCH FEEDBACK BUS              │
                      │         branch_taken, branch_target           │
                      └───────┬───────────────────────────────┬───────┘
                              │                               │
                              ▼ (Overrides PC)                ▼ (Flushes Registers)
  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
  │  pc_reg      ├──►  │  if_id_reg   ├──►  │  control     ├──►  │  id_ex_reg   │
  │  (Brick 1)   │     │  (Barrier 1) │     │  & regfile   │     │  (Barrier 2) │
  └──────┬───────┘     └──────────────┘     └──────┬───────┘     └──────┬───────┘
         │                                         │                    │
         ▼                                         ▼                    ▼
  ┌──────────────┐                          Sign-extended       Gated Operands
  │  imem        │                          Immediates &        To ALU & Memory
  │  (Brick 2)   │                          Register Data               │
  └──────────────┘                                                      ▼
                                                                 ┌──────────────┐
                                                                 │  alu_top,    │
                                                                 │  branch_unit │
                                                                 │  & dmem      │
                                                                 └──────┬───────┘
                                                                        │
                                                                   wb_result
                                                                        │
                      ┌─────────────────────────────────────────────────┘
                      ▼
         Register File Write Port (Stage 2)
```

1. **The clock pulse arrives:** The Program Counter updates, and Instruction Memory outputs a 32-bit instruction word.
2. **Barrier 1 latches:** The instruction slides into `if_id_reg`.
3. **Stage 2 decodes:** The Control Unit decodes the instruction, the Register File looks up the operands, and the Immediate Generator sign-extends any constant offsets.
4. **Barrier 2 latches:** The operands and control lines are latched into `id_ex_reg`.
5. **Stage 3 executes:** The Eco-Gate isolates unused lines, the ALU or Cheat-Code engine computes the result, Data Memory reads or writes if needed, and the final value travels back across the writeback bus into the Register File.

---

## 6.  What Happens If You Wire It Wrong? (Real Silicon Disasters)

In software, a bug throws an error message (like `NullPointerException`). In hardware design, there are no error messages. Miswiring a connection causes the chip to silently calculate garbage, freeze into deadlock, or overheat.

###  Disaster 1: Forgetting the x0 Forwarding Guard

**The mistake:** You write your forwarding check as:

```verilog
if (ex_reg_write && (ex_rd == id_rs1)) forward_a = 1;
```

**The failure:** Suppose your code runs `addi x0, x0, 5` (which is supposed to discard the 5). The next instruction reads `x0`. Your forwarding unit detects a match on register index 0 and forwards `5`. Suddenly `x0` appears to hold a non-zero value, violating the RISC-V specification and corrupting loop counters across your program.

**The fix:** Add `&& (ex_rd != 0)` to the condition.

###  Disaster 2: The Inferred Latch (The Missing `else`)

**The mistake:** In your combinational ALU block, you write an `if` condition for addition but forget the `else` branch or a `default` case.

**The failure:** In software, a missing `else` does nothing. In silicon, the wires ask: "What voltage do I hold when the condition is false?" The synthesis tool assumes you want to remember the old value and creates a feedback loop of gates called an **inferred latch**. This creates timing glitches, slows your clock frequency, and causes random calculation failures.

**The fix:** Always assign a default value, or cover every case.

###  Disaster 3: Shifting by 32 Bits Instead of `b[4:0]`

**The mistake:** Wiring all 32 bits of operand B directly into your barrel shifter instead of only the lowest 5 bits (`b[4:0]`).

**The failure:** If register B holds 32, standard Verilog shifts the number by 32 positions, clearing the register to 0. The RISC-V standard states that shift amounts are evaluated modulo 32 (`32 % 32 = 0`), meaning the number should not have been shifted at all.

**The fix:** Use only `b[4:0]` as the shift amount.

---

## 7.  Testing on an FPGA: How Do We Prove It Works?

You do not need to spend millions of dollars building a custom chip at a factory. We can prove our processor runs by loading it onto an **FPGA** (Field-Programmable Gate Array).

```text
       [ Your Computer ]
               │
               ▼ (Synthesize Verilog using Vivado or Yosys)
       [ The Bitstream File ]
               │
               ▼ (Sent over USB cable)
      ┌───────────────────────────────────┐
      │          THE FPGA BOARD           │
      │                                   │
      │  ┌───────────────┐ ┌───────────┐  │
      │  │  YOUR RISC-V  │ │   BRAM    │  │──► Physically toggles LEDs
      │  │     CORE      │ │  (Memory) │  │──► Transmits data over UART to PC
      │  └───────────────┘ └───────────┘  │
      └───────────────────────────────────┘
```

### The Three Stages of Verification

#### 1. Software Waveform Simulation (GTKWave)

Before loading the core onto physical hardware, run the testbench using Icarus Verilog (`iverilog`). It creates a trace file (`.vcd`) that lets you inspect every wire across time:

- **Check 1:** Does the Program Counter (`pc`) increment by 4 on every cycle (`0x0`, `0x4`, `0x8`)?
- **Check 2:** Does the `wb_result` bus show the expected math results?
- **Check 3:** Does `branch_taken` pulse high for one clock cycle and flush Barrier 1?

#### 2. The UART Serial Console Test

Connect the core to a serial transmitter wire (UART) linked to your computer via USB. Compile an assembly program that runs both a standard software PopCount loop and the single-cycle Cheat-Code instruction. The core prints its execution profile straight to your terminal:

```text
========================================
      ECO-CHEAT RISC-V CORE OK!
========================================
[1] Testing Standard PopCount Loop...
    Cycles Elapsed: 432 clock cycles
[2] Testing Hardware Cheat-Code...
    Cycles Elapsed: 1 clock cycle!
----------------------------------------
ACCELERATION FACTOR: 432x FASTER!
DYNAMIC ENERGY SAVED: 38% ALU Gated
========================================
```

#### 3. The Physical LED "Heartbeat"

Map an output wire from the core to a physical LED on the FPGA board, and write a countdown loop that toggles the LED on and off. When you see that light blink on the circuit board, you are watching your custom processor execute machine instructions in th
