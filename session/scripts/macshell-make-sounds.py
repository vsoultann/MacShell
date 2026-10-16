#!/usr/bin/env python3
"""Synthesize MacShell's UI sounds (macOS-style, original recordings are Apple's and not redistributable).

Writes 48 kHz mono WAVs to ~/.local/share/sounds/macshell/:
  pop      volume change            (macOS "Pop")
  tink     small UI ticks            (macOS "Tink")
  glass    notification              (macOS "Glass")
  lock     lock screen appears       (iOS/macOS lock click)
  unlock   unlocked                  (soft rising chime)
  shutter  screenshot                (camera shutter)
  charge   charger connected         (macOS power chime)
  trash    empty trash               (paper crumple)
"""
import os
import wave
import numpy as np

SR = 48000
OUT = os.path.expanduser("~/.local/share/sounds/macshell")
rng = np.random.default_rng(7)


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def env(t, attack, decay):
    """fast attack, exponential decay"""
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / decay)


def bandpass_noise(n, lo, hi):
    x = rng.standard_normal(n)
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    f[(freqs < lo) | (freqs > hi)] = 0
    return np.fft.irfft(f, n)


def bell(t, f0, ratios, amps, decays, attack=0.002):
    s = np.zeros_like(t)
    for r, a, d in zip(ratios, amps, decays):
        s += a * np.sin(2 * np.pi * f0 * r * t) * env(t, attack, d)
    return s


def finish(x, peak_db=-7.0, tail=0.02):
    x = np.asarray(x, dtype=np.float64)
    n = int(SR * tail)
    if n and len(x) > n:
        x[-n:] *= np.linspace(1, 0, n)          # no click at the end
    x -= np.mean(x)
    peak = np.max(np.abs(x)) or 1.0
    return x / peak * (10 ** (peak_db / 20))


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# Pop: a bubble — fast downward pitch sweep with a soft click
t = t_axis(0.09)
f = 1250 * np.exp(-t * 22) + 420
pop = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(t, 0.0015, 0.022)
pop += 0.25 * bandpass_noise(len(t), 2000, 7000) * env(t, 0.0003, 0.003)
write("pop", finish(pop, -8))

# Tink: tiny metallic tap
t = t_axis(0.16)
tink = bell(t, 2350, [1.0, 1.62, 2.71], [1.0, 0.45, 0.22], [0.045, 0.03, 0.018], 0.0008)
write("tink", finish(tink, -12))

# Glass: bright bell, inharmonic partials, long gentle ring
t = t_axis(1.3)
glass = bell(t, 1568, [1.0, 2.76, 5.40, 8.93], [1.0, 0.42, 0.20, 0.08], [0.42, 0.20, 0.09, 0.05], 0.003)
glass += 0.5 * bell(t, 1568 * 1.5, [1.0, 2.76], [0.35, 0.12], [0.25, 0.1], 0.004)   # a fifth on top, like the macOS chime
write("glass", finish(glass, -9))

# Lock: soft mechanical click + low thump
t = t_axis(0.12)
lock = 0.8 * bandpass_noise(len(t), 1800, 6000) * env(t, 0.0004, 0.006)
lock += 0.9 * np.sin(2 * np.pi * 150 * t) * env(t, 0.001, 0.018)
t2 = t_axis(0.12)
click2 = 0.35 * bandpass_noise(len(t2), 2500, 8000) * env(t2, 0.0003, 0.004)
lock = lock + np.concatenate([np.zeros(int(SR * 0.018)), click2])[: len(lock)]
write("lock", finish(lock, -10))

# Unlock: two quick soft notes going up (E6 → B6)
t = t_axis(0.5)
n1 = bell(t, 1318.5, [1.0, 2.0, 3.0], [1.0, 0.25, 0.08], [0.14, 0.08, 0.05], 0.004)
n2 = bell(t, 1975.5, [1.0, 2.0, 3.0], [0.9, 0.22, 0.07], [0.2, 0.1, 0.05], 0.004)
off = int(SR * 0.075)
unlock = n1 + np.concatenate([np.zeros(off), n2])[: len(n1)]
write("unlock", finish(unlock, -12))

# Shutter: two mechanical clicks (curtain open / close) with a little body resonance
def shutter_click(sec, lo, hi, body):
    t = t_axis(sec)
    x = bandpass_noise(len(t), lo, hi) * env(t, 0.0003, 0.012)
    x += 0.5 * np.sin(2 * np.pi * body * t) * env(t, 0.0005, 0.02)
    return x
a = shutter_click(0.08, 1500, 9000, 420)
b = shutter_click(0.12, 1200, 7000, 330)
shut = np.zeros(int(SR * 0.26))
shut[: len(a)] += a
o = int(SR * 0.11)
shut[o: o + len(b)] += 0.85 * b
write("shutter", finish(shut, -8))

# Charge: the macOS power chime — one warm, clean bell
t = t_axis(1.0)
charge = bell(t, 1046.5, [1.0, 2.0, 3.01, 4.2], [1.0, 0.35, 0.12, 0.05], [0.38, 0.22, 0.12, 0.06], 0.005)
write("charge", finish(charge, -10))

# Trash: paper crumple — a burst of random crackles
dur = 0.7
n = int(SR * dur)
trash = np.zeros(n)
for _ in range(70):
    pos = int(rng.uniform(0, 0.62) * SR)
    ln = int(rng.uniform(0.004, 0.02) * SR)
    seg = bandpass_noise(ln, 900, 7000) * np.hanning(ln) * rng.uniform(0.3, 1.0)
    trash[pos: pos + ln] += seg[: max(0, min(ln, n - pos))]
trash *= np.concatenate([np.linspace(0.6, 1, n // 3), np.linspace(1, 0.15, n - n // 3)])
write("trash", finish(trash, -12))

# Alarm: a bright marimba arpeggio in the spirit of Apple's "Radial" (original synthesis) — one 2 s phrase, looped
# by the Clock while it rings
def marimba(f, sec=0.5):
    t = t_axis(sec)
    return bell(t, f, [1.0, 3.93, 9.0], [1.0, 0.28, 0.06], [0.22, 0.05, 0.02], 0.001)
phrase = [(0.00, 1318.5), (0.12, 1567.98), (0.24, 1975.5), (0.36, 1567.98),
          (0.72, 1318.5), (0.84, 1567.98), (0.96, 1975.5), (1.08, 2637.0)]
alarm = np.zeros(int(SR * 2.0))
for at, f in phrase:
    m = marimba(f); o = int(at * SR)
    alarm[o: o + len(m)] += m[: max(0, min(len(m), len(alarm) - o))]
write("alarm", finish(alarm, -8))

# Timer done: the same voice, a shorter three-note phrase
tdone = np.zeros(int(SR * 1.2))
for at, f in [(0.0, 1567.98), (0.14, 1975.5), (0.28, 2349.3)]:
    m = marimba(f, 0.7); o = int(at * SR)
    tdone[o: o + len(m)] += m[: max(0, min(len(m), len(tdone) - o))]
write("timer", finish(tdone, -8))

print("wrote", ", ".join(sorted(os.listdir(OUT))), "to", OUT)
