module proc (
    input  logic [8:0] DIN,
    input  logic       Resetn,
    input  logic       Clock,
    input  logic       Run,
    output logic       Done,
    output logic [8:0] BusWires
);
    
    // FSM State Definitions
    typedef enum  logic [1:0] {T0=2'b00, T1=2'b01, T2=2'b10, T3=2'b11} t_state;    
    t_state Tstep_Q, Tstep_D;

    // Control Signals Declarations
    logic [7:0] Rin;       // Register write enables
    logic [7:0] Rout;      // Register read enables to BusWires
    logic G_in;            // ALU result register write enable
    logic G_out;           // ALU result register read enable
    logic DIN_out;         // External data bus read enable
    logic A_in;            // ALU operand register write enable
    logic [1:0] ALU;       // ALU operation selector
    logic IRin;            // Instruction Register write enable
    
    // Internal Datapath Signals (Wires)
    logic [8:0] R0, R1, R2, R3, R4, R5, R6, R7; // Wires carrying outputs from general purpose registers
    logic [8:0] A;         // Wire carrying output from ALU first operand register
    logic [8:0] G;         // Wire carrying output from ALU result register
    logic [8:0] ALU_Result;// Wire carrying ALU combinational output
    
    logic [8:0] IR;        // Wire carrying output from Instruction Register
    logic [2:0] I;         // Combinational wire for Opcode field (Top 3 bits of IR)
    logic [7:0] Xreg, Yreg;// Combinational wires for decoded one-hot register selectors
    logic En;              // General enable wire


    assign I = IR[8:6]; // Holds the operation number

 
    // Decode the 3-bit Rx and Ry fields into 8-bit one-hot signals
    dec3to8 decX (.W(IR[5:3]), .En(1'b1), .Y(Xreg));
    dec3to8 decY (.W(IR[2:0]), .En(1'b1), .Y(Yreg));

    // Control FSM state table (Next State Logic)
    always_comb begin
        unique case (Tstep_Q)
            T0: begin 
                if (!Run) Tstep_D = T0; // Wait for Run signal
                else      Tstep_D = T1; // Proceed to execution
            end
            T1: begin
                    if (I == 3'b000 || I == 3'b001) Tstep_D = T0; // move and movei needs only 2 cycles so we're done
                    else     Tstep_D = T2;
            end
                T2: begin
                    if (I == 3'b100 || I == 3'b101) Tstep_D = T0; // ones and specialMult needs only 3 cycles so we're done
                    else     Tstep_D = T3;   
            end
            T3: begin 
                Tstep_D = T0; // Final state for 4-cycle instructions
            end                

            default: Tstep_D = T0;
        endcase
    end

    // Control FSM outputs (Combinational Control Logic)
    always_comb begin
        // Default values to prevent unintended latches
          IRin = 1'b0;
          Rin = 8'b0;
          Rout = 8'b0;
          G_in = 1'b0;
          G_out = 1'b0;
          DIN_out = 1'b0;
          A_in = 1'b0;
          ALU = 2'b0;
          Done = 1'b0;
          
        unique case (Tstep_Q)
            T0: begin // Store DIN in IR in time step 0 (Fetch)
                IRin = 1'b1;
            end
            
            T1: begin // Define signals in time step 1
                unique case (I)
                          3'b000: begin // move (Rx <- Ry)
                                Rout = Yreg; // Place Ry on the bus
                                Rin = Xreg;  // Write bus to Rx
                                Done = 1'b1;
                            end
                            3'b001: begin // movi (Rx <- Immediate)
                                DIN_out = 1'b1; // Place external DIN on the bus
                                Rin = Xreg;     // Write bus to Rx
                                Done = 1'b1;
                            end
                            3'b010: begin // add (Setup: A <- Rx)
                                Rout = Xreg; // Place Rx on the bus
                                A_in = 1'b1; // Load Rx into A
                            end
                            3'b011: begin // sub (Setup: A <- Rx)
                                Rout = Xreg;
                                A_in = 1'b1;
                            end
                            3'b100: begin // ones (Setup: G <- ones(Rx))
                                Rout = Xreg; // Place Rx on the bus
                                ALU = 2'b10; // Select 'ones' operation
                                G_in = 1'b1; // Store result in G
                            end
                            3'b101: begin // specialMult (Setup: G <- mult(Rx))
                                Rout = Xreg;
                                ALU = 2'b11;
                                G_in = 1'b1;
                            end                            
                endcase
            end
            
            T2: begin // Define signals in time step 2
                unique case (I)
                            3'b010: begin // add (Setup: G <- A + Ry)
                                Rout = Yreg; // Place Ry on the bus
                                G_in = 1'b1; // Store addition result in G
                            end
                            3'b011: begin // sub (Setup: G <- A - Ry)
                                Rout = Yreg;
                                G_in = 1'b1;
                                ALU = 2'b01; // Select subtract operation
                            end
                            3'b100: begin // ones (Writeback: Ry <- G)
                                G_out = 1'b1; // Place G on the bus
                                Rin = Yreg;   // Write bus to Ry
                                Done = 1'b1;
                            end
                            3'b101: begin // specialMult (Writeback: Ry <- G)
                                G_out = 1'b1;
                                Rin = Yreg;
                                Done = 1'b1;
                            end                                
                endcase
            end
            
            T3: begin // Define signals in time step 3
                unique case (I)
                          3'b010: begin // add (Writeback: Rx <- G)
                                G_out = 1'b1; // Place G on the bus
                                Rin = Xreg;   // Write bus to Rx
                                Done = 1'b1;
                            end
                            3'b011: begin // sub (Writeback: Rx <- G)
                                G_out = 1'b1;
                                Rin = Xreg;
                                Done = 1'b1;
                            end
                endcase
            end
            default: ;
        endcase
    end

    // Control FSM flip-flops (State Register with Async Reset)
    always_ff @(posedge Clock or negedge Resetn) begin
        if (!Resetn) begin
                Tstep_Q <= T0;
        end else begin
            Tstep_Q <= Tstep_D;
        end
    end

    // Instantiations of registers
    
     // Instantiations of Registers R_0 until R_7
     regn #(.n(9)) reg_0 (.R(BusWires), .Rin(Rin[0]), .Clock(Clock), .Resetn(Resetn), .Q(R0));
     regn #(.n(9)) reg_1 (.R(BusWires), .Rin(Rin[1]), .Clock(Clock), .Resetn(Resetn), .Q(R1));
     regn #(.n(9)) reg_2 (.R(BusWires), .Rin(Rin[2]), .Clock(Clock), .Resetn(Resetn), .Q(R2));
     regn #(.n(9)) reg_3 (.R(BusWires), .Rin(Rin[3]), .Clock(Clock), .Resetn(Resetn), .Q(R3));
     regn #(.n(9)) reg_4 (.R(BusWires), .Rin(Rin[4]), .Clock(Clock), .Resetn(Resetn), .Q(R4));
     regn #(.n(9)) reg_5 (.R(BusWires), .Rin(Rin[5]), .Clock(Clock), .Resetn(Resetn), .Q(R5));
     regn #(.n(9)) reg_6 (.R(BusWires), .Rin(Rin[6]), .Clock(Clock), .Resetn(Resetn), .Q(R6));
     regn #(.n(9)) reg_7 (.R(BusWires), .Rin(Rin[7]), .Clock(Clock), .Resetn(Resetn), .Q(R7));

	  // Instantiation of IR
     regn #(.n(9)) reg_IR (.R(DIN), .Rin(IRin), .Clock(Clock), .Resetn(Resetn), .Q(IR));
    
     // Instantiation of A
     regn #(.n(9)) reg_A (.R(BusWires), .Rin(A_in), .Clock(Clock), .Resetn(Resetn), .Q(A));
    
    
     // Instantiation of G
     regn #(.n(9)) reg_G (.R(ALU_Result), .Rin(G_in), .Clock(Clock), .Resetn(Resetn), .Q(G));
    
    
     // The Main Multiplexer for the BusWires
    
     always_comb begin
        // Safe default value to prevent unintended latches
        BusWires = DIN; 
        
        // Multiplexer routing based on One-Hot conditions
        if      (DIN_out) BusWires = DIN;
        else if (Rout[0]) BusWires = R0;
        else if (Rout[1]) BusWires = R1;
        else if (Rout[2]) BusWires = R2;
        else if (Rout[3]) BusWires = R3;
        else if (Rout[4]) BusWires = R4;
        else if (Rout[5]) BusWires = R5;
        else if (Rout[6]) BusWires = R6;
        else if (Rout[7]) BusWires = R7;
        else if (G_out)   BusWires = G;
    end
    
 
    // The ALU
    // Resource Sharing Architecture:
    // We separate the critical paths. The standard Add/Sub shares 
    // a single unit, while the 'specialMult' gets a dedicated 
    // fast subtractor
    // ==========================================
    logic [3:0] ones_count;   // Final count for the 'ones' instruction
    logic [3:0] level1 [0:2]; // Intermediate array for the Adder Tree

    logic [8:0] add_sub_res;  // Result of standard Add/Sub
    logic [8:0] mult_res;     // Result of fast specialMult

    // ALU Stage 1: Parallel Hardware Arithmetic
    // Quartus will synthesize this into a single shared Add/Sub unit
    assign add_sub_res = (ALU == 2'b01) ? (A - BusWires) : (A + BusWires);
    
    // specialMult instruction
    // (Rx << 2) gives mult by 4, (Rx >> 1) gives division by 2.
    // sub between this two shift gives as 3.5: (4-0.5) * Rx = 3.5 * Rx
    // As defined, Rx is even, so no precision is lost.
    assign mult_res = 9'( (11'(BusWires) << 2) - (11'(BusWires) >> 1) );

    // ALU Stage 2: Output Routing & 'ones' Execution
    always_comb begin
        ALU_Result = 9'b0; 
        ones_count = 4'b0;
        
        unique case (ALU)
            // Route the standard operations to the shared unit
            2'b00, 2'b01: ALU_Result = add_sub_res;
            
            // Route the specialMult to its dedicated fast unit
            2'b11: ALU_Result = mult_res;
                
            2'b10: begin // 'ones' instruction
                // Hardware Concept: Parallel Adder Tree using a 'for' loop
                // 
                // Explanation:
                // Instead of a 9-iteration loop (which creates a long 
                // critical path of 9 sequential adders), we force the 
                // synthesizer to build a parallel tree.
                // 
                // Step 1: The 'for' loop iterates only 3 times. In each 
                // iteration, it sums a distinct group of 3 bits in parallel.
                for (int i = 0; i < 3; i++) begin
                    level1[i] = BusWires[i*3] + BusWires[i*3+1] + BusWires[i*3+2];
                end
                
                // Step 2: Sum the 3 intermediate results outside the loop.
                ones_count = level1[0] + level1[1] + level1[2];
                
                // Pad the 4-bit count to match the 9-bit Data Bus
                ALU_Result = {5'b00000, ones_count};
            end
        endcase
    end

endmodule
