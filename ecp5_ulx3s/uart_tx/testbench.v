/* 

    Testbench for UART. 

*/


// Never forget this!
`default_nettype none

module tb();

reg clk;
reg resetn;
wire [7:0] data;
wire busy;  
wire tx;

wire start_tx;
uart_tx u1 (
    .clk_25mhz(clk),
    .resetn(resetn),
    .data(data),
    .start_tx(start_tx),
    .busy(busy),
    .tx(tx)
);

uart_sender us1 (
    .clk(clk),
    .resetn(resetn),
    .busy(busy),
    .data(data),
    .data_ready(start_tx)
);


initial begin
    
    // initialise values
    clk = 1'b0;
    
    // reset 
    resetn = 1'b1;
    #5
    resetn = 1'b0;
    #5
    resetn = 1'b1;

end

// generate clk
always @ ( * ) begin
    #1
    clk <= ~clk; 
end

initial begin
    $dumpfile("testbench.vcd");
    $dumpvars;
    #10000
    $finish;
end
endmodule