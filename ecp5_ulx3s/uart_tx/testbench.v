/* 

    Testbench for UART. 

*/


// Never forget this!
`default_nettype none

module tb();

reg clk;
reg resetn;
wire tx;

reg [7:0] data;
wire busy;  
reg data_ready;

uart_tx u1 (
    .clk_25mhz(clk),
    .resetn(resetn),
    .data(data),
    .start_tx(data_ready),
    .busy(busy),
    .tx(tx)
);

initial begin
    // initialise values
    clk = 1'b0;
    // reset 
    resetn = 1'b1;
    #4
    resetn = 1'b0;
    #4
    resetn = 1'b1;
end

// send data 
always @(posedge clk) begin
    if (!resetn) begin
        data <= 8'd0;
        data_ready <= 1'b1;
    end
    else begin
        if (!busy)
            data <= data + 1; 
    end
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