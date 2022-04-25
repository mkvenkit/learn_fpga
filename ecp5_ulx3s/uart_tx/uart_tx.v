/*

    uart_tx.v

    UART Transmitter module.

*/

// Never forget this!
`default_nettype none

module uart_tx (
    input clk_25mhz,        // input clock 
    input resetn,           // active low reset 
    input [7:0] data,       // 8 bit input data 
    input start_tx,         // flag to start TX
    output busy,            // high when TX is busy 
    output reg tx           // serial output data 
);

// ********************
// baud rate generator 
// ********************
// create a clock strobe at 115200 Hz
// f = 25000000
// f/115200 = 217.01388888888889
// f/217 = 115207.3732718894
// So divider is 2^16 / 217 = 302
// https://zipcpu.com/blog/2017/06/02/generating-timing.html 
reg	[15:0]	clk_counter;
reg bclk_stb;

// for simulation use large divider
`ifdef __ICARUS__
parameter divider = 16'd16384;
`else
parameter divider = 16'd302;
`endif // `ifdef __ICARUS__

always @(posedge clk_25mhz)
    // reset 
    if (!resetn) 
        clk_counter <= 16'd0;
    else 
        {bclk_stb, clk_counter} <= clk_counter + divider;

// state machine
parameter sIDLE = 2'b00;
parameter sTX = 2'b01;
reg [1:0] state;
reg [1:0] next_state;

// set busy flag 
assign busy = (state != sIDLE);

// Controller Module  
reg load_data;
reg tx_done;
// next state logic 
always @(posedge clk_25mhz) begin    

    // reset 
    if (!resetn) begin
        // initialize to idle
        next_state <= sIDLE;
        // set flag
        load_data <= 1'b0;        
    end
    else if (bclk_stb) begin
        case (state)
            sIDLE: begin
                // if flag set  
                if (start_tx) begin
                    next_state <= sTX;
                    load_data <= 1'b1;
                end
            end

            sTX: begin
                if (tx_done)
                    next_state <= sIDLE;
            end

            default: 
                next_state <= sIDLE;
        endcase
    end 
end 

// state transititon 
always @(posedge clk_25mhz) begin    
    // reset 
    if (!resetn) 
        state <= sIDLE;
    else if (bclk_stb)
        state <= next_state;
end

// Datapath module 

// data shift reg
// start followed by LSB is sent first
// stop-b7-b6-b5-b4-b3-b2-b1-b0-start 
reg [9:0] data_sr;
// number of bits (0 to 9) shifted out 
reg [3:0] nbits;

always @(posedge clk_25mhz) begin    
    // reset 
    if (!resetn) begin
        // reset nbits
        nbits <= 4'd0;
        // set flag 
        tx_done <= 1'b0;        
        // init shift reg to 1s
        data_sr <= {10{1'b1}};
        // set tx as high
        tx <= 1'b1;
    end
    else if (bclk_stb) begin
        case (state)
            sIDLE: begin
                if (load_data) begin
                    // load data to shift register
                    data_sr <= {1'b1, data, 1'b0};
                    // reset nbits
                    nbits <= 4'd0;
                    // set flag 
                    tx_done <= 1'b0;             
                end
            end

            sTX: begin
                if (nbits < 4'd10) begin
                    // send LSB
                    tx <= data_sr[0];
                    // shift 
                    data_sr <= {1'b1, data_sr[9:1]};
                    // increment bits
                    nbits <= nbits + 4'd1;
                end              
                else 
                    // set flag 
                    tx_done <= 1'b1;
            end

            default: 
                // reset nbits
                nbits <= 4'd0;   
        endcase
    end 
end 


endmodule