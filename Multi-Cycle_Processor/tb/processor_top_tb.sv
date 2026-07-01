`timescale 1ns / 1ps

module processor_top_tb();
    logic [8:0] DIN;
    logic Resetn;
    logic Clock;
    logic Run;
    logic Done;
    logic [8:0] BusWires;
    
    processor_top uut (
        .DIN(DIN),
        .Resetn(Resetn),
        .Clock(Clock),
        .Run(Run),
        .Done(Done),
        .BusWires(BusWires)
    );

    // Clock Generation
    // Generates a 50MHz clock (20ns period).
    // Clock toggles every 10ns.
    initial begin
        Clock = 0;
        forever #10 Clock = ~Clock; 
    end

    // Task definition for sending instructions
    // This task abstracts the manual toggling of 
    // Run and DIN, making the testbench readable.

    task send_inst(input logic [8:0] opcode_word, input logic is_mvi, input logic [8:0] immediate_val);
        // Align to the negative edge to ensure setup/hold times are met
        @(negedge Clock);
        DIN = opcode_word;
        Run = 1'b1; // Trigger the FSM to move from T0 to T1
        
        @(negedge Clock); 
        Run = 1'b0; // Pull Run down so the FSM doesn't re-trigger after Done
        
        // If this is an 'mvi' instruction, the immediate value must be placed 
        // on the DIN bus during T1 so it can be loaded into the target register.
        if (is_mvi) begin
            DIN = immediate_val; 
        end
        
        // Wait asynchronously until the processor asserts the Done signal
        wait (Done == 1'b1); 
        
        // Wait one more clock cycle to let the FSM return to T0
        @(negedge Clock);    
    endtask

    // Main Test Sequence (Aligned with the Final Test Plan)
    initial begin
        // Initialization
        Run = 0;
        DIN = 9'b0;
        
        // Test 1.1: Asynchronous Reset
        // Verifies the system remains in state T0 and outputs are 0.
        Resetn = 0;
        #25; // Hold reset for more than one clock cycle
        Resetn = 1; // Release reset
        
        // Test 1.2: Idle State Hold
        // Verifies that without the Run signal, the FSM does nothing.
        #40; // Wait a few clock cycles to observe Idle behavior

        // Test 1.3: mvi R0, 5
        // Basic Datapath - Immediate load.
        // Opcode: 001. X=000. Y=000. -> IR = 001_000_000
        // ---------------------------------------------------------
        send_inst(9'b001_000_000, 1'b1, 9'd5);

        // ---------------------------------------------------------
        // Test 1.4: mv R1, R0
        // Basic Datapath - Register copy. Expected R1 = 5.
        // Opcode: 000. X=001. Y=000. -> IR = 000_001_000
        // ---------------------------------------------------------
        send_inst(9'b000_001_000, 1'b0, 9'd0);

        // ---------------------------------------------------------
        // Test 1.5: add R0, R1
        // Arithmetic - Adds 5 + 5. Expected R0 = 10.
        // Opcode: 010. X=000. Y=001. -> IR = 010_000_001
        // ---------------------------------------------------------
        send_inst(9'b010_000_001, 1'b0, 9'd0);

        // ---------------------------------------------------------
        // Test 1.6: sub R0, R0
        // Arithmetic - Self subtraction (10 - 10). Expected R0 = 0.
        // Opcode: 011. X=000. Y=000. -> IR = 011_000_000
        // ---------------------------------------------------------
        send_inst(9'b011_000_000, 1'b0, 9'd0);
        
        // ---------------------------------------------------------
        // Test 1.7: mvi R2, 511
        // Hardware Limits - Max Bound loading. Expected R2 = 511.
        // Opcode: 001. X=010. Y=000. -> IR = 001_010_000
        // ---------------------------------------------------------
        send_inst(9'b001_010_000, 1'b1, 9'd511);

        // ---------------------------------------------------------
        // Test 1.8: ones R2, R4
        // Custom Logic - Adder Tree Stress. R2 is 511 (all 1s). Expected R4 = 9.
        // Opcode: 100. X=010. Y=100. -> IR = 100_010_100 
        // ---------------------------------------------------------
        send_inst(9'b100_010_100, 1'b0, 9'd0);

        // ---------------------------------------------------------
        // Test 1.9: mvi R3, 507  -->  ones R3, R5
        // Custom Logic - Adder Tree Normal. 
        // 1. Load 507 (111111011) into R3.
        // 2. Count ones. Expected R5 = 8.
        // ---------------------------------------------------------
        // Opcode (mvi R3, 507): 001. X=011. Y=000. -> IR = 001_011_000
        send_inst(9'b001_011_000, 1'b1, 9'd507);
        // Opcode (ones R3, R5): 100. X=011. Y=101. -> IR = 100_011_101
        send_inst(9'b100_011_101, 1'b0, 9'd0);

        // ---------------------------------------------------------
        // Test 1.10: mvi R6, 0  -->  ones R6, R7
        // Custom Logic - Adder Tree Min Boundary (All 0s). Expected R7 = 0.
        // ---------------------------------------------------------
        // Opcode (mvi R6, 0): 001. X=110. Y=000. -> IR = 001_110_000
        send_inst(9'b001_110_000, 1'b1, 9'd0);
        // Opcode (ones R6, R7): 100. X=110. Y=111. -> IR = 100_110_111
        send_inst(9'b100_110_111, 1'b0, 9'd0);

        // ---------------------------------------------------------
        // Test 1.11: mvi R6, 146  -->  specialMult R6, R7
        // Special Mult - Critical Edge Case (Internal Casting Check).
        // Computes 146 * 3.5. Expected R7 = 511.
        // ---------------------------------------------------------
        // Opcode (mvi R6, 146): 001. X=110. Y=000. -> IR = 001_110_000
        send_inst(9'b001_110_000, 1'b1, 9'd146);
        // Opcode (specialMult R6, R7): 101. X=110. Y=111. -> IR = 101_110_111 
        send_inst(9'b101_110_111, 1'b0, 9'd0);
        
        // ---------------------------------------------------------
        // Test 1.12: Mid-Flight Asynchronous Reset
        // System Control - Interrupt an 'add R3, R2' instruction during T2.
        // Opcode: 010. X=011. Y=010. -> IR = 010_011_010
        // NOTE: We do not use send_inst() here because we want to interrupt execution!
        // ---------------------------------------------------------
        @(negedge Clock);
        DIN = 9'b010_011_010; // Setup 'add R3, R2'
        Run = 1'b1;           // Trigger instruction (FSM is in T0)
        
        @(negedge Clock);     // Clock edge: FSM moves to T1
        Run = 1'b0;           // Turn off Run signal
        
        @(negedge Clock);     // Clock edge: FSM moves to T2
        
        // ASYNCHRONOUS RESET ASSERTED
        // We are now in the middle of T2. Before T3 can write to R3, we hit reset!
        Resetn = 1'b0;
        
        #5; // Wait 5ns to clearly observe the asynchronous drop to T0 in the waveform
        
        Resetn = 1'b1;        // Release reset, system is now safely back in Idle/T0
        @(negedge Clock);     // Align back to clock
        
        // ---------------------------------------------------------
        // Simulation End
        // ---------------------------------------------------------
        
        #50;
        $display("Simulation completed successfully.");
        $stop; // Halts the ModelSim simulation
    end

endmodule