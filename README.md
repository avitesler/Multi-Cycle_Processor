# Multi-Cycle_Processor
A fully functional, multi-cycle processor featuring an optimized ALU with custom instruction set extensions, implemented in SystemVerilog

## 🎥 Hardware Demonstration

The processor executing instructions on the FPGA, displaying the main bus data and execution status flags via LEDs.

**Hardware Setup & Connections:**

The FPGA's switches and buttons interface directly with the processor's inputs (DIN, Run, Clock, Resetn), while the LEDs provide real-time monitoring of the 9-bit main data bus and the 'Done' signal.

---

## 📌 Project Overview
This project implements a multi-cycle digital processor. Designed using SystemVerilog and synthesized via Intel Quartus Prime, the system features a central 9-bit data bus and supports both standard arithmetic operations and custom hardware-accelerated instructions. 

### Key Features:
* **Custom ALU Architecture:** Includes an optimized parallel adder tree for fast bit-counting (`ones`) and a shift-based hardware multiplier (`specialMult`).
* **Safe Datapath Design:** Incorporates dynamic bit-casting (11-bit intermediate representation) within the ALU to prevent silent data truncation (overflow) during fast multiplication.
* **4-State Control FSM:** A control unit manages Fetch, Decode, Execute, and Writeback cycles with precise timing control over the shared data bus.
* **Complete Register Coverage:** Verified architecture ensuring flawless data routing between all 8 general-purpose registers and special purpose registers (IR, A, G).

---

## 🏗️ System Architecture

The architecture separates the control path from the data path, ensuring modularity and reliable timing constraints across the system.

<img width="461" height="164" alt="Block Diagram" src="https://github.com/user-attachments/assets/c8779ce2-9414-4531-8f09-d5c761c9482a" />

<img width="750" height="500" alt="Processor Schematic" src="https://github.com/user-attachments/assets/ec050f50-ad60-4f38-a1aa-3b29e2208de2" />

### Module Descriptions & Datapath
* `processor_top`: The top-level entity routing physical FPGA pins (Switches, Keys, LEDs) directly to the processor core.
* `regn` & `dec3to8`: Reusable synchronous register modules and 3-to-8 decoders for dynamic register addressing.
* `proc`: The heart of the system. It directly instantiates the internal registers, the main bus Multiplexer, the Control FSM, and incorporates the integrated **ALU logic**.

### Integrated ALU & Supported ISA
Embedded directly within the `proc` module's combinational logic, the ALU supports a customized 6-instruction set architecture (ISA):
* `mv` (000): Register-to-register copy.
* `mvi` (001): Load immediate value from the DIN bus.
* `add` (010) & `sub` (011): Standard addition and subtraction utilizing shared arithmetic resources.
* `ones` (100): Custom parallel hardware to count active high bits in a register.
* `specialMult` (101): Custom shift-based hardware to multiply a register's value by 3.5.

### Control Unit FSM
The internal management relies on a 4-state Finite State Machine (T0 to T3) to transition between Fetch and Execute cycles based on the decoded 3-bit Opcode.

<img width="940" height="180" alt="Control Unit FSM" src="https://github.com/user-attachments/assets/dcfb8302-c89e-40f2-9919-fb4c7c7952b2" />

---

## 🧪 Verification & Simulation

The design was verified using ModelSim. The verification environment utilizes a detailed testbench (`processor_top_tb`) designed to stress-test the Datapath, custom ALU logic, and FSM synchronization.

Instead of basic operational checks, the testbench achieves **100% register coverage** and covers asynchronous reset recoveries during mid-flight execution, parallel adder tree boundary validation (all 0s/1s), and precise casting checks for shift-based multiplication.

📁 **Simulation Waveforms:**
All detailed waveform captures showcasing the custom instruction executions and state cycle progressions can be found in the dedicated simulations folder: 
[Click here to view the simulation screenshots](./docs/simulations)

📝 **Full Verification Plan:**
The complete verification methodology and test plan document is available here:
[Click here to view the Test Plan](./docs/Verification_Test_Plan.pdf)

---

## 🚀 Future Roadmap
While the current core is fully functional, this architecture is built for scalability. Planned future enhancements include:
- [ ] Refactor the integrated ALU logic into a standalone structural module to fully decouple calculation logic from the `proc` datapath.
- [ ] Integrate Instruction Memory (IMEM) and Data Memory (DMEM).
- [ ] Expand the Instruction Set Architecture (ISA) to support conditional branching and jump instructions.

---

## 📬 Contact

- **Author:** [Avi Tesler]
- **Email:** [tesleravi1@gmail.com]
 
- **LinkedIn:** [www.linkedin.com/in/avi-tesler-0016ab377]
 
- **GitHub:** [https://github.com/avitesler]

---

## 📄 License

This project is released under the [MIT License](LICENSE).
