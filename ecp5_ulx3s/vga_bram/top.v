/*

top.v

A simple test pattern using the hvsync_generator module.

VGA code adapted from:

DESIGNING VIDEO GAME HARDWARE IN VERILOG by Steven Hugg

*/

module top(
  input clk_25mhz,
  output hsync,     // hysnc 
  output vsync,     // vsync
  output [3:0] R, // red 
  output [3:0] G, // green 
  output [3:0] B, // blue 
  output [7:0] led   // LED 
);

wire display_on;
wire [10:0] hpos;
wire [10:0] vpos;
reg [22:0] counter;

// hook up hsync/vsync     
hvsync_generator hvsync_gen(
    .clk(clk_25mhz),
    .reset(0),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos)
);

// bram module
wire [11:0] rgb;
bram_buffer buf_rgb (
    .clk(clk_25mhz),
    .reset(0),
    .row(vpos[6:0]),
    .col(hpos[6:0]),
    .oe(1),
    .rgb(rgb)
);

// LED blink
reg RL;
always @ (posedge clk_25mhz)
    begin 
        counter <= counter + 1;
        if(!counter)
            RL = ~RL;
    end

// set color to a region 
wire [11:0] col = ((hpos >= 10'd256 && hpos < 10'd384) && 
                    (vpos >= 10'd128 && vpos < 10'd256)) ? 
                        rgb : 12'h888;
// assign RGB out 
assign {B, G, R} = display_on ? col : 12'd0;

// set LEDs
assign led[0] = RL;
assign led[7:1] = {7{0}};

endmodule
