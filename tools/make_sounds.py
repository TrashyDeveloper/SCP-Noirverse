# Synthesises all of SCP: Noirverse's sound effects and the placeholder menu
# music (original sounds, made from noise and sine waves).
import numpy as np, wave, os, sys
SR = 22050
OUT = sys.argv[1]
rng = np.random.default_rng(1947)

def t(d): return np.arange(int(SR * d)) / SR
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def env_exp(d, decay, attack=0.002):
    x = t(d); e = np.exp(-x / decay); a = np.minimum(x / attack, 1.0) if attack > 0 else 1
    return e * a
def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR); y = np.zeros_like(x); s = 0.0
    for i in range(len(x)):
        s = (1 - a) * x[i] + a * s; y[i] = s
    return y
def highpass(x, cutoff): return x - lowpass(x, cutoff)
def bandpass(x, lo, hi): return highpass(lowpass(x, hi), lo)
def norm(x, peak=0.9): m = np.max(np.abs(x)) or 1; return x / m * peak
def pad(x, d): return np.concatenate([x, np.zeros(int(SR * d))])
def mix(*parts):
    n = max(len(p) for p in parts); y = np.zeros(n)
    for p in parts: y[:len(p)] += p
    return y
def at(x, start, total):
    y = np.zeros(int(SR * total)); s = int(SR * start); y[s:s + len(x)] += x[:len(y) - s]; return y
def echo(x, delay, fb, n=4):
    y = x.copy()
    for k in range(1, n + 1):
        d = int(SR * delay * k); y2 = np.zeros(len(y) + d); y2[:len(y)] += y; y2[d:d + len(x)] += x * fb ** k; y = y2
    return y
def save(name, x, peak=0.9):
    x = norm(x, peak); data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
def thump(freq, d, decay):
    x = t(d); f = freq * (1 + 1.5 * np.exp(-x / 0.01)); return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-x / decay)

# --- Gunshots ---------------------------------------------------------------
def shot(crack_cut, crack_decay, body_freq, body_decay, tail, tail_fb):
    d = 0.6 + tail * 4
    crack = lowpass(noise(d), crack_cut) * env_exp(d, crack_decay, 0.0005)
    body = thump(body_freq, d, body_decay)
    x = mix(crack * 1.0, body * 0.8)
    return echo(x, tail, tail_fb, 3) if tail > 0 else x
save("shot_light", shot(5000, 0.035, 140, 0.05, 0.09, 0.25))
save("shot_rifle", shot(7000, 0.05, 110, 0.07, 0.12, 0.3))
save("shot_heavy", shot(4500, 0.07, 80, 0.1, 0.14, 0.35))
save("shot_sniper", shot(8000, 0.06, 70, 0.12, 0.22, 0.45))
save("shot_suppressed", mix(lowpass(noise(0.25), 1200) * env_exp(0.25, 0.03, 0.001) * 0.7,
	at(bandpass(noise(0.02), 2000, 6000) * env_exp(0.02, 0.005), 0.03, 0.25) * 0.4), 0.6)

# --- Mechanical clicks ------------------------------------------------------
def click(freq_lo=1500, freq_hi=6000, d=0.03): return bandpass(noise(d), freq_lo, freq_hi) * env_exp(d, 0.004, 0.0003)
save("dry_fire", click(), 0.5)
save("reload", mix(at(click(800, 4000, 0.05), 0.0, 1.2), at(lowpass(noise(0.15), 900) * env_exp(0.15, 0.04), 0.35, 1.2) * 0.6,
	at(click(1000, 5000, 0.05), 0.9, 1.2), at(click(600, 3000, 0.06), 1.05, 1.2) * 1.2), 0.6)
save("pickup", mix(click(1200, 5000, 0.04), at(click(700, 2500, 0.04), 0.05, 0.12)), 0.45)
save("button", mix(click(900, 4000, 0.04), thump(300, 0.08, 0.02) * 0.3), 0.5)

# --- Footsteps (4 variants) -------------------------------------------------
for i in range(4):
    d = 0.18
    knock = thump(90 + i * 12, d, 0.025) * 0.9
    scuff = lowpass(noise(d), 1800 + i * 300) * env_exp(d, 0.02, 0.001) * 0.6
    save("footstep_%d" % (i + 1), mix(knock, scuff), 0.5)

# --- Doors ------------------------------------------------------------------
def door(opening):
    d = 1.0
    x = t(d)
    hiss = bandpass(noise(d), 2500, 8000) * np.clip(1 - x / 0.5, 0, 1) * np.minimum(x / 0.02, 1) * 0.5
    f = 160 + (60 if opening else -30) * x
    motor = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.25 * np.clip(1 - np.abs(x - 0.3) / 0.35, 0, 1)
    clunk = at(mix(thump(70, 0.25, 0.06), click(300, 2000, 0.05)), 0.62, d)
    return mix(hiss, motor, clunk * 0.9)
save("door_open", door(True), 0.6)
save("door_close", door(False), 0.6)
def beep(f, d, n=1, gap=0.06, square=False):
    parts = []
    for k in range(n):
        x = t(d); w = np.sin(2 * np.pi * f * x)
        if square: w = np.sign(w) * 0.6
        parts.append(at(w * np.minimum(x / 0.005, 1) * np.clip((d - x) / 0.01, 0, 1), k * (d + gap), n * (d + gap)))
    return mix(*parts)
save("card_accept", mix(beep(1320, 0.07, 1), at(beep(1760, 0.09, 1), 0.09, 0.2)), 0.45)
save("card_deny", lowpass(beep(180, 0.32, 1, square=True), 1500), 0.5)

# --- Explosions -------------------------------------------------------------
d = 3.0
boom = lowpass(noise(d), 600) * env_exp(d, 0.5, 0.002)
rumble = lowpass(noise(d), 120) * env_exp(d, 1.0, 0.05) * 2.5
save("explosion", mix(boom, rumble, thump(45, d, 0.35) * 1.5, lowpass(noise(0.1), 6000) * env_exp(0.1, 0.02) * 0.6))
x = t(2.5)
ring = np.sin(2 * np.pi * 3100 * x) * np.exp(-x / 0.9) * 0.25 + np.sin(2 * np.pi * 3170 * x) * np.exp(-x / 1.1) * 0.15
save("flashbang", mix(lowpass(noise(0.5), 5000) * env_exp(0.5, 0.06), ring), 0.85)

# --- Lifts ------------------------------------------------------------------
d = 7.0; x = t(d)
fade = np.clip(x / 0.8, 0, 1) * np.clip((d - x) / 0.8, 0, 1)
motor = (np.sin(2 * np.pi * 98 * x) * 0.5 + np.sin(2 * np.pi * 196 * x) * 0.2 + lowpass(noise(d), 300) * 0.6) * fade
save("lift_move", motor, 0.5)
def bell(f, d, decay):
    x = t(d); return sum(np.sin(2 * np.pi * f * h * x) * np.exp(-x / (decay / h)) / h for h in (1, 2.01, 3.03, 4.2))
save("lift_ding", mix(bell(880, 1.5, 0.8), at(bell(659, 1.5, 0.8), 0.35, 1.9)), 0.5)
save("intercom_chime", mix(bell(523, 1.6, 0.7), at(bell(659, 1.6, 0.7), 0.3, 2.0), at(bell(784, 1.6, 0.9), 0.6, 2.4)), 0.5)

# --- Loops (lengths chosen so the waves line up at the loop point) ----------
d = 2.0; x = t(d)
f = 650 + 250 * (0.5 - 0.5 * np.cos(2 * np.pi * x / d))
siren = np.sin(2 * np.pi * np.cumsum(f) / SR)
siren = np.tanh(siren * 2.0) * 0.7
save("alarm_loop", siren, 0.55)
d = 4.0; x = t(d)
hum = np.sin(2 * np.pi * 55 * x) * 0.5 + np.sin(2 * np.pi * 110.25 * x) * 0.3 + np.sin(2 * np.pi * 165 * x) * 0.15 \
	+ np.sin(2 * np.pi * 440 * x) * 0.05 * (0.5 + 0.5 * np.sin(2 * np.pi * x))
save("reactor_hum_loop", hum, 0.6)
d = 8.0
amb = lowpass(lowpass(noise(d + 1), 200), 120)[SR:]
amb = amb / np.max(np.abs(amb)) * 0.6 + np.sin(2 * np.pi * 50 * t(d)) * 0.08 + np.sin(2 * np.pi * 100 * t(d)) * 0.04
n = int(SR * 0.5); amb[:n] = amb[:n] * np.linspace(0, 1, n) + amb[-n:] * np.linspace(1, 0, n); amb = amb[:-n]
save("ambience_loop", amb, 0.5)
# SCP-914: clockwork ticking, gear whir and grinding.
d = 4.0; x = t(d)
ticks = np.zeros(len(x))
for k in range(32):
    tk = click(1500 + (k % 4) * 400, 7000, 0.03) * (1.0 if k % 2 == 0 else 0.6)
    s = int(k * d / 32 * SR); ticks[s:s + len(tk)] += tk[:len(ticks) - s]
whir = (2 * ((55 * x) % 1) - 1) * 0.25 + np.sin(2 * np.pi * 110 * x) * 0.2
grind = lowpass(noise(d), 700) * (0.6 + 0.4 * np.sin(2 * np.pi * 2 * x)) * 0.5
save("machine_914_loop", mix(ticks * 0.8, lowpass(whir, 900), grind), 0.6)
save("machine_914_start", mix(click(400, 3000, 0.08), at(thump(60, 0.6, 0.15), 0.1, 0.8), at(bell(330, 0.6, 0.3) * 0.3, 0.05, 0.8)), 0.6)
save("machine_914_done", mix(bell(1046, 1.8, 0.9), at(thump(70, 0.4, 0.1), 0.0, 1.8)), 0.55)

# --- Placeholder menu music: slow noir chords, a lonely melody, vinyl crackle.
def note(n): return 440.0 * 2 ** ((n - 69) / 12)
BAR = 6.0
chords = [[57, 60, 64], [53, 57, 60], [50, 53, 57], [52, 56, 59], [57, 60, 64], [53, 57, 60], [55, 59, 62], [52, 56, 59]]
total = BAR * len(chords)
song = np.zeros(int(SR * total))
for ci, ch in enumerate(chords):
    x = t(BAR)
    pad_env = np.minimum(x / 1.8, 1) * np.clip((BAR - x) / 1.5, 0, 1)
    padv = sum(np.sin(2 * np.pi * note(n) * x) + 0.6 * np.sin(2 * np.pi * note(n) * 1.003 * x) for n in ch) * pad_env * 0.12
    bass = np.sin(2 * np.pi * note(ch[0] - 12) * x) * np.exp(-x / 3.0) * 0.35
    s = int(ci * BAR * SR); song[s:s + len(x)] += padv + bass
melody = [(0.0, 69), (1.5, 72), (3.0, 71), (6.5, 69), (9.0, 65), (12.0, 64), (13.5, 65), (15.0, 62), (19.0, 64), (21.0, 68),
	(24.5, 76), (26.0, 74), (27.5, 72), (31.0, 69), (36.0, 71), (37.5, 74), (40.0, 71), (43.0, 68), (45.0, 69)]
for start, n in melody:
    x = t(3.0); f = note(n)
    tone = (np.sin(2 * np.pi * f * x) + 0.4 * np.sin(4 * np.pi * f * x) + 0.15 * np.sin(6 * np.pi * f * x)) * np.exp(-x / 0.9) * np.minimum(x / 0.01, 1) * 0.22
    s = int(start * SR); end = min(len(song), s + len(tone)); song[s:end] += tone[:end - s]
# Circular reverb: the loop wraps around seamlessly.
ir_len = int(SR * 2.5); ir = rng.normal(0, 1, ir_len) * np.exp(-np.arange(ir_len) / (SR * 0.6)); ir[0] = 6.0
N = len(song)
wet = np.real(np.fft.ifft(np.fft.fft(song) * np.fft.fft(np.pad(ir, (0, N - ir_len)))))
song = song * 0.6 + norm(wet, np.max(np.abs(song))) * 0.5
crackle = np.zeros(N); idx = rng.integers(0, N, 900); crackle[idx] = rng.uniform(-0.4, 0.4, 900)
crackle = lowpass(crackle, 3000) + lowpass(noise(total), 1200) * 0.01
save("../music/menu_placeholder", song + crackle, 0.7)
print("done")
