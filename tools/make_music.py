# Synthesises the extra placeholder menu tracks (original music, made from
# sine/saw waves and noise). Every track loops seamlessly: notes that run
# past the end wrap around to the start, and the reverb is circular.
# Usage: python3 tools/make_music.py assets/audio/music
import numpy as np, wave, os, sys
SR = 22050
OUT = sys.argv[1]
rng = np.random.default_rng(2025)

def t(d): return np.arange(int(SR * d)) / SR
def note(n): return 440.0 * 2 ** ((n - 69) / 12)
def norm(x, peak=0.9): m = np.max(np.abs(x)) or 1; return x / m * peak
def spectral(x, gain):
    # Filters a whole (looping) signal in the frequency domain.
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(np.fft.rfft(x) * gain(f), len(x))
def lowpass(x, cut): return spectral(x, lambda f: 1 / np.sqrt(1 + (f / cut) ** 4))
def highpass(x, cut): return spectral(x, lambda f: 1 / np.sqrt(1 + (cut / np.maximum(f, 1)) ** 4))
def place(song, x, start):
    s = int(start * SR) % len(song); n = len(x); end = s + n
    if end <= len(song): song[s:end] += x
    else:
        k = len(song) - s; song[s:] += x[:k]; rest = x[k:]
        while len(rest) > 0:
            m = min(len(rest), len(song)); song[:m] += rest[:m]; rest = rest[m:]
def reverb(song, length, decay, wet):
    n = int(SR * length); ir = rng.normal(0, 1, n) * np.exp(-np.arange(n) / (SR * decay))
    ir = lowpass(np.pad(ir, (0, len(song) - n)), 4000)
    w = np.real(np.fft.ifft(np.fft.fft(song) * np.fft.fft(ir)))
    return song * (1 - wet) + norm(w, np.max(np.abs(song))) * wet
def save(name, x, peak=0.7):
    x = norm(x, peak); data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
    print("saved", name)

def env(d, attack, release):
    x = t(d); return np.minimum(x / attack, 1) * np.clip((d - x) / release, 0, 1)
def pad_voice(n, d, detune=0.004):
    x = t(d); f = note(n)
    return (np.sin(2 * np.pi * f * x) + 0.6 * np.sin(2 * np.pi * f * (1 + detune) * x)
        + 0.3 * np.sin(2 * np.pi * f * 2 * (1 - detune) * x))
def bell(n, d, decay):
    x = t(d); f = note(n)
    return (np.sin(2 * np.pi * f * x) + 0.5 * np.sin(2 * np.pi * f * 2.76 * x) * np.exp(-x / (decay * 0.3))
        + 0.25 * np.sin(2 * np.pi * f * 5.4 * x) * np.exp(-x / (decay * 0.1))) * np.exp(-x / decay) * np.minimum(x / 0.003, 1)
def piano(n, d, decay=1.2):
    x = t(d); f = note(n)
    return sum(np.sin(2 * np.pi * f * k * x) * np.exp(-x * k / decay) / k for k in range(1, 6)) * np.minimum(x / 0.004, 1)
def pluck_bass(n, d):
    x = t(d); f = note(n)
    return (np.sin(2 * np.pi * f * x) + 0.3 * np.sin(4 * np.pi * f * x) * np.exp(-x / 0.1)) * np.exp(-x / 0.5) * np.minimum(x / 0.005, 1)
def saw(f, x): return 2 * ((f * x) % 1) - 1
def brush(d):
    return highpass(rng.uniform(-1, 1, int(SR * d)), 3000) * np.exp(-t(d) / 0.06)
def kick(d=0.4):
    x = t(d); f = 50 * (1 + 2 * np.exp(-x / 0.02)); return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-x / 0.18)
def hat(d=0.05):
    return highpass(rng.uniform(-1, 1, int(SR * d)), 7000) * np.exp(-t(d) / 0.015)

# --- 2: "Cold Storage" - slow, icy pads and glass bells. ----------------------
BAR = 8.0
chords = [[50, 57, 60, 64], [46, 53, 57, 62], [43, 50, 57, 58], [45, 52, 55, 61], [50, 57, 60, 65], [46, 53, 58, 62]]
song = np.zeros(int(SR * BAR * len(chords)))
for i, ch in enumerate(chords):
    for n in ch:
        place(song, pad_voice(n, BAR + 3) * env(BAR + 3, 2.5, 3.0) * 0.1, i * BAR)
    place(song, np.sin(2 * np.pi * note(ch[0] - 12) * t(BAR + 2)) * env(BAR + 2, 1.5, 2.0) * 0.25, i * BAR)
for start, n in [(1, 81), (5, 76), (9.5, 79), (14, 74), (17, 77), (22, 81), (26, 84), (30.5, 79), (33, 77), (38, 76), (41, 74), (45, 72)]:
    place(song, bell(n, 4, 1.6) * 0.18, start)
song = reverb(lowpass(song, 5000), 4.0, 1.2, 0.55)
song += lowpass(rng.uniform(-1, 1, len(song)), 400) * 0.01
save("menu_placeholder_2", song)

# --- 3: "Night Shift" - noir jazz: walking bass, brushes, a muted horn. -------
BPM = 72; BEAT = 60 / BPM; BARS = 16
song = np.zeros(int(SR * BEAT * 4 * BARS))
prog = [(45, [57, 60, 64, 67]), (50, [57, 60, 62, 65]), (43, [55, 59, 62, 65]), (48, [55, 59, 64, 67])] * 4
walk = [[0, 3, 5, 7], [0, 2, 3, 4], [0, 4, 7, 5], [0, 2, 4, -1]]
for b, (root, voic) in enumerate(prog):
    for k, step in enumerate(walk[b % 4]):
        place(song, pluck_bass(root - 12 + step, BEAT * 1.2) * 0.45, (b * 4 + k) * BEAT)
    for hit in [0.0, 1.5] if b % 2 == 0 else [0.5, 2.5]:
        for n in voic:
            place(song, piano(n, BEAT * 3, 0.9) * 0.08, (b * 4 + hit) * BEAT)
    for k in range(4):
        place(song, brush(0.25) * (0.16 if k % 2 else 0.07), (b * 4 + k) * BEAT)
        place(song, brush(0.12) * 0.05, (b * 4 + k + 0.66) * BEAT)
horn = [(1, 69, 2), (3, 72, 1), (4, 71, 3), (9, 67, 1.5), (10.5, 69, 1.5), (12, 64, 4), (17, 72, 2), (19, 76, 1), (20, 74, 3),
    (25, 72, 1), (26, 71, 1), (27, 69, 2), (29, 67, 3), (33, 69, 2), (35, 72, 1), (36, 76, 3), (41, 74, 1.5), (42.5, 72, 1.5),
    (44, 71, 4), (49, 69, 1), (50, 67, 1), (51, 64, 2), (53, 69, 6)]
for beat, n, length in horn:
    d = length * BEAT; x = t(d + 0.3); f = note(n) * (1 + 0.006 * np.sin(2 * np.pi * 5 * x) * np.minimum(x / 0.4, 1))
    tone = saw(1, np.cumsum(f) / SR)
    place(song, lowpass(np.pad(tone * env(d + 0.3, 0.06, 0.3), (0, len(song) - len(tone))), 1300)[:len(tone)] * 0.12, beat * BEAT)
song = reverb(song, 2.5, 0.6, 0.35)
crackle = np.zeros(len(song)); idx = rng.integers(0, len(song), 700); crackle[idx] = rng.uniform(-0.3, 0.3, 700)
save("menu_placeholder_3", song + lowpass(crackle, 3000))

# --- 4: "Event Horizon" - time slowing down: sinking pads, a slow heartbeat. --
L = 48.0
song = np.zeros(int(SR * L))
x = t(L)
for n, amp in [(38, 0.3), (45, 0.18), (50, 0.12), (53, 0.08), (57, 0.06)]:
    # Each voice wobbles a little in pitch, as if the tape were dragging.
    # (Whole number of cycles per loop, so the seam is silent.)
    f = round(note(n) * L) / L * (1 + 0.01 * np.sin(2 * np.pi * x / L * 2))
    song += np.sin(2 * np.pi * np.cumsum(f) / SR) * amp * (0.6 + 0.4 * np.sin(2 * np.pi * x / L * 3 + n * 0.7))
for beat in np.arange(0, L, 4.0):
    place(song, kick(0.5) * 0.35, beat); place(song, kick(0.5) * 0.2, beat + 0.45)
for start in [6, 19, 31, 42]:
    d = 6; xs = t(d); f = note(rng.integers(74, 86)) * np.linspace(1, 0.8, len(xs))
    place(song, np.sin(2 * np.pi * np.cumsum(f) / SR) * env(d, 3, 2.5) * 0.08, start)
for start in rng.uniform(0, L, 6):
    place(song, lowpass(np.pad(rng.uniform(-1, 1, int(SR * 1.5)) * env(1.5, 0.4, 1.0), (0, len(song) - int(SR * 1.5))), 600)[:int(SR * 1.5)] * 0.1, start)
song = reverb(lowpass(song, 3000), 5.0, 1.6, 0.6)
save("menu_placeholder_4", song)

# --- Fusion 1: "Reactor Hum" - pulsing synth arpeggios over a deep hum. -------
BPM = 100; BEAT = 60 / BPM; BARS = 16
song = np.zeros(int(SR * BEAT * 4 * BARS))
prog = [[45, 52, 57, 60, 64], [41, 48, 53, 57, 60], [43, 50, 55, 59, 62], [40, 47, 52, 56, 59]] * 4
for b, ch in enumerate(prog):
    for k in range(16):
        n = ch[1:][[0, 1, 2, 3, 2, 1, 3, 2][k % 8]] + (12 if k % 4 == 3 else 0)
        d = BEAT / 4; xs = t(d * 1.6)
        tone = saw(note(n), xs) * np.exp(-xs / 0.09) * np.minimum(xs / 0.003, 1)
        place(song, tone * 0.11, (b * 4 + k / 4) * BEAT)
    for n in ch[1:]:
        place(song, pad_voice(n, BEAT * 4.5, 0.006) * env(BEAT * 4.5, 0.5, 0.8) * 0.05, b * 4 * BEAT)
    for k in range(8):
        place(song, saw(note(ch[0] - 12), t(BEAT / 2)) * np.exp(-t(BEAT / 2) / 0.12) * 0.2, (b * 4 + k / 2) * BEAT)
    if b >= 4:
        for k in range(4):
            place(song, kick() * 0.5, (b * 4 + k) * BEAT)
            place(song, hat() * 0.12, (b * 4 + k + 0.5) * BEAT)
song = lowpass(song, 3500)
song += np.sin(2 * np.pi * 60 * t(len(song) / SR)) * 0.04 + np.sin(2 * np.pi * 120 * t(len(song) / SR)) * 0.015
song = reverb(song, 2.0, 0.5, 0.3)
save("fusion_placeholder", song)

# --- Fusion 2: "Clean Energy" - bright bells, a hopeful Lydian lift. ----------
BPM = 88; BEAT = 60 / BPM; BARS = 16
song = np.zeros(int(SR * BEAT * 4 * BARS))
prog = [[48, 55, 60, 64, 66], [45, 52, 57, 60, 64], [41, 48, 53, 57, 62], [43, 50, 55, 59, 62]] * 4
for b, ch in enumerate(prog):
    for k in range(8):
        n = ch[1:][[0, 2, 1, 3, 2, 3, 1, 2][k]] + 12
        place(song, bell(n, 2.0, 0.7) * 0.07, (b * 4 + k / 2) * BEAT)
    for n in ch[1:]:
        place(song, pad_voice(n, BEAT * 5, 0.003) * env(BEAT * 5, 1.0, 1.2) * 0.06, b * 4 * BEAT)
    place(song, np.sin(2 * np.pi * note(ch[0] - 12) * t(BEAT * 4)) * env(BEAT * 4, 0.05, 0.5) * 0.3, b * 4 * BEAT)
    if b >= 2:
        for k in (0, 2):
            place(song, kick() * 0.3, (b * 4 + k) * BEAT)
        for k in range(8):
            place(song, hat(0.03) * 0.05, (b * 4 + k / 2 + 0.25) * BEAT)
song = reverb(song, 3.0, 0.8, 0.45)
save("fusion_placeholder_2", song)
