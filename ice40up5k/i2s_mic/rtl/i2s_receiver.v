// i2s_receiver.v
// Receives I2S audio data from a microphone.
//
// Protocol (Philips I2S):
//   - Data is MSB-first, presented on the falling edge of SCK
//   - Data should be sampled on the rising edge of SCK
//   - The MSB is presented one SCK cycle AFTER the WS transition
//   - WS = 0 → right channel; WS = 1 → left channel
//
// For the Adafruit SPH0645 I2S MEMS mic (18-bit output):
//   - We capture only the top 16 bits of each 18-bit word
//   - The SELECT pin on each mic sets its channel:
//       SELECT = GND → left  channel (data valid during WS = 1)
//       SELECT = VDD → right channel (data valid during WS = 0)
//
// This module is clocked by the system clock (48 MHz).
// SCK and WS are OUTPUTS driven by i2s_clk_gen and connected back in here
// as inputs so we can sample SD synchronously.

module i2s_receiver #(
    parameter DATA_WIDTH     = 16,  // bits to capture per channel
    parameter BITS_PER_FRAME = 32   // total SCK cycles per WS half-period
)(
    input  wire clk,            // system clock (48 MHz)
    input  wire resetn,         // active-low reset
    input  wire sck,            // I2S bit clock (from i2s_clk_gen)
    input  wire ws,             // I2S word select (from i2s_clk_gen)
    input  wire sd,             // I2S serial data from mic

    output reg [DATA_WIDTH-1:0] left_data,   // captured left  channel sample
    output reg [DATA_WIDTH-1:0] right_data,  // captured right channel sample
    output reg                  data_valid   // pulses high for 1 clk when new sample ready
);

    // Edge detection registers
    reg sck_prev;
    reg ws_prev;

    wire sck_rise = ( sck && !sck_prev);  // SCK rising edge
    wire ws_edge  = (ws  != ws_prev);     // WS changed

    // Shift register and bit counter
    reg [DATA_WIDTH-1:0] shift_reg;
    reg [$clog2(BITS_PER_FRAME+1)-1:0] bit_cnt;  // counts rising SCK edges since WS edge
    reg ws_latch;   // latched WS at start of frame

    always @(posedge clk) begin
        if (!resetn) begin
            sck_prev   <= 0;
            ws_prev    <= 0;
            shift_reg  <= 0;
            bit_cnt    <= 0;
            ws_latch   <= 0;
            left_data  <= 0;
            right_data <= 0;
            data_valid <= 0;
        end else begin
            // Update edge-detect registers every clock
            sck_prev <= sck;
            ws_prev  <= ws;

            // Default: data_valid is a one-cycle pulse
            data_valid <= 0;

            // On SCK rising edge: sample serial data
            if (sck_rise) begin
                // bit_cnt == 0 is the "one SCK delay" slot (per I2S spec)
                // We shift in data starting from bit_cnt == 1
                // We capture DATA_WIDTH bits: bit_cnt 1 .. DATA_WIDTH
                if (bit_cnt >= 1 && bit_cnt <= DATA_WIDTH) begin
                    // Shift in MSB first
                    shift_reg <= {shift_reg[DATA_WIDTH-2:0], sd};
                end

                // When we have captured DATA_WIDTH bits, latch them
                if (bit_cnt == DATA_WIDTH) begin
                    if (ws_latch == 1'b1) begin
                        left_data  <= {shift_reg[DATA_WIDTH-2:0], sd};
                    end else begin
                        right_data <= {shift_reg[DATA_WIDTH-2:0], sd};
                    end
                end

                // Count bits; WS edge resets the counter
                if (ws_edge) begin
                    bit_cnt  <= 1;      // this rising edge is bit 1 (after the delay)
                    ws_latch <= ws;     // remember which channel we are capturing
                    // Latch the completed sample pair when we start a new right-channel frame
                    // (right channel comes first per standard timing)
                    if (ws == 1'b1) begin
                        // Just finished right channel, starting left channel
                        // right_data already latched above at bit_cnt==DATA_WIDTH
                        // We emit data_valid at the start of the NEXT right-channel frame
                        // (handled below in the ws_edge block)
                    end
                end else begin
                    bit_cnt <= bit_cnt + 1;
                end
            end

            // Signal data_valid when a complete stereo pair is available.
            // WS goes from 1→0 means: left channel finished, right channel starting.
            // At that moment both left_data and right_data hold fresh values.
            if (ws_edge && ws_prev == 1'b1 && ws == 1'b0) begin
                data_valid <= 1;
            end
        end
    end

endmodule
