// i2s_clk_gen.v
// Generates I2S bit clock (SCK) and word select (WS) from system clock.
//
// System clock:  CLK_FREQ Hz (default 48 MHz from iCE40UP5K HFOSC)
// SCK frequency: CLK_FREQ / (CLK_DIV * 2)
//   with CLK_DIV=24 → SCK = 48 MHz / 48 = 1 MHz
// WS frequency:  SCK / (BITS_PER_FRAME * 2)
//   with BITS_PER_FRAME=32 → WS = 1 MHz / 64 = 15625 Hz (sample rate)
//
// WS = 0 → Right channel data period
// WS = 1 → Left  channel data period
// (matches Philips I2S spec with WS low = right, WS high = left)

module i2s_clk_gen #(
    parameter CLK_DIV       = 24,   // divider for half-period of SCK
    parameter BITS_PER_FRAME = 32   // number of SCK cycles per WS half-period
)(
    input  wire clk,        // system clock (48 MHz)
    input  wire resetn,     // active-low reset
    output reg  sck,        // I2S bit clock output to mic
    output reg  ws          // I2S word select output to mic
);

    // Counter for SCK half-period
    reg [$clog2(CLK_DIV)-1:0] clk_cnt;

    // Counter for bits within a WS period (one half = BITS_PER_FRAME bits)
    reg [$clog2(BITS_PER_FRAME)-1:0] bit_cnt;

    always @(posedge clk) begin
        if (!resetn) begin
            clk_cnt <= 0;
            bit_cnt <= 0;
            sck     <= 0;
            ws      <= 0;
        end else begin
            if (clk_cnt == CLK_DIV - 1) begin
                clk_cnt <= 0;
                sck     <= ~sck;

                // On rising edge of SCK, increment bit counter
                // sck was 0, about to go 1 → rising edge
                if (!sck) begin
                    if (bit_cnt == BITS_PER_FRAME - 1) begin
                        bit_cnt <= 0;
                        ws      <= ~ws;
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end
    end

endmodule
