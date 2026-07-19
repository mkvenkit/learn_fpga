"""
pdm_sigma_delta.py
==================
Understand how a sine wave becomes a PDM (1-bit) stream,
and how to recover audio back from it using a simple FIR filter.

Sections:
  1. Sigma-delta modulator: sine → bitstream
  2. Visualise the bitstream vs input
  3. Decimate with a simple box FIR (moving average)
  4. Show frequency spectrum: input vs recovered audio

Run:
  pip install numpy matplotlib
  python pdm_sigma_delta.py
"""

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec

# ─────────────────────────────────────────────
# Parameters
# ─────────────────────────────────────────────
PDM_RATE   = 3_072_000   # PDM clock rate  (Hz)
AUDIO_RATE =    48_000   # target audio rate (Hz)
DECIMATE   = PDM_RATE // AUDIO_RATE   # = 64
DURATION   = 0.002       # seconds to simulate (2 ms → 6144 PDM samples)
FREQ       = 1_000       # sine wave frequency (Hz)

N = int(PDM_RATE * DURATION)   # total PDM samples
t = np.arange(N) / PDM_RATE    # time axis (seconds)

print(f"PDM rate      : {PDM_RATE:,} Hz")
print(f"Audio rate    : {AUDIO_RATE:,} Hz")
print(f"Decimation    : {DECIMATE}×")
print(f"Samples       : {N:,} PDM → {N // DECIMATE:,} audio")

# ─────────────────────────────────────────────
# 1. Sigma-Delta Modulator
#    Each step:
#      error      = input_sample - feedback
#      integrator += error
#      bit         = 1 if integrator >= 0 else 0
#      feedback    = +1 if bit == 1 else -1
# ─────────────────────────────────────────────
sine_in    = np.sin(2 * np.pi * FREQ * t)   # normalised to [-1, +1]

integrator = 0.0
feedback   = 1.0
bits       = np.zeros(N, dtype=np.int8)
intg_trace = np.zeros(N)                     # save integrator for plotting

for i in range(N):
    error       = sine_in[i] - feedback
    integrator += error
    bit         = 1 if integrator >= 0 else 0
    feedback    = 1.0 if bit else -1.0
    bits[i]     = bit
    intg_trace[i] = integrator

print(f"\nBit density (mean of bits): {bits.mean():.4f}  "
      f"(sine mean is {sine_in.mean():.4f} — should be close to 0)")

# ─────────────────────────────────────────────
# 2. Recover audio: decimate with box FIR
#    Box filter = moving average over R=64 bits.
#    This is the simplest possible CIC (1 stage).
#    Output = sum of 64 bits, then keep every 64th value.
#
#    A real system would use a 5-stage CIC then a
#    compensation FIR, but the box filter is enough
#    to see the sine come back.
# ─────────────────────────────────────────────
R = DECIMATE   # 64

# np.convolve with a box kernel, then downsample
box_kernel   = np.ones(R) / R              # length-64, uniform weights
filtered     = np.convolve(bits.astype(float), box_kernel, mode='same')
audio_out    = filtered[::R]               # keep every R-th sample
t_audio      = np.arange(len(audio_out)) / AUDIO_RATE

# Scale: bits are 0/1 so mean is 0.5, integrator midpoint is 0.
# The output swings around 0.5; centre and rescale to [-1, +1].
audio_out = (audio_out - 0.5) * 2.0

# ─────────────────────────────────────────────
# 3. Plot everything
# ─────────────────────────────────────────────
SHOW = 256   # how many PDM samples to display in the bit plots

fig = plt.figure(figsize=(13, 9))
fig.suptitle("Sigma-Delta Modulation: Sine → PDM → Recovered Audio",
             fontsize=13, fontweight='bold')

gs = gridspec.GridSpec(4, 2, figure=fig, hspace=0.55, wspace=0.35)

# ── Panel A: input sine (first SHOW samples) ──
ax0 = fig.add_subplot(gs[0, :])
ax0.plot(t[:SHOW] * 1e6, sine_in[:SHOW], color='#2563eb', lw=1.5, label='Sine input x[n]')
ax0.axhline(0, color='#d1d5db', lw=0.8, ls='--')
ax0.set_title('① Input sine wave', loc='left', fontsize=10, fontweight='bold')
ax0.set_ylabel('Amplitude')
ax0.set_xlabel('Time (µs)')
ax0.set_ylim(-1.3, 1.3)
ax0.legend(fontsize=9)
ax0.grid(True, alpha=0.3)

# ── Panel B: integrator trace ──
ax1 = fig.add_subplot(gs[1, 0])
ax1.plot(t[:SHOW] * 1e6, intg_trace[:SHOW], color='#f59e0b', lw=1.2)
ax1.axhline(0, color='#16a34a', lw=1, ls='--', label='threshold = 0')
ax1.set_title('② Integrator output\n(hunts around zero)', loc='left', fontsize=10, fontweight='bold')
ax1.set_ylabel('Value')
ax1.set_xlabel('Time (µs)')
ax1.legend(fontsize=9)
ax1.grid(True, alpha=0.3)

# ── Panel C: PDM bitstream ──
ax2 = fig.add_subplot(gs[1, 1])
ax2.step(t[:SHOW] * 1e6, bits[:SHOW], color='#2563eb', lw=1, where='post')
ax2.fill_between(t[:SHOW] * 1e6, bits[:SHOW], step='post',
                 alpha=0.15, color='#2563eb')
ax2.set_title('③ PDM bitstream\n(density ≈ amplitude)', loc='left', fontsize=10, fontweight='bold')
ax2.set_yticks([0, 1])
ax2.set_ylabel('Bit')
ax2.set_xlabel('Time (µs)')
ax2.grid(True, alpha=0.3)

# ── Panel D: local bit density (sliding window) ──
ax3 = fig.add_subplot(gs[2, 0])
window = 32
density = np.convolve(bits[:SHOW].astype(float),
                      np.ones(window)/window, mode='same')
ax3.plot(t[:SHOW] * 1e6, sine_in[:SHOW] * 0.5 + 0.5,
         color='#2563eb', lw=1, ls='--', alpha=0.5, label='Sine (scaled to [0,1])')
ax3.plot(t[:SHOW] * 1e6, density,
         color='#ea580c', lw=1.5, label=f'Bit density (window={window})')
ax3.set_title('④ Bit density tracks sine amplitude', loc='left', fontsize=10, fontweight='bold')
ax3.set_ylabel('Density')
ax3.set_xlabel('Time (µs)')
ax3.set_ylim(-0.05, 1.05)
ax3.legend(fontsize=9)
ax3.grid(True, alpha=0.3)

# ── Panel E: recovered audio ──
ax4 = fig.add_subplot(gs[2, 1])
ax4.plot(t_audio * 1e3, audio_out, color='#16a34a', lw=1.5, label='Recovered audio')
# overlay expected sine at audio rate
t_ref = np.arange(len(audio_out)) / AUDIO_RATE
ax4.plot(t_ref * 1e3, np.sin(2 * np.pi * FREQ * t_ref),
         color='#2563eb', lw=1, ls='--', alpha=0.6, label='Expected sine')
ax4.set_title('⑤ Recovered audio (box FIR ÷64)', loc='left', fontsize=10, fontweight='bold')
ax4.set_ylabel('Amplitude')
ax4.set_xlabel('Time (ms)')
ax4.set_ylim(-1.3, 1.3)
ax4.legend(fontsize=9)
ax4.grid(True, alpha=0.3)

# ── Panel F: frequency spectrum comparison ──
ax5 = fig.add_subplot(gs[3, :])
# FFT of recovered audio
fft_out  = np.abs(np.fft.rfft(audio_out * np.hanning(len(audio_out))))
fft_freq = np.fft.rfftfreq(len(audio_out), 1 / AUDIO_RATE)
fft_db   = 20 * np.log10(fft_out / fft_out.max() + 1e-12)

ax5.plot(fft_freq / 1000, fft_db, color='#16a34a', lw=1.2, label='Recovered spectrum')
ax5.axvline(FREQ / 1000, color='#2563eb', lw=1.5, ls='--',
            label=f'Input tone: {FREQ} Hz')
ax5.set_title('⑥ Frequency spectrum of recovered audio', loc='left', fontsize=10, fontweight='bold')
ax5.set_xlabel('Frequency (kHz)')
ax5.set_ylabel('Magnitude (dB)')
ax5.set_xlim(0, AUDIO_RATE / 2000)
ax5.set_ylim(-80, 5)
ax5.legend(fontsize=9)
ax5.grid(True, alpha=0.3)

import os
out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'pdm_sigma_delta.png')
plt.savefig(out_path, dpi=150, bbox_inches='tight')
print(f"\nPlot saved to {out_path}")


# ─────────────────────────────────────────────
# Quick numpy one-liner version (for reference)
# ─────────────────────────────────────────────
print("\n── Minimal sigma-delta in 8 lines ──")
print("""
intg, fb = 0.0, 1.0
bits = []
for x in sine_samples:
    intg += x - fb          # accumulate error
    bit   = int(intg >= 0)  # compare to zero
    fb    = 1.0 if bit else -1.0
    bits.append(bit)
""")
