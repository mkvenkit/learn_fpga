/* 

    Testbench for UART. 

*/


// Never forget this!
`default_nettype none

module tb();

reg clk;
reg resetn;
wire tx;

`define USE_SENDER
`ifdef USE_SENDER
// USE_SENDER
wire [7:0] data;
wire start_tx;
wire busy;

// UART module 
uart_tx uart1(
    .clk_25mhz(clk),
    .resetn(resetn),
    .data(data),
    .start_tx(start_tx),
    .busy(busy),
    .tx(tx)
);
// UART sender 
uart_sender us1 (
    .clk(clk),
    .resetn(resetn),
    .busy(busy),
    .data(data),
    .data_ready(start_tx)
);

`else // USE_SENDER

reg [7:0] data;
wire busy;  

reg start_tx;
uart_tx u1 (
    .clk_25mhz(clk),
    .resetn(resetn),
    .data(data),
    .start_tx(start_tx),
    .busy(busy),
    .tx(tx)
);
`endif // USE_SENDER

initial begin
    
    // initialise values
    clk = 1'b0;

`ifndef USE_SENDER
    data = 8'haf;
`endif 

    // reset 
    resetn = 1'b1;
    #4
    resetn = 1'b0;
    #4
    resetn = 1'b1;


`ifndef USE_SENDER
    start_tx = 1'b1;
`endif 

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