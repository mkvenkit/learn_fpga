/*

    uart_sender.v


*/

// Never forget this!
`default_nettype none

module uart_sender(
    input clk,
    input resetn,
    input busy,
    output reg [7:0] data,
    output reg data_ready        //
);

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

endmodule