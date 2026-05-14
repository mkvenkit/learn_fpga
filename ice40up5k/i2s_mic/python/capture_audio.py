#!/usr/bin/env python3
"""
capture_audio.py
----------------
Reads raw 16-bit stereo I2S audio samples from the iCE40UP5K FPGA over UART
and saves them as a standard WAV file.

Protocol (matches top.v):
  Each stereo sample = 4 bytes in this order:
    Byte 0: left[15:8]   MSB of left  channel
    Byte 1: left[7:0]    LSB of left  channel
    Byte 2: right[15:8]  MSB of right channel
    Byte 3: right[7:0]   LSB of right channel

  Baud rate:  921600
  Sample rate: 15625 Hz  (48 MHz / 48 / 64)
  Bit depth:  16-bit signed, big-endian from FPGA (converted to little-endian for WAV)

Usage:
  python3 capture_audio.py --port /dev/ttyUSB0 --duration 5 --out recording.wav
  python3 capture_audio.py --port /dev/cu.usbserial-XXX --duration 10 --out out.wav

Press Ctrl+C to stop early — the WAV file is still saved.

Requirements:
  pip install pyserial
"""

import argparse
import struct
import sys
import time
import wave
from pathlib import Path

try:
    import serial
except ImportError:
    print("ERROR: pyserial not found.  Install with:  pip install pyserial")
    sys.exit(1)


# ── Constants ──────────────────────────────────────────────────────────────────

BAUD_RATE   = 921_600
SAMPLE_RATE = 15_625   # Hz — must match FPGA design
CHANNELS    = 2
SAMPLE_WIDTH = 2       # bytes per sample per channel (16-bit)
BYTES_PER_FRAME = CHANNELS * SAMPLE_WIDTH  # 4 bytes per stereo sample


# ── Helpers ────────────────────────────────────────────────────────────────────

def bytes_to_signed16(msb: int, lsb: int) -> int:
    """Convert two bytes (big-endian from FPGA) to a signed 16-bit integer."""
    value = (msb << 8) | lsb
    if value >= 0x8000:
        value -= 0x10000
    return value


def capture(port: str, duration_s: float, out_path: Path) -> None:
    """Open serial port, receive audio frames, write WAV file."""

    print(f"Opening {port} at {BAUD_RATE} baud …")
    try:
        ser = serial.Serial(port, baudrate=BAUD_RATE, timeout=1.0)
    except serial.SerialException as exc:
        print(f"ERROR: Cannot open serial port: {exc}")
        sys.exit(1)

    total_frames   = int(SAMPLE_RATE * duration_s)
    pcm_left  = []
    pcm_right = []
    buf = bytearray()

    print(f"Recording {duration_s:.1f}s — {total_frames} samples expected.")
    print("Press the FPGA button to start transmitting, then Ctrl+C to stop early.\n")

    start_time = time.monotonic()
    try:
        while len(pcm_left) < total_frames:
            chunk = ser.read(256)
            if not chunk:
                continue
            buf.extend(chunk)

            # Parse complete 4-byte frames from buffer
            while len(buf) >= BYTES_PER_FRAME:
                frame = buf[:BYTES_PER_FRAME]
                buf   = buf[BYTES_PER_FRAME:]

                left_sample  = bytes_to_signed16(frame[0], frame[1])
                right_sample = bytes_to_signed16(frame[2], frame[3])

                pcm_left.append(left_sample)
                pcm_right.append(right_sample)

            elapsed = time.monotonic() - start_time
            captured = len(pcm_left)
            pct = 100.0 * captured / total_frames
            print(f"\r  {captured:6d}/{total_frames} samples  ({pct:5.1f}%)  "
                  f"{elapsed:5.1f}s elapsed", end="", flush=True)

    except KeyboardInterrupt:
        print("\nStopped early by user.")

    finally:
        ser.close()

    print(f"\nCaptured {len(pcm_left)} stereo samples.")

    if not pcm_left:
        print("No data received — check that the FPGA is transmitting.")
        return

    # ── Write WAV file ────────────────────────────────────────────────────────
    # WAV expects interleaved samples: L0 R0 L1 R1 …
    # Each sample is signed 16-bit little-endian.
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out_path), "wb") as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(SAMPLE_WIDTH)
        wf.setframerate(SAMPLE_RATE)

        # Pack all frames
        frame_bytes = bytearray()
        for l, r in zip(pcm_left, pcm_right):
            frame_bytes += struct.pack("<hh", l, r)  # little-endian signed shorts

        wf.writeframes(bytes(frame_bytes))

    size_kb = out_path.stat().st_size / 1024
    print(f"Saved: {out_path}  ({size_kb:.1f} KB)")
    print(f"  Sample rate : {SAMPLE_RATE} Hz")
    print(f"  Channels    : {CHANNELS} (stereo)")
    print(f"  Bit depth   : 16-bit signed")
    print(f"  Duration    : {len(pcm_left)/SAMPLE_RATE:.2f}s")


# ── Entry point ────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Capture I2S audio from iCE40UP5K FPGA and save as WAV."
    )
    parser.add_argument(
        "--port", "-p",
        required=True,
        help="Serial port, e.g. /dev/ttyUSB0 or /dev/cu.usbserial-XXXX"
    )
    parser.add_argument(
        "--duration", "-d",
        type=float,
        default=5.0,
        help="Recording duration in seconds (default: 5)"
    )
    parser.add_argument(
        "--out", "-o",
        default="recording.wav",
        help="Output WAV file path (default: recording.wav)"
    )
    args = parser.parse_args()

    capture(
        port      = args.port,
        duration_s= args.duration,
        out_path  = Path(args.out)
    )


if __name__ == "__main__":
    main()
