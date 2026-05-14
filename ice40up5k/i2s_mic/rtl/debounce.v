// debounce.v
// Simple counter-based button debouncer.
//
// Waits for the input to be stable for STABLE_COUNT clock cycles
// before updating the output. For a 48 MHz clock and a 20 ms debounce
// window: STABLE_COUNT = 48_000_000 * 0.020 = 960_000.
//
// btn_out is the debounced level.
// btn_press pulses high for one clock on a debounced falling edge
// (button pressed, active-low input).

module debounce #(
    parameter STABLE_COUNT = 960_000   // ~20 ms at 48 MHz
)(
    input  wire clk,
    input  wire resetn,
    input  wire btn_in,    // raw button input (active low)
    output reg  btn_out,   // debounced button level
    output reg  btn_press  // one-clock pulse on debounced press (falling edge)
);

    reg [$clog2(STABLE_COUNT)-1:0] cnt;
    reg btn_sync0, btn_sync1;  // two-stage synchroniser for metastability
    reg btn_prev;

    always @(posedge clk) begin
        if (!resetn) begin
            btn_sync0 <= 1'b1;
            btn_sync1 <= 1'b1;
            cnt       <= 0;
            btn_out   <= 1'b1;
            btn_press <= 1'b0;
            btn_prev  <= 1'b1;
        end else begin
            // Synchronise input to clock domain
            btn_sync0 <= btn_in;
            btn_sync1 <= btn_sync0;

            btn_press <= 1'b0;  // default

            if (btn_sync1 != btn_out) begin
                // Input has changed; start (or continue) counting
                cnt <= cnt + 1;
                if (cnt == STABLE_COUNT - 1) begin
                    btn_out <= btn_sync1;
                    cnt     <= 0;
                    // Detect press (falling edge on active-low button)
                    if (btn_sync1 == 1'b0 && btn_out == 1'b1) begin
                        btn_press <= 1'b1;
                    end
                end
            end else begin
                cnt <= 0;  // input stable, reset counter
            end
        end
    end

endmodule
