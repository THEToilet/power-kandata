#!/usr/bin/env python3
"""パワーカンダタの BGM と効果音を、ファミコン風の音色で合成して audio/ に書き出す。

  python tools/make_audio.py        （numpy と scipy が必要）

音階は「都節（みやこぶし）」= E F A B C。地獄っぽい和の響きになる。
極楽（クリア）だけは明るい長調にしている。
"""
import os
import wave

import numpy as np
from scipy.signal import butter, lfilter

SR = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
rng = np.random.default_rng(7)

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def midi(name):
    # "E4" -> 64
    n, o = name[:-1], int(name[-1])
    return 12 * (o + 1) + NOTE[n]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def tl(sec):
    return np.arange(int(sec * SR)) / SR


# ------------------------------------------------------------ 音源
def square(f, t, duty=0.5):
    ph = np.cumsum(np.broadcast_to(f, t.shape) / SR) if np.ndim(f) else f * t
    return np.where((ph % 1.0) < duty, 1.0, -1.0)


def tri(f, t):
    ph = np.cumsum(np.broadcast_to(f, t.shape) / SR) if np.ndim(f) else f * t
    return 4.0 * np.abs((ph % 1.0) - 0.5) - 1.0


def sine(f, t):
    ph = np.cumsum(np.broadcast_to(f, t.shape) / SR) if np.ndim(f) else f * t
    return np.sin(2 * np.pi * ph)


def noise(n):
    return rng.uniform(-1, 1, n)


def lp(x, fc, order=2):
    b, a = butter(order, min(fc / (SR / 2), 0.99), "low")
    return lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = butter(order, min(fc / (SR / 2), 0.99), "high")
    return lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], "band")
    return lfilter(b, a, x)


def env(n, a=0.005, d=0.1, s=0.6, r=0.05, hold=None):
    """ADSR。hold = 鍵盤を押している長さ（秒）。"""
    hold = n / SR - r if hold is None else hold
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-6), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-6)))
    rel = t > hold
    e[rel] = e[rel] * np.exp(-(t[rel] - hold) / max(r, 1e-6))
    return e


def decay(n, tau):
    return np.exp(-np.arange(n) / SR / tau)


# ------------------------------------------------------------ 楽器
def pluck(m, dur, vol=0.3, duty=0.25, tau=0.18):
    """琴っぽい、はじく音"""
    t = tl(dur)
    f = hz(m)
    x = 0.6 * square(f, t, duty) + 0.4 * tri(f * 2, t)
    return lp(x, 3500) * decay(len(t), tau) * vol


def lead(m, dur, vol=0.22, duty=0.5, vib=True):
    """主旋律: 矩形波＋遅れてかかるビブラート"""
    t = tl(dur + 0.08)
    f = hz(m) * np.ones_like(t)
    if vib:
        f = f * (1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.15) / 0.2, 0, 1))
    x = 0.7 * square(f, t, duty) + 0.3 * square(f * 1.003, t, 0.25)
    return lp(x, 4200) * env(len(t), 0.004, 0.12, 0.65, 0.05, hold=dur) * vol


def bass(m, dur, vol=0.3):
    t = tl(dur)
    x = tri(hz(m), t)
    return x * env(len(t), 0.003, 0.08, 0.7, 0.02, hold=dur - 0.02) * vol


def taiko(vol=0.6, low=1.0):
    """大太鼓: 音程の下がるサイン波＋皮をたたく雑音"""
    t = tl(0.5)
    f = (110 * low) * np.exp(-t * 6) + 48 * low
    x = sine(f, t) * decay(len(t), 0.16)
    x += lp(noise(len(t)), 900) * decay(len(t), 0.02) * 0.6
    return np.tanh(x * 1.6) * vol


def shime(vol=0.15):
    """締太鼓: 乾いた高い音"""
    t = tl(0.08)
    x = bp(noise(len(t)), 1800, 6000) * decay(len(t), 0.015)
    x += sine(620 * np.exp(-t * 20) + 380, t) * decay(len(t), 0.02) * 0.6
    return x * vol


def bell(m, dur=2.5, vol=0.25):
    """お寺の鐘っぽい、うなる響き"""
    t = tl(dur)
    f = hz(m)
    x = np.zeros_like(t)
    for ratio, amp, tau in [(1.0, 1.0, 1.2), (2.0, 0.5, 0.8), (2.76, 0.4, 0.5), (5.4, 0.25, 0.25), (1.004, 0.6, 1.4)]:
        x += amp * sine(f * ratio, t) * decay(len(t), tau * dur / 2.5)
    return x * vol / 2.0


def chime(m, dur=0.9, vol=0.2):
    t = tl(dur)
    f = hz(m)
    x = sine(f, t) + 0.35 * sine(f * 3, t) * decay(len(t), 0.15)
    return x * decay(len(t), dur / 3) * vol


def pad(ms, dur, vol=0.1):
    t = tl(dur)
    x = np.zeros_like(t)
    for m in ms:
        x += tri(hz(m), t) + 0.5 * tri(hz(m) * 1.004, t)
    x = lp(x, 2000)
    a = np.clip(t / 0.6, 0, 1) * np.clip((dur - t) / 0.8, 0, 1)
    return x * a * vol / len(ms)


# ------------------------------------------------------------ 楽譜まわり
class Track:
    def __init__(self, sec, tail=3.0):
        self.loop = int(sec * SR)
        self.buf = np.zeros(self.loop + int(tail * SR))

    def add(self, at, x):
        i = int(at * SR)
        n = min(len(x), len(self.buf) - i)
        if n > 0:
            self.buf[i:i + n] += x[:n]

    def render(self, loop=True):
        out = self.buf.copy()
        if loop:   # はみ出した余韻を頭に重ねて、つなぎ目を消す
            tail = out[self.loop:]
            out = out[:self.loop]
            out[:len(tail)] += tail
        return out


def seq(line):
    """ "E4:2 F4:1 -:2" -> [(midi or None, 長さ)] """
    out = []
    for tok in line.split():
        n, l = tok.split(":")
        out.append((None if n == "-" else midi(n), float(l)))
    return out


def master(x, peak=0.89):
    x = np.tanh(x * 1.1)
    return x / max(1e-9, np.max(np.abs(x))) * peak


def save(name, x, peak=0.89):
    os.makedirs(OUT, exist_ok=True)
    x = master(x, peak)
    if not (name.startswith("bgm") or name == "se_rumble"):   # ループしない音は、最後を短くフェードして「プチッ」を防ぐ
        k = min(len(x) // 4, int(0.012 * SR))
        x[-k:] *= np.linspace(1, 0, k)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", name, "%.2fs" % (len(x) / SR))


# ============================================================ BGM
def bgm_play():
    """プレイ中: 太鼓が刻む、都節の速い曲（16小節ループ）"""
    bpm = 150
    e8 = 60 / bpm / 2
    bar = e8 * 8
    tr = Track(bar * 16)
    melody = (
        # A
        "E4:2 F4:1 A4:1 B4:3 A4:1  C5:2 B4:1 A4:1 F4:2 E4:2  E4:1 F4:1 A4:2 B4:2 C5:1 B4:1  A4:4 -:4 "
        "E5:2 C5:1 B4:1 A4:2 B4:2  C5:1 B4:1 A4:1 F4:1 E4:4  F4:2 A4:2 B4:2 C5:2  B4:6 -:2 "
        # B（高く、せわしなく）
        "E5:1 E5:1 F5:1 E5:1 C5:2 B4:2  A4:1 B4:1 C5:2 B4:2 A4:2  E5:1 E5:1 F5:1 A5:1 F5:2 E5:2  C5:4 B4:4 "
        "A4:2 C5:2 B4:2 F4:2  E4:2 F4:2 A4:2 B4:2  C5:2 B4:1 A4:1 F4:2 A4:2  E4:6 -:2"
    )
    at = 0.0
    for m, l in seq(melody):
        if m is not None:
            tr.add(at, lead(m, l * e8 * 0.92))
            tr.add(at + e8 * 3, lead(m, l * e8 * 0.9, vol=0.05))   # こだま
        at += l * e8
    roots = ["E2", "E2", "F2", "E2", "E2", "E2", "A2", "B2", "E2", "E2", "F2", "E2", "C3", "C3", "B2", "B2"]
    pat = [0, 0, 12, 0, 7, 0, 12, 7]
    arp = [12, 19, 24, 19, 16, 19, 24, 28]
    for b, r in enumerate(roots):
        rm = midi(r)
        for i in range(8):
            t0 = b * bar + i * e8
            tr.add(t0, bass(rm + pat[i], e8 * 0.85))
            if b >= 8:   # 後半は琴の分散和音も重ねて盛り上げる
                tr.add(t0, pluck(rm + arp[i], e8 * 1.5, vol=0.07))
            # 太鼓: 1拍目と3拍目にドン、裏で締太鼓
            if i in (0, 4) or (i == 7 and b % 2 == 1) or (i == 6 and b % 4 == 3):
                tr.add(t0, taiko(0.55 if i == 0 else 0.42))
            tr.add(t0, shime(0.10 if i % 2 else 0.05))
        if b % 4 == 3:   # 4小節ごとのフィル
            for k in range(4):
                tr.add(b * bar + 6 * e8 + k * e8 / 2, shime(0.14))
    return tr.render()


def bgm_title():
    """タイトル: ゆっくり、鐘と琴と低いうなり（8小節ループ）"""
    bpm = 72
    e8 = 60 / bpm / 2
    bar = e8 * 8
    tr = Track(bar * 8, tail=4.0)
    mel = ("E4:4 F4:2 A4:2  B4:6 A4:2  C5:4 B4:2 A4:2  F4:8 "
           "E4:4 A4:2 B4:2  C5:4 E5:4  F5:2 E5:2 C5:2 B4:2  E4:8")
    at = 0.0
    for m, l in seq(mel):
        if m is not None:
            tr.add(at, pluck(m, l * e8 + 0.6, vol=0.26, tau=0.5))
            tr.add(at + 0.012, pluck(m + 12, l * e8, vol=0.05, tau=0.2))
        at += l * e8
    for b in range(8):
        tr.add(b * bar, pad([midi("E2"), midi("B2")], bar + 0.6, vol=0.22))
        if b % 4 == 0:
            tr.add(b * bar, bell(midi("E3"), 4.0, vol=0.32))
        if b % 2 == 1:
            tr.add(b * bar + 6 * e8, taiko(0.25, low=0.8))
    return tr.render()


def bgm_heaven():
    """極楽（クリア後）: やわらかい長調の分散和音（4小節ループ）"""
    bpm = 88
    e8 = 60 / bpm / 2
    bar = e8 * 8
    tr = Track(bar * 4, tail=3.0)
    chords = [["E4", "G#4", "B4", "D#5"], ["C#4", "E4", "G#4", "B4"], ["A3", "C#4", "E4", "G#4"], ["B3", "D#4", "F#4", "A4"]]
    for b, ch in enumerate(chords):
        ms = [midi(c) for c in ch]
        tr.add(b * bar, pad(ms, bar + 0.8, vol=0.18))
        order = [0, 1, 2, 3, 2, 1, 2, 3]
        for i in range(8):
            tr.add(b * bar + i * e8, chime(ms[order[i]] + 12, 0.9, vol=0.12))
        tr.add(b * bar, bass(ms[0] - 12, bar * 0.95, vol=0.18))
    return tr.render()


def jingle_clear():
    """極楽に着いた！: 上がっていくアルペジオ＋鐘"""
    tr = Track(4.5, tail=0.0)
    run = ["E4", "G#4", "B4", "E5", "G#5", "B5", "E6"]
    for i, n in enumerate(run):
        tr.add(i * 0.07, lead(midi(n), 0.12, vol=0.18, vib=False))
    t0 = len(run) * 0.07 + 0.05
    for n in ["E5", "G#5", "B5"]:
        tr.add(t0, lead(midi(n), 1.6, vol=0.14))
    tr.add(t0, bass(midi("E3"), 1.6, vol=0.3))
    tr.add(t0, taiko(0.5))
    tr.add(t0, bell(midi("E5"), 3.5, vol=0.3))
    for i in range(10):
        tr.add(t0 + 0.2 + i * 0.13, chime(midi(["B6", "G#6", "E6", "B5"][i % 4]), 0.6, vol=0.08))
    return tr.render(loop=False)


def jingle_gameover():
    """GAME OVER: 沈んでいく下降音型"""
    tr = Track(3.5, tail=0.0)
    notes = [("E4", 0.0), ("C4", 0.28), ("B3", 0.56), ("F3", 0.84)]
    for n, at in notes:
        tr.add(at, pluck(midi(n), 0.9, vol=0.3, tau=0.4))
    tr.add(1.15, pluck(midi("E3"), 2.0, vol=0.32, tau=0.9))
    tr.add(1.15, bell(midi("E2"), 2.3, vol=0.35))
    tr.add(1.15, taiko(0.45, low=0.7))
    return tr.render(loop=False)


# ============================================================ 効果音
def se_shout(clutch=False):
    t = tl(0.9 if clutch else 0.5)
    n = len(t)
    boom = sine(95 * np.exp(-t * 5) + 38, t) * decay(n, 0.28 if clutch else 0.2)
    burst = lp(noise(n), 2500) * decay(n, 0.09)
    f = 240 * np.exp(-t * 2.5) + 100
    roar = np.tanh(3 * (square(f, t, 0.4) + 0.5 * square(f * 1.5, t, 0.3))) * decay(n, 0.18)
    x = 1.0 * boom + 0.6 * burst + 0.35 * lp(roar, 2200)
    if clutch:   # 金色のきらめきを重ねる
        x = x * 1.2
        for i, m in enumerate(["E6", "B6", "E7"]):
            s = np.zeros(n)
            c = chime(midi(m), 0.7, 0.25)
            k = int((0.03 + i * 0.06) * SR)
            s[k:k + len(c)] = c[:n - k]
            x += s
    return np.tanh(x * 1.3)


def se_kick():
    t = tl(0.09)
    f = 520 * np.exp(t * 8)
    return square(f, t, 0.25) * decay(len(t), 0.03) * 0.5


def se_catch():
    t = tl(0.35)
    n = len(t)
    thud = sine(160 * np.exp(-t * 15) + 60, t) * decay(n, 0.06)
    twang = tri(110 * (1 + 0.04 * np.exp(-t * 20)), t) * decay(n, 0.15)
    return 0.9 * thud + 0.5 * twang + 0.2 * lp(noise(n), 1200) * decay(n, 0.015)


def se_grab():
    t = tl(0.18)
    n = len(t)
    return 0.4 * square(440 * (1 + 0.02 * np.exp(-t * 30)), t, 0.25) * decay(n, 0.05) + 0.3 * hp(noise(n), 3000) * decay(n, 0.006)


def se_snap():
    t = tl(0.6)
    n = len(t)
    crack = hp(noise(n), 2500) * decay(n, 0.012) * 1.4
    twang = square(900 * np.exp(-t * 6) + 120, t, 0.3) * decay(n, 0.12) * 0.45
    thump = sine(80, t) * decay(n, 0.08) * 0.6
    return crack + lp(twang, 3500) + thump


def se_fall():
    t = tl(1.4)
    f = 1100 * np.exp(-t * 1.2) + 180
    f = f * (1 + 0.03 * np.sin(2 * np.pi * 7 * t))
    return sine(f, t) * np.clip(t / 0.05, 0, 1) * decay(len(t), 0.6) * 0.35


def se_hit_fire():
    t = tl(0.5)
    n = len(t)
    whoosh = lp(noise(n), 1400) * decay(n, 0.15)
    crackle = hp(noise(n), 2000) * (rng.uniform(0, 1, n) > 0.985) * decay(n, 0.2) * 3
    thump = sine(70, t) * decay(n, 0.1)
    return whoosh + 0.4 * crackle + 0.7 * thump


def se_hit_rock():
    t = tl(0.45)
    n = len(t)
    crunch = lp(noise(n), 900) * decay(n, 0.1) * 1.3
    thump = sine(90 * np.exp(-t * 8) + 45, t) * decay(n, 0.12)
    grit = bp(noise(n), 1500, 4000) * decay(n, 0.04) * 0.4
    return np.tanh(1.5 * (crunch + thump + grit))


def se_burn():
    t = tl(0.6)
    n = len(t)
    sizzle = hp(noise(n), 3000) * (0.6 + 0.4 * rng.uniform(0, 1, n)) * np.clip(t / 0.03, 0, 1) * decay(n, 0.25)
    return 0.6 * sizzle + 0.4 * lp(noise(n), 500) * decay(n, 0.1)


def se_throw():
    t = tl(0.4)
    n = len(t)
    a = np.sin(np.pi * np.clip(t / 0.4, 0, 1)) ** 2
    return bp(noise(n), 400, 1600) * a * 0.8


def se_warn():
    t = tl(0.2)
    x = np.zeros(len(t))
    for k in (0.0, 0.09):
        i = int(k * SR)
        b = square(1320, tl(0.06), 0.5) * decay(int(0.06 * SR), 0.03)
        x[i:i + len(b)] += b
    return x * 0.35


def se_leap():
    t = tl(0.22)
    n = len(t)
    a = np.sin(np.pi * t / 0.22)
    return bp(noise(n), 900, 3000) * a * 0.5 + sine(300 + 900 * t / 0.22, t) * a * 0.12


def se_start():
    tr = Track(0.6, tail=0.0)
    for i, n in enumerate(["E5", "A5", "B5", "E6"]):
        tr.add(i * 0.06, lead(midi(n), 0.08 if i < 3 else 0.3, vol=0.4, vib=False))
    return tr.render(loop=False)


def se_tick():
    t = tl(0.05)
    return square(1760, t, 0.5) * decay(len(t), 0.015) * 0.4


def se_rank_new():
    tr = Track(1.0, tail=0.0)
    for i, n in enumerate(["B5", "E6", "G#6", "B6"]):
        tr.add(i * 0.08, lead(midi(n), 0.1 if i < 3 else 0.5, vol=0.35, vib=i == 3))
    tr.add(0.24, chime(midi("E7"), 0.7, 0.2))
    return tr.render(loop=False)


def se_heart():
    t = tl(0.2)
    return sine(55 * (1 + 0.5 * np.exp(-t * 30)), t) * decay(len(t), 0.06)


def se_whiff():
    """空振りの蹴り: 短い「ヒュッ」"""
    t = tl(0.18)
    n = len(t)
    a = np.sin(np.pi * np.clip(t / 0.18, 0, 1)) ** 1.5
    f = 2400 * np.exp(-t * 8) + 600
    sw = bp(noise(n), 700, 3500) * a
    return sw * 0.9 + sine(f, t) * a * 0.08


def se_rumble():
    """マグマの地鳴り（2秒ループ）"""
    sec = 2.0
    n = int(sec * SR)
    x = lp(noise(n + SR), 120, order=4)
    x = x[SR // 2: SR // 2 + n + SR // 4]
    fade = SR // 4   # 端をなめらかに重ねてループさせる
    head = x[:fade] * np.linspace(0, 1, fade)
    body = x[fade:fade + n].copy()
    body[-fade:] = body[-fade:] * np.linspace(1, 0, fade) + head
    lfo = 0.75 + 0.25 * np.sin(2 * np.pi * np.arange(n) / n * 3)
    return body * lfo


if __name__ == "__main__":
    save("bgm_title", bgm_title(), 0.8)
    save("bgm_play", bgm_play(), 0.8)
    save("bgm_heaven", bgm_heaven(), 0.7)
    save("jingle_clear", jingle_clear(), 0.85)
    save("jingle_gameover", jingle_gameover(), 0.8)
    save("se_shout", se_shout())
    save("se_shout_clutch", se_shout(True))
    save("se_kick", se_kick(), 0.6)
    save("se_catch", se_catch(), 0.8)
    save("se_grab", se_grab(), 0.5)
    save("se_snap", se_snap())
    save("se_fall", se_fall(), 0.6)
    save("se_hit_fire", se_hit_fire())
    save("se_hit_rock", se_hit_rock())
    save("se_burn", se_burn(), 0.6)
    save("se_throw", se_throw(), 0.5)
    save("se_warn", se_warn(), 0.45)
    save("se_leap", se_leap(), 0.4)
    save("se_start", se_start(), 0.7)
    save("se_tick", se_tick(), 0.4)
    save("se_rank_new", se_rank_new(), 0.7)
    save("se_heart", se_heart(), 0.8)
    save("se_rumble", se_rumble(), 0.8)
    save("se_whiff", se_whiff(), 0.5)   # 追加分は最後に（乱数の順番を変えず、既存の音を作り直しても同じになるように）
