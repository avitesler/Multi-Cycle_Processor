module processor_top(
	 input  logic [8:0] DIN,
    input  logic       Resetn,
    input  logic       Clock,
    input  logic       Run,
    output logic       Done,
    output logic [8:0] BusWires

);
	proc proc_inst (
	.DIN(DIN) ,	// input [8:0] DIN_sig
	.Resetn(Resetn) ,	// input  Resetn_sig
	.Clock(Clock) ,	// input  Clock_sig
	.Run(Run) ,	// input  Run_sig
	.Done(Done) ,	// output  Done_sig
	.BusWires(BusWires) 	// output [8:0] BusWires_sig
);



endmodule