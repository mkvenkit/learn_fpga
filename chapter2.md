# Chapter 2: Edge Detection and Clock Strobes in Verilog

## Introduction

One of the most common and useful building blocks in digital design is the **edge detector** — a circuit that produces a single-cycle pulse ("strobe") whenever a signal transitions from low to high (rising edge) or high to low (falling edge). Despite its simplicity, this pattern appears everywhere: debouncing buttons, synchronising signals between clock domains, and driving baud rate generators in UART and bit-clock dividers in I2S.

In this chapter we build an edge detector from scratch, understand exactly why it works, and then show how the one-cycle strobe it produces becomes the heartbeat of several common serial protocols.

---

## How an Edge Detector Works

The idea is straightforward: compare the current value of a signal against a one-clock-cycle-delayed copy of itself.

```
current value  ─────┐
                    ├──► logic ──► pulse
delayed value  ─────┘
```

| `sig` (current) | `sig_d` (delayed) | Rising edge? | Falling edge? |
|:-:|:-:|:-:|:-:|
| 0 | 0 | no | no |
| 1 | 0 | **yes** | no |
| 0 | 1 | no | **yes** |
| 1 | 1 | no | no |

From this table:

```
rising_edge  = sig & ~sig_d
falling_edge = ~sig & sig_d
any_edge     = sig ^ sig_d     // XOR
```

The delay is produced by a single D flip-flop clocked by the system clock, so the pulse lasts exactly **one clock cycle** regardless of how slowly the input signal changes.

---

## Timing Diagram

The SVG below shows `sig`, its delayed copy `sig_d`, and the resulting `rising_pulse` and `falling_pulse` strobes.

<figure>

<svg viewBox="0 0 720 260" xmlns="http://www.w3.org/2000/svg" font-family="monospace" font-size="13">

  <!-- Background -->
  <rect width="720" height="260" fill="#1e1e2e" rx="8"/>

  <!-- Clock ticks (light vertical lines) -->
  <g stroke="#3a3a5c" stroke-width="1">
    <line x1="100" y1="10" x2="100" y2="250"/>
    <line x1="160" y1="10" x2="160" y2="250"/>
    <line x1="220" y1="10" x2="220" y2="250"/>
    <line x1="280" y1="10" x2="280" y2="250"/>
    <line x1="340" y1="10" x2="340" y2="250"/>
    <line x1="400" y1="10" x2="400" y2="250"/>
    <line x1="460" y1="10" x2="460" y2="250"/>
    <line x1="520" y1="10" x2="520" y2="250"/>
    <line x1="580" y1="10" x2="580" y2="250"/>
    <line x1="640" y1="10" x2="640" y2="250"/>
    <line x1="700" y1="10" x2="700" y2="250"/>
  </g>

  <!-- Labels -->
  <g fill="#a6adc8" font-size="12">
    <text x="8"  y="40"  >clk</text>
    <text x="8"  y="95"  >sig</text>
    <text x="8"  y="150" >sig_d</text>
    <text x="8"  y="195" >rising</text>
    <text x="8"  y="207" >pulse</text>
    <text x="8"  y="245" >falling</text>
    <text x="8"  y="257" >pulse</text>
  </g>

  <!-- CLK waveform -->
  <polyline fill="none" stroke="#89b4fa" stroke-width="2"
    points="
      100,50 100,25 130,25 130,50 160,50
      160,25 190,25 190,50 220,50
      220,25 250,25 250,50 280,50
      280,25 310,25 310,50 340,50
      340,25 370,25 370,50 400,50
      400,25 430,25 430,50 460,50
      460,25 490,25 490,50 520,50
      520,25 550,25 550,50 580,50
      580,25 610,25 610,50 640,50
      640,25 670,25 670,50 700,50
    "/>

  <!-- SIG waveform: low until t=220, high 220-460, low 460-580, high 580+ -->
  <polyline fill="none" stroke="#a6e3a1" stroke-width="2"
    points="
      100,105 220,105 220,80 460,80 460,105 580,105 580,80 700,80
    "/>

  <!-- SIG_D waveform: delayed one cycle -->
  <polyline fill="none" stroke="#fab387" stroke-width="2"
    points="
      100,160 280,160 280,135 520,135 520,160 640,160 640,135 700,135
    "/>

  <!-- RISING PULSE: one cycle at t=220..280 and t=580..640 -->
  <polyline fill="none" stroke="#f38ba8" stroke-width="2.5"
    points="100,210 220,210 220,185 280,185 280,210 580,210 580,185 640,185 640,210 700,210"/>

  <!-- FALLING PULSE: one cycle at t=460..520 -->
  <polyline fill="none" stroke="#cba6f7" stroke-width="2.5"
    points="100,255 460,255 460,230 520,230 520,255 700,255"/>

  <!-- Cycle number labels at bottom -->
  <g fill="#585b70" font-size="10" text-anchor="middle">
    <text x="130" y="15">1</text>
    <text x="190" y="15">2</text>
    <text x="250" y="15">3</text>
    <text x="310" y="15">4</text>
    <text x="370" y="15">5</text>
    <text x="430" y="15">6</text>
    <text x="490" y="15">7</text>
    <text x="550" y="15">8</text>
    <text x="610" y="15">9</text>
    <text x="670" y="15">10</text>
  </g>

</svg>

*Figure 1: Rising and falling edge detector timing. The pulse lasts exactly one clock cycle.*

</figure>

Notice that `rising_pulse` fires one cycle after `sig` goes high, and `falling_pulse` fires one cycle after `sig` goes low. That single-cycle delay is the flip-flop doing its job.

---

## Verilog Implementation

### Basic Module

```verilog
// edge_detector.v
// Detects rising and/or falling edges of an input signal.
// Outputs a one-cycle strobe for each edge type.

module edge_detector (
    input  wire clk,
    input  wire rst_n,      // active-low synchronous reset
    input  wire sig,        // signal to monitor

    output wire rising_edge,
    output wire falling_edge,
    output wire any_edge
);

    reg sig_d;  // one-cycle delayed copy of sig

    // Register: delay sig by one clock
    always @(posedge clk) begin
        if (!rst_n)
            sig_d <= 1'b0;
        else
            sig_d <= sig;
    end

    // Combinational edge detection
    assign rising_edge  =  sig & ~sig_d;
    assign falling_edge = ~sig &  sig_d;
    assign any_edge     =  sig ^  sig_d;

endmodule
```

That is the complete core — one flip-flop and three logic gates.

### Parameterised Version (multi-bit bus)

Sometimes you need to watch several signals simultaneously. A parameterised version handles an N-bit bus with the same logic:

```verilog
module edge_detector_n #(
    parameter WIDTH = 8
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] sig,

    output wire [WIDTH-1:0] rising_edge,
    output wire [WIDTH-1:0] falling_edge,
    output wire [WIDTH-1:0] any_edge
);

    reg [WIDTH-1:0] sig_d;

    always @(posedge clk) begin
        if (!rst_n)
            sig_d <= {WIDTH{1'b0}};
        else
            sig_d <= sig;
    end

    assign rising_edge  =  sig & ~sig_d;
    assign falling_edge = ~sig &  sig_d;
    assign any_edge     =  sig ^  sig_d;

endmodule
```

---

## Example: Button Debounce + Edge Detect

Raw button inputs bounce — they toggle rapidly for a few milliseconds before settling. A common FPGA pattern chains a debounce filter with an edge detector so downstream logic sees exactly one clean strobe per button press.

```verilog
module button_press (
    input  wire clk,        // e.g. 12 MHz
    input  wire rst_n,
    input  wire btn_raw,    // raw, bouncy button (active-low)
    output wire btn_press   // one-cycle strobe per press
);

    // --- Stage 1: synchronise to clock domain ---
    reg btn_sync0, btn_sync1;
    always @(posedge clk) begin
        btn_sync0 <= ~btn_raw;   // invert active-low
        btn_sync1 <= btn_sync0;
    end

    // --- Stage 2: debounce counter (16 ms at 12 MHz = 192000 cycles) ---
    localparam DEBOUNCE_CYCLES = 192_000;
    reg [$clog2(DEBOUNCE_CYCLES)-1:0] cnt;
    reg btn_stable;

    always @(posedge clk) begin
        if (!rst_n) begin
            cnt        <= 0;
            btn_stable <= 0;
        end else if (btn_sync1 != btn_stable) begin
            if (cnt == DEBOUNCE_CYCLES - 1) begin
                btn_stable <= btn_sync1;
                cnt        <= 0;
            end else begin
                cnt <= cnt + 1;
            end
        end else begin
            cnt <= 0;
        end
    end

    // --- Stage 3: edge detector ---
    reg btn_d;
    always @(posedge clk)
        btn_d <= btn_stable;

    assign btn_press = btn_stable & ~btn_d;  // rising edge strobe

endmodule
```

The final `btn_press` signal is a clean, single-cycle pulse that you can use to trigger counters, state machines, or any event-driven logic.

---

## The Strobe Pattern in Serial Protocols

The one-cycle strobe produced by an edge detector is more than just a curiosity — it is the **fundamental timing primitive** behind baud-rate and bit-clock generation in virtually every serial protocol. The idea in each case is the same:

> Run a free-running counter from a fast system clock. Use an edge detector (or a comparator that acts like one) to fire a strobe every N cycles. Everything downstream ticks on that strobe, not on the raw system clock.

This keeps all logic in a single clock domain while allowing arbitrarily slow "derived" rates.

### UART Baud Rate Generator

A UART transmitter and receiver need a tick at 16× the baud rate (for oversampling) or exactly 1× for direct-rate sampling. The generator counts to `(f_clk / baud_rate) - 1` and fires a one-cycle strobe at the terminal count:

```verilog
module baud_gen #(
    parameter CLK_HZ  = 12_000_000,
    parameter BAUD    = 115_200,
    // 16x oversampling tick
    parameter DIVISOR = CLK_HZ / (BAUD * 16)
)(
    input  wire clk,
    input  wire rst_n,
    output reg  baud_tick   // one-cycle strobe at 16x baud rate
);

    localparam CNT_BITS = $clog2(DIVISOR);
    reg [CNT_BITS-1:0] cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            cnt       <= 0;
            baud_tick <= 0;
        end else begin
            if (cnt == DIVISOR - 1) begin
                cnt       <= 0;
                baud_tick <= 1;   // strobe: one cycle wide
            end else begin
                cnt       <= cnt + 1;
                baud_tick <= 0;
            end
        end
    end

endmodule
```

The UART TX state machine then steps through its start-bit / data-bits / stop-bit sequence only when `baud_tick` is high — every other cycle it simply holds state. This is exactly the edge-detector strobe pattern: a narrow pulse that advances a larger state machine.

### I2S Bit Clock (SCK) and Word Select (WS)

In I2S audio, the bit clock SCK and the word-select signal WS are both derived from a master clock by dividing it down with counters. An edge detector on SCK produces a strobe on every rising (or falling) SCK edge, which the data-capture state machine uses to shift in one audio bit at a time:

```verilog
// Inside an I2S receiver ---
// sck_i is the incoming bit clock from the microphone.
// Detect its rising edge relative to our system clock.

reg sck_d0, sck_d1;
always @(posedge sys_clk) begin
    sck_d0 <= sck_i;
    sck_d1 <= sck_d0;
end

wire sck_rising = sck_d0 & ~sck_d1;  // strobe on SCK rising edge

// Shift register advances only on sck_rising
always @(posedge sys_clk) begin
    if (sck_rising)
        shift_reg <= {shift_reg[14:0], sd_i};
end
```

Note the **two-stage synchroniser** (`sck_d0`, `sck_d1`) before the edge detect — this is mandatory when `sck_i` is asynchronous to `sys_clk` to avoid metastability.

### SPI Clock Phase Detection

SPI has four modes (CPOL/CPHA) that determine whether data is sampled on a rising or falling edge of SCLK. An edge detector on SCLK lets you select the capture edge at the top level with a simple mux:

```verilog
wire sclk_rise = sclk_d0 & ~sclk_d1;
wire sclk_fall = ~sclk_d0 & sclk_d1;

wire sample_tick = (CPHA == 0) ? sclk_rise : sclk_fall;

always @(posedge clk)
    if (sample_tick)
        rx_reg <= {rx_reg[DATA_BITS-2:0], miso};
```

### Other Uses

The same strobe pattern appears in:

- **PWM period detection** — detecting the rising edge of a sync input to reset a PWM counter.
- **Quadrature encoder decoding** — detecting edges on both A and B channels to compute direction and position.
- **I²C clock stretching detection** — detecting when a slave holds SCL low to pause the master.
- **Handshake protocols** — detecting the rising edge of a `valid` or `req` signal to trigger a response.

Whenever you see a piece of Verilog with a counter and the phrase "advance state machine on tick," there is almost certainly an edge-detector strobe somewhere nearby.

---

## Common Pitfalls

**Asynchronous inputs.** If the signal being monitored comes from outside the FPGA (a button, an external clock, another chip), always pass it through a two-stage synchroniser before the edge detector. Skipping this risks metastability — the flip-flop output can oscillate for an indeterminate time, corrupting all downstream logic.

```verilog
// Two-stage synchroniser
reg sig_sync0, sig_sync1;
always @(posedge clk) begin
    sig_sync0 <= sig_async;
    sig_sync1 <= sig_sync0;
end
// Now use sig_sync1 as the input to your edge detector
```

**Reset state.** If `sig` is high at reset and you initialise `sig_d` to 0, the edge detector will fire a spurious rising-edge strobe on the first clock cycle after reset. Initialise `sig_d` to match the known reset state of `sig`, or mask the output for a cycle or two after reset.

**Glitches on combinational inputs.** If `sig` is the output of combinational logic (not a registered signal), it may glitch as multiple inputs change. Register `sig` before the edge detector or ensure the signal is glitch-free at the point of sampling.

---

## Summary

| What you want | How |
|---|---|
| Rising-edge strobe | `sig & ~sig_d` |
| Falling-edge strobe | `~sig & sig_d` |
| Either-edge strobe | `sig ^ sig_d` |
| Safe async input | Two-stage sync first, then edge detect |
| Derived baud / bit rate | Counter terminal-count strobe → drives state machine |

An edge detector is small, deterministic, and composable. Once you internalise the "delay-and-compare" pattern you will recognise it everywhere in FPGA design — and reach for it naturally whenever you need to react to a signal transition.
