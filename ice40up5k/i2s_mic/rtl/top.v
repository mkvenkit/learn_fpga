// top.v  —  iCE40UP5K I2S Dual-Microphone Capture
//
// Hardware: Lattice iCE40UP5K Breakout EVN board
//           2x Adafruit SPH0645 I2S MEMS microphone breakouts
//
// Operation:
//   Press BTN → green LED on, start streaming 16-bit stereo samples over UART.
//   Press BTN again → green LED off, stop streaming.
//
// I2S clock:  1 MHz SCK, 15625 Hz sample rate (48 MHz HFOSC / 48 / 64)
// UART:       921600 baud, 8N1
//
// Each stereo sample is sent as 4 bytes over UART:
//   Byte 0: left_data[15:8]   (MSB)
//   Byte 1: left_data[7:0]    (LSB)
//   Byte 2: right_data[15:8]  (MSB)
//   Byte 3: right_data[7:0]   (LSB)
//
// Mic wiring:
//   Mic 1 (LEFT)  — SELECT pin tied to GND  → provides data during WS=1
//   Mic 2 (RIGHT) — SELECT pin tied to VDD  → provides data during WS=0
//   Both mics share SCK, WS.  SD lines are separate and OR'd here (each mic
//   is in tri-state during the other channel's slot, so we can wire them
//   together or bring them in separately — we use separate pins for clarity).

module top (
    // UART
    output wire uart_tx,

    // I2S microphone interface
    output wire i2s_sck,    // bit clock  → both mics
    output wire i2s_ws,     // word select → both mics
    input  wire i2s_sd_left,  // serial data ← left  mic (SELECT=GND)
    input  wire i2s_sd_right, // serial data ← right mic (SELECT=VDD)

    // User interface
    input  wire btn,        // push button, active-low (BTN_N on B-EVN)
    output wire led_green,  // green channel of RGB LED
    output wire led_red,    // red channel of RGB LED (idle indicator)
    output wire led_blue    // blue channel (unused, wired low)
);

    // -----------------------------------------------------------------------
    // Internal 48 MHz oscillator (HFOSC)
    // -----------------------------------------------------------------------
    wire clk;
    SB_HFOSC #(.CLKHF_DIV("0b00")) hfosc_inst (
        .CLKHFEN(1'b1),
        .CLKHFPU(1'b1),
        .CLKHF(clk)
    );

    // -----------------------------------------------------------------------
    // Reset generator — hold reset for 256 cycles after power-on
    // -----------------------------------------------------------------------
    reg [7:0] reset_cnt = 0;
    reg resetn = 0;
    always @(posedge clk) begin
        if (!(&reset_cnt)) begin
            reset_cnt <= reset_cnt + 1;
        end else begin
            resetn <= 1'b1;
        end
    end

    // -----------------------------------------------------------------------
    // Button debouncer
    // -----------------------------------------------------------------------
    wire btn_press;
    wire btn_debounced;

    debounce #(
        .STABLE_COUNT(960_000)  // ~20 ms at 48 MHz
    ) deb (
        .clk      (clk),
        .resetn   (resetn),
        .btn_in   (btn),
        .btn_out  (btn_debounced),
        .btn_press(btn_press)
    );

    // -----------------------------------------------------------------------
    // Recording state: toggle on each debounced button press
    // -----------------------------------------------------------------------
    reg recording = 0;
    always @(posedge clk) begin
        if (!resetn) begin
            recording <= 0;
        end else if (btn_press) begin
            recording <= ~recording;
        end
    end

    // -----------------------------------------------------------------------
    // RGB LED driver using SB_RGBA_DRV primitive
    // Green = recording; Red = idle; Blue = off
    // -----------------------------------------------------------------------
    SB_RGBA_DRV #(
        .CURRENT_MODE ("0b1"),      // half-current mode (lower power)
        .RGB0_CURRENT ("0b000001"), // green  ~4 mA
        .RGB1_CURRENT ("0b000001"), // blue   ~4 mA
        .RGB2_CURRENT ("0b000001")  // red    ~4 mA
    ) rgba_drv (
        .RGBLEDEN (1'b1),
        .RGB0PWM  (recording),         // green on when recording
        .RGB1PWM  (1'b0),              // blue  always off
        .RGB2PWM  (~recording),        // red   on when idle
        .CURREN   (1'b1),
        .RGB0     (led_green),
        .RGB1     (led_blue),
        .RGB2     (led_red)
    );

    // -----------------------------------------------------------------------
    // I2S clock generator
    // SCK = 48 MHz / (24*2) = 1 MHz
    // WS  = 1 MHz / 64      = 15625 Hz
    // -----------------------------------------------------------------------
    i2s_clk_gen #(
        .CLK_DIV       (24),
        .BITS_PER_FRAME(32)
    ) clk_gen (
        .clk   (clk),
        .resetn(resetn),
        .sck   (i2s_sck),
        .ws    (i2s_ws)
    );

    // -----------------------------------------------------------------------
    // I2S receiver — left mic
    // -----------------------------------------------------------------------
    wire [15:0] left_data;
    wire [15:0] right_data;
    wire        data_valid;

    // Both mics share SCK and WS.  The SD lines are separate but we use
    // a single i2s_receiver that captures whichever SD line is active
    // per WS phase.  Since only one mic drives SD in any given slot, we
    // OR the two SD lines together (the inactive mic output is high-Z).
    // Alternatively, bring them in on separate lines and mux — done here
    // by feeding SD as the OR of both lines for simplicity.
    //
    // The left  mic (SELECT=GND) drives SD during WS=1 (left  channel).
    // The right mic (SELECT=VDD) drives SD during WS=0 (right channel).
    // Since the inactive mic is in tri-state, OR = whichever is active.

    wire sd_combined = i2s_sd_left | i2s_sd_right;

    i2s_receiver #(
        .DATA_WIDTH    (16),
        .BITS_PER_FRAME(32)
    ) i2s_rx (
        .clk       (clk),
        .resetn    (resetn),
        .sck       (i2s_sck),
        .ws        (i2s_ws),
        .sd        (sd_combined),
        .left_data (left_data),
        .right_data(right_data),
        .data_valid(data_valid)
    );

    // -----------------------------------------------------------------------
    // UART transmitter
    // -----------------------------------------------------------------------
    wire uart_busy;
    reg  [7:0] uart_data;
    reg        uart_send;

    uart_tx #(
        .CLK_FREQ (48_000_000),
        .BAUD_RATE(921_600)
    ) utx (
        .clk   (clk),
        .resetn(resetn),
        .data  (uart_data),
        .send  (uart_send),
        .tx    (uart_tx),
        .busy  (uart_busy)
    );

    // -----------------------------------------------------------------------
    // UART byte sequencer
    // Sends 4 bytes per stereo sample in order:
    //   [left_MSB] [left_LSB] [right_MSB] [right_LSB]
    // -----------------------------------------------------------------------
    reg [15:0] left_latch;
    reg [15:0] right_latch;
    reg [1:0]  tx_byte_idx;  // 0..3
    reg        tx_pending;

    always @(posedge clk) begin
        if (!resetn) begin
            left_latch  <= 0;
            right_latch <= 0;
            tx_byte_idx <= 0;
            tx_pending  <= 0;
            uart_send   <= 0;
            uart_data   <= 0;
        end else begin
            uart_send <= 0;  // default: no new byte

            // Latch new sample when available and recording is active
            if (data_valid && recording) begin
                left_latch  <= left_data;
                right_latch <= right_data;
                tx_pending  <= 1;
                tx_byte_idx <= 0;
            end

            // Send bytes one at a time
            if (tx_pending && !uart_busy && !uart_send) begin
                case (tx_byte_idx)
                    2'd0: uart_data <= left_latch[15:8];
                    2'd1: uart_data <= left_latch[7:0];
                    2'd2: uart_data <= right_latch[15:8];
                    2'd3: uart_data <= right_latch[7:0];
                endcase
                uart_send   <= 1;
                tx_byte_idx <= tx_byte_idx + 1;
                if (tx_byte_idx == 2'd3) begin
                    tx_pending <= 0;
                end
            end
        end
    end

endmodule
