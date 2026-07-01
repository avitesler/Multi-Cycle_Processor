module regn #(parameter int n = 9) 
(
    input  logic [n-1:0] R,
    input  logic         Rin,
    input  logic         Clock,
    input  logic         Resetn,  // נוסף איפוס כדי לעמוד בתקן!
    output logic [n-1:0] Q
);

    always_ff @(posedge Clock or negedge Resetn) begin
        if (!Resetn)
            Q <= '0;
        else if (Rin)
            Q <= R;
    end
    
endmodule