// uart_tx.v
// Simple UART transmitter, 8N1 format.
//
// Parameters:
//   CLK_FREQ  - system clock frequency in Hz (default 48 MHz)
//   BAUD_RATE - UART baud rate (default 921600)
//
// Usage:
//   Assert 'send' for one clock cycle with 'data' valid.
//   'busy' remains high until the byte has been fully transmitted.
//   Do not assert 'send' while 'busy' is high.

module uart_tx #(
    parameter CLK_FREQ  = 48_000_000,
    parameter BAUD_RATE = 921_600
)(
    input  wire       clk,
    input  wire       resetn,
    input  wire [7:0] data,   // byte to transmit
    input  wire       send,   // pulse high for 1 clk to start transmission
    output reg        tx,     // UART TX line
    output reg        busy    // high while transmitting
);

    // Number of system clocks per UART bit
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;  // = 52 for 48 MHz / 921600

    // Bit counter: 10 bits total (1 start + 8 data + 1 stop)
    localparam TOTAL_BITS = 10;

    reg [$clog2(CLKS_PER_BIT)-1:0] clk_cnt;
    reg [$clog2(TOTAL_BITS)-1:0]   bit_cnt;
    reg [9:0] shift_reg;  // {stop, data[7:0], start}

    always @(posedge clk) begin
        if (!resetn) begin
            tx        <= 1'b1;   // idle high
            busy      <= 1'b0;
            clk_cnt   <= 0;
            bit_cnt   <= 0;
            shift_reg <= 10'h3FF;
        end else begin
            if (!busy) begin
                tx <= 1'b1;  // idle
                if (send) begin
                    // Load frame: start bit (0), 8 data bits LSB-first, stop bit (1)
                    shift_reg <= {1'b1, data, 1'b0};
                    clk_cnt   <= 0;
                    bit_cnt   <= 0;
                    busy      <= 1'b1;
                end
            end else begin
                // Drive TX from shift register bit 0
                tx <= shift_reg[0];

                if (clk_cnt == CLKS_PER_BIT - 1) begin
                    clk_cnt   <= 0;
                    shift_reg <= {1'b1, shift_reg[9:1]};  // shift right, fill with 1
                    if (bit_cnt == TOTAL_BITS - 1) begin
                        busy    <= 1'b0;
                        bit_cnt <= 0;
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end
        end
    end

endmodule
