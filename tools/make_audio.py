"""Синтезирует все звуки и музыку игры в game/audio/*.wav (чистый Python, без зависимостей).

Запуск: python tools/make_audio.py
Всё сгенерировано кодом -> нет лицензионных проблем (правило CrazyGames: оригинальные ассеты).
Лупящиеся файлы (музыка, двигатель) получают smpl-чанк, Godot подхватывает петлю при импорте.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "audio")
os.makedirs(OUT, exist_ok=True)
rng = random.Random(1234)


def write_wav(name, samples, loop=False, gain=0.9):
    peak = max(1e-9, max(abs(s) for s in samples))
    data = b"".join(struct.pack("<h", int(s / peak * gain * 32767)) for s in samples)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    if loop:  # дописываем smpl-чанк с петлёй на весь файл
        smpl = struct.pack("<9I", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(samples) - 1, 0, 0)
        with open(path, "ab") as f:
            f.write(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
        size = os.path.getsize(path) - 8
        with open(path, "r+b") as f:
            f.seek(4)
            f.write(struct.pack("<I", size))
    print(name, round(len(samples) / RATE, 2), "s")


def n(sec):
    return int(sec * RATE)


def env(i, total, attack=0.005, curve=3.0):
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * (1.0 - i / total) ** curve


def lowpass(samples, k):
    out, y = [], 0.0
    for s in samples:
        y += k * (s - y)
        out.append(y)
    return out


def noise(count):
    return [rng.uniform(-1, 1) for _ in range(count)]


# ---------------------------------------------------------------- SFX

def shot():
    total = n(0.28)
    out, phase = [], 0.0
    nz = lowpass(noise(total), 0.5)
    for i in range(total):
        f = 160 * math.exp(-i / RATE * 14) + 45
        phase += 2 * math.pi * f / RATE
        out.append((math.sin(phase) * 0.9 + nz[i] * 0.9 * math.exp(-i / RATE * 28)) * env(i, total, 0.001, 2.2))
    return out


def bounce():
    total = n(0.16)
    return [(math.sin(2 * math.pi * 1180 * i / RATE) * 0.5 + math.sin(2 * math.pi * 1770 * i / RATE) * 0.3
             + math.sin(2 * math.pi * 2650 * i / RATE) * 0.15) * env(i, total, 0.0005, 4.0) for i in range(total)]


def explosion():
    total = n(0.9)
    nz = noise(total)
    low = lowpass(nz, 0.06)
    mid = lowpass(nz, 0.25)
    out, phase = [], 0.0
    for i in range(total):
        t = i / RATE
        phase += 2 * math.pi * (95 * math.exp(-t * 3.5) + 28) / RATE
        out.append(low[i] * 3.0 * math.exp(-t * 3.2) + mid[i] * 1.0 * math.exp(-t * 9) + math.sin(phase) * 0.9 * math.exp(-t * 4))
    return [s * (1 - (i / total) ** 6) for i, s in enumerate(out)]


def crate_break():
    total = n(0.38)
    out = []
    nz = lowpass(noise(total), 0.45)
    for i in range(total):
        t = i / RATE
        crack = nz[i] * (1.0 if (i // 90) % 3 else 0.4) * math.exp(-t * 11)
        thud = math.sin(2 * math.pi * 120 * math.exp(-t * 8) * t) * math.exp(-t * 14)
        out.append((crack * 2.0 + thud * 0.8) * env(i, total, 0.001, 1.0))
    return out


def tone_seq(notes, dur, wave_fn="square", vol=0.5, tail=0.15):
    out = []
    for f in notes:
        count = n(dur)
        for i in range(count):
            t = i / RATE
            ph = (f * t) % 1.0
            v = (1.0 if ph < 0.5 else -1.0) if wave_fn == "square" else math.sin(2 * math.pi * f * t)
            out.append(v * vol * min(1.0, i / 60) * (1.0 - (i / count) ** 2 * 0.5))
    out += [0.0] * n(tail)
    for i in range(len(out)):
        out[i] *= 1.0 - max(0.0, (i - (len(out) - n(tail * 2))) / max(1, n(tail * 2))) ** 1
    return out


def note(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def ui_click():
    return tone_seq([note(79)], 0.03, "square", 0.35, 0.04)


def ui_hover():
    return tone_seq([note(84)], 0.018, "sine", 0.3, 0.02)


def pause_on():
    return tone_seq([note(72), note(67)], 0.07, "square", 0.3, 0.05)


def pause_off():
    return tone_seq([note(67), note(72)], 0.07, "square", 0.3, 0.05)


def round_start():
    return tone_seq([note(72), note(72), note(79)], 0.09, "square", 0.32, 0.1)


def round_win():
    return tone_seq([note(67), note(72), note(76), note(79)], 0.1, "square", 0.34, 0.25)


def round_draw():
    return tone_seq([note(67), note(64), note(60)], 0.14, "square", 0.3, 0.2)


def match_win():
    seq = [note(60), note(64), note(67), note(72), note(67), note(72), note(76), note(79), note(84)]
    return tone_seq(seq, 0.11, "square", 0.34, 0.5)


def engine():
    # ровно целое число периодов на длину файла -> бесшовная петля
    total = n(0.5)
    out = []
    for i in range(total):
        t = i / total
        v = 0.0
        for k, a in ((1, 1.0), (2, 0.6), (3, 0.35), (5, 0.18)):
            v += math.sin(2 * math.pi * 36 * k * 0.5 * t * 1) * a  # 18*k циклов на файл
        v *= 0.7 + 0.3 * math.sin(2 * math.pi * 9 * t)
        out.append(v)
    return out


# ---------------------------------------------------------------- Музыка

def drum_kick(count):
    return [math.sin(2 * math.pi * (140 * math.exp(-(i / RATE) * 28) + 42) * (i / RATE)) * math.exp(-(i / RATE) * 9) for i in range(count)]


def drum_snare(count):
    nz = noise(count)
    return [nz[i] * math.exp(-(i / RATE) * 22) * 0.7 + math.sin(2 * math.pi * 190 * i / RATE) * math.exp(-(i / RATE) * 25) * 0.4 for i in range(count)]


def drum_hat(count):
    nz = noise(count)
    prev, out = 0.0, []
    for i in range(count):
        hp = nz[i] - prev
        prev = nz[i]
        out.append(hp * math.exp(-(i / RATE) * 70) * 0.5)
    return out


def mix_in(buf, start, samples, vol):
    for i, s in enumerate(samples):
        j = start + i
        if j >= len(buf):
            break
        buf[j] += s * vol


def synth_note(freq, dur, kind, vol):
    count = max(1, n(dur))
    out = []
    for i in range(count):
        t = i / RATE
        ph = (freq * t) % 1.0
        if kind == "pulse":
            v = 1.0 if ph < 0.25 else -1.0
        elif kind == "square":
            v = 1.0 if ph < 0.5 else -1.0
        elif kind == "tri":
            v = 4 * abs(ph - 0.5) - 1
        else:
            v = math.sin(2 * math.pi * freq * t)
        a = min(1.0, i / 80) * min(1.0, (count - i) / 200)
        out.append(v * a * vol * (0.55 + 0.45 * math.exp(-t * 6)))
    return out


def make_track(name, bpm, root, scale, progression, bars_per_chord, lead_seed, drums, lead_vol=0.12):
    beat = 60.0 / bpm
    step = beat / 2  # восьмая
    chords = len(progression) * bars_per_chord
    total_steps = chords * 8
    buf = [0.0] * (total_steps * n(step))
    r = random.Random(lead_seed)
    kick, snare, hat = drum_kick(n(0.3)), drum_snare(n(0.25)), drum_hat(n(0.08))
    prev_deg = 0
    for s in range(total_steps):
        pos = s * n(step)
        chord = progression[(s // 8 // bars_per_chord) % len(progression)]
        c_root = root + chord[0]
        tones = [c_root + x for x in chord[1:]]
        # бас: октава вниз, ритм «корень-корень-квинта-корень»
        bass_note = c_root - 24 + (7 if s % 4 == 3 else 0)
        mix_in(buf, pos, synth_note(note(bass_note), step * 0.9, "tri", 0.30), 1.0)
        # арпеджио аккорда
        arp = tones[(s % 4) % len(tones)] + (12 if (s // 4) % 2 else 0)
        mix_in(buf, pos, synth_note(note(arp), step * 0.8, "pulse", 0.07), 1.0)
        # мелодия: случайное блуждание по гамме, паузы по ритму
        if s % 2 == 0 and r.random() < 0.8:
            prev_deg = max(0, min(len(scale) * 2 - 1, prev_deg + r.choice([-2, -1, -1, 0, 1, 1, 2])))
            semi = scale[prev_deg % len(scale)] + 12 * (prev_deg // len(scale))
            dur = step * r.choice([1.0, 1.8, 1.8])
            mix_in(buf, pos, synth_note(note(root + 12 + semi), dur, "square", lead_vol), 1.0)
        if drums:
            if s % 4 == 0:
                mix_in(buf, pos, kick, 0.55)
            if s % 8 == 4:
                mix_in(buf, pos, snare, 0.35)
            if s % 2 == 1 or drums == 2:
                mix_in(buf, pos, hat, 0.18)
    # лёгкая сатурация + нормализация
    peak = max(abs(x) for x in buf)
    buf = [math.tanh(x / peak * 1.6) for x in buf]
    write_wav(name, buf, loop=True, gain=0.8)


def main():
    for name, fn in [("shot", shot), ("bounce", bounce), ("explosion", explosion), ("crate_break", crate_break),
                     ("ui_click", ui_click), ("ui_hover", ui_hover), ("pause_on", pause_on), ("pause_off", pause_off),
                     ("round_start", round_start), ("round_win", round_win), ("round_draw", round_draw), ("match_win", match_win)]:
        write_wav(name, fn())
    write_wav("engine", engine(), loop=True, gain=0.7)

    minor = [0, 2, 3, 5, 7, 8, 10]
    major = [0, 2, 4, 5, 7, 9, 11]
    # Am - F - C - G / Am - Dm - E - Am : боевая (быстрая)
    battle = [(0, 0, 3, 7), (-4, 0, 4, 7), (3, 0, 4, 7), (-2, 0, 4, 7), (0, 0, 3, 7), (5, 0, 3, 7), (7, 0, 4, 7), (0, 0, 3, 7)]
    make_track("music_battle", 142, 57, minor, battle, 2, 11, drums=2, lead_vol=0.11)
    # C - Am - F - G : мягкая меню-тема
    menu = [(0, 0, 4, 7), (-3, 0, 3, 7), (-7, 0, 4, 7), (-5, 0, 4, 7)]
    make_track("music_menu", 104, 60, major, menu, 2, 5, drums=1, lead_vol=0.10)


if __name__ == "__main__":
    main()
