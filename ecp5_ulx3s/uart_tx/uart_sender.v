/*

    uart_sender.v


*/

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
parameter MAX_CYCLES = 8'd8;
reg [7:0] cwait;
reg data_ready;

// next state logic 
always @(posedge clk_25mhz) begin    
    // reset 
    if (!resetn) begin
        // initialize to idle
        next_state <= sIDLE;
        // initialize data 
        data <= 8'd0;
        // set flag 
        data_ready <= 1'b0;
    end
    else begin
        
        case (state)
            sIDLE: begin
                // if not busy
                if (!busy) begin
                    // next state is TX
                    next_state <= sTX;
                    // reset wait cycles
                    cwait <= 8'd0;
                end
            end

            sSET_DATA: begin
                // set flag     
                data_ready <= 1'b1;
                // set next state
                next_state <= sWAIT; 
            end 

            sWAIT: begin
                
                if (cwait < MAX_CYCLES) begin
                    // incr cycles
                    cwait <= cwait + 8'd1;
                end
                else begin
                    // set next state
                    next_state <= sIDLE;
                    // reset cycles
                    cwait <= 8'd0; 
                end

            end

            default: 
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


// send data via uart
always @ (posedge clk) begin
    // reset regs
    if (!resetn) begin 
        data <= 8'd0;
        data_ready <= 1'b0;
        curr_state <= sIDLE;
        cwait <= 8'd0;
    end
    else begin 
        case (curr_state)
            sIDLE: begin 
                if (!busy)
                    // set data 
                    curr_state <= sSET_DATA;
                else 
                    // reset flag
                    data_ready <= 1'b0;
            end 

            sSET_DATA: begin 
                // set data
                data <= data + 1;
                // switch to wait curr_state
                curr_state <= sWAIT;
            end

            sWAIT: begin 
                cwait <= cwait + 1;
                if (cwait == 8'd7) begin 
                    // set flag to tx
                    data_ready <= 1'b1;
                    // go to idle curr_state
                    curr_state <= sIDLE;
                    // reset wait
                    cwait <= 8'd0;
                end
            end

            default: 
                curr_state <= sIDLE;
        endcase
    end
end

endmodule