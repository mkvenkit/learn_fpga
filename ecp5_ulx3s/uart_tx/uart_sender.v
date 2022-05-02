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
    output data_ready        //
);

parameter sIDLE         = 2'b00;
parameter sSET_DATA     = 2'b01;
parameter sWAIT         = 2'b10;

reg [1:0] curr_state;
reg [1:0] next_state;
parameter MAX_CYCLES = 8'd8;
reg [7:0] cwait;
reg data_ready;

// next state logic 
always @(*) begin    
    // initialize to idle
    next_state = sIDLE;
    
    // case 
    case (curr_state)
        sIDLE: begin
            // if not busy
            if (!busy) begin
                // next state is set data
                next_state = sSET_DATA;
            end
            else 
                next_state = sIDLE;
        end
        sSET_DATA: begin
            // set next state
            next_state = sWAIT; 
        end 
        sWAIT: begin
            if (cwait < MAX_CYCLES) begin
                // set next state
                next_state = sWAIT; 
            end
            else begin
                // set next state
                next_state = sIDLE;
            end
        end
        default: 
            // set next state
            next_state = sIDLE;
    endcase
end 


// state transititon 
always @(posedge clk) begin    
    // reset 
    if (!resetn) 
        curr_state <= sIDLE;
    else
        curr_state <= next_state;
end


// send data via uart
always @ (posedge clk) begin
    // reset regs
    if (!resetn) begin 
        data <= 8'd0;
        data_ready <= 1'b0;
        cwait <= 8'd0;
    end
    else begin 
        case (curr_state)
            sIDLE: begin 
                data <= 8'd0;
                data_ready <= 1'b0;
                cwait <= 8'd0;
            end 
            sSET_DATA: begin 
                // set data
                data <= data + 1;
                // set flag 
                data_ready <= 1'b1;
            end
            sWAIT: begin 
                cwait <= cwait + 1;
            end
            default: begin
                data <= 8'd0;
                data_ready <= 1'b0;
                cwait <= 8'd0;                
            end
        endcase
    end
end

endmodule