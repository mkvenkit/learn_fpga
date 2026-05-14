# i2s_mic — Stereo I2S Microphone Capture on iCE40UP5K

Records stereo audio from two Adafruit SPH0645 I2S MEMS microphones using the Lattice iCE40UP5K B-EVN board, streams 16-bit samples over UART, and saves them as a WAV file on your laptop.

Press the on-board button → green LED on, FPGA starts transmitting.  
Press again → red LED on, transmission stops.

**Sample rate:** 15625 Hz | **Bit depth:** 16-bit | **Baud rate:** 921600

---

## Project Structure

```
i2s_mic/
├── rtl/
│   ├── top.v             top-level module
│   ├── i2s_clk_gen.v     generates SCK (1 MHz) and WS (15625 Hz)
│   ├── i2s_receiver.v    shifts serial I2S data into 16-bit stereo samples
│   ├── uart_tx.v         8N1 UART transmitter at 921600 baud
│   └── debounce.v        20 ms counter-based button debouncer
├── tb/
│   └── tb_i2s_receiver.v testbench for i2s_clk_gen + i2s_receiver
├── python/
│   └── capture_audio.py  reads UART stream, writes stereo WAV file
├── constraints/
│   └── pins.pcf          FPGA pin assignments
└── Makefile
```

---

## Hookup Guide

### What you need

- Lattice iCE40UP5K Breakout EVN (B-EVN) board
- 2× Adafruit SPH0645LM4H I2S MEMS Microphone breakout (#3421)
- Jumper wires and a small breadboard

### I2S Microphone Wiring

Both mics share the SCK and WS clock lines. Only the DATA and SELECT pins differ.

| SPH0645 Pin | Left Mic → FPGA | Right Mic → FPGA |
|-------------|-----------------|------------------|
| 3V          | 3V3             | 3V3              |
| GND         | GND             | GND              |
| BCLK        | pin 19 (i2s_sck) | pin 19 (i2s_sck) |
| LRCLK       | pin 18 (i2s_ws)  | pin 18 (i2s_ws)  |
| DATA        | pin 20 (i2s_sd_left) | pin 21 (i2s_sd_right) |
| SELECT      | **GND** (= left channel)  | **3V3** (= right channel) |

> **Pin labels on the B-EVN board:** pins 18–21 correspond to header labels 25B, 26B, 27B, 28B. Cross-check against the board schematic before wiring.

### External Button

The B-EVN has no user GPIO button (SW1 is reset-only, SW2 is a programming switch). Wire a momentary push button between **Header C pin 23B** (FPGA pin 23) and **GND**. No pull-up resistor is needed — the PCF file enables the iCE40's internal pull-up with `-pullup yes`.

```
FPGA pin 23 (23B) ──┤button├── GND
```

### RGB LED

Built into the B-EVN board, driven by the `SB_RGBA_DRV` primitive — no external resistors required.

### UART

The FTDI chip on the B-EVN board bridges the FPGA's UART TX (pin 14) to USB. Use the same USB cable you use to program the board.

---

## Build and Program

```bash
# Synthesise, place-and-route, pack
make

# Upload to FPGA
make prog
```

---

## Simulate

```bash
make sim        # runs testbench, prints PASS/FAIL per sample
make sim-wave   # also opens GTKWave
```

---

## Capture Audio

Install the one required Python package:

```bash
pip install pyserial
```

Find your serial port (`/dev/ttyUSB0` on Linux, `/dev/cu.usbserial-XXXX` on macOS), then:

```bash
python3 python/capture_audio.py --port /dev/ttyUSB0 --duration 10 --out recording.wav
```

Press the FPGA button to start recording. The script shows a live progress bar and writes the WAV file when done. Press the button again (or Ctrl+C) to stop early.

---

## Further Reading

See `article.md` for a full write-up covering the I2S protocol, Verilog implementation details, and simulation results.
