/* 

    bram_buffer.v

    This module implements a 128 x 128 x 16-bit buffer using BRAM.

*/

`default_nettype none

module bram_buffer (
  input clk,
  input reset,
  input [6:0] row,          // 0 to 127 
  input [6:0] col,          // 0 to 127
  input oe,                 // output enable
  output reg [11:0] rgb     // 4-bit x 3 BGR 
);

// declare a reg from which 
// block RAM will be inferred 
// 128 * 128 * 12-bit = 196608
parameter SZ = 128 * 128;
reg [11:0] buffer[SZ];

// initialize RAM 
`define USE_FILE
`ifdef USE_FILE 
// initialize from file 
initial begin 
    $readmemh("img.mem", buffer); 
end
`else // USE_FILE
// initialize with values 
integer k;
initial begin
    for (k = 0; k < SZ; k++) begin
        if (k < SZ/2)  
            buffer[k] = 12'h00F;
        else 
            buffer[k] = 12'hF00;
    end
end
`endif // USE_FILE

// compute read address 
wire [17:0] read_addr = 8'd128 * row + col;

// define read access 
always @ (posedge clk) begin
    if (oe)
        rgb <= buffer[read_addr];
end

endmodule
