/*

top.v

A simple test pattern using the hvsync_generator module.

Code adapted from:

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

  reg myclk;
  reg RL;
  always @ (posedge clk_25mhz)
    begin 
      myclk = ~myclk;
      counter <= counter + 1;
      if(!counter)
        RL = ~RL;
    end

  // set pattern 
  wire r1 = display_on && (((hpos&7)==0) || ((vpos&7)==0));
  wire g1 = display_on && vpos[4];
  wire b1 = display_on && hpos[4];
  
  // assign RGB out 
  assign R = {4{r1}};
  assign G = {4{g1}};
  assign B = {4{b1}};
  
  // set LEDs
  assign led[0] = RL;
  assign led[7:1] = {7{0}};

endmodule
