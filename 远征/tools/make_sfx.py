#!/usr/bin/env python3
# make_sfx.py —— 合成《远征》全套音效（程序生成：无外部素材、无版权问题）
# 风格目标：木质 / 羊皮纸 / 克制——短促、不喧哗；UI 音峰值压低一档，战斗音允许更脏更重。
# 全部 44.1kHz / 16-bit / 单声道 WAV，写入 assets/audio/（同名覆盖，可反复生成）。
# 用法：python tools/make_sfx.py
# 生成后让 Godot 重新导入：godot --headless --path . --import
from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
rng = np.random.default_rng(20260918)


# ---------- 基础工具 ----------
def n_of(sec: float) -> int:
    return max(1, int(sec * SR))


def env(n: int, tau: float, attack: float = 0.002) -> np.ndarray:
    """快速起音 + 指数衰减（tau 单位秒）。短音都靠它，防爆音、防长尾。"""
    e = np.exp(-np.arange(n) / (tau * SR))
    na = min(n, max(1, int(attack * SR)))
    e[:na] *= np.linspace(0.0, 1.0, na)
    return e


def sine(f: float, n: int, phase: float = 0.0) -> np.ndarray:
    return np.sin(2.0 * np.pi * f * np.arange(n) / SR + phase)


def noise(n: int) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, n)


def lp(x: np.ndarray, fc: float) -> np.ndarray:
    """一阶低通（砍掉高频毛刺）"""
    a = float(np.exp(-2.0 * np.pi * fc / SR))
    y = np.empty_like(x)
    acc = 0.0
    for i in range(x.size):
        acc = (1.0 - a) * x[i] + a * acc
        y[i] = acc
    return y


def hp(x: np.ndarray, fc: float) -> np.ndarray:
    """一阶高通（去掉低频隆隆，留"沙/擦"的味道）"""
    return x - lp(x, fc)


def bell(f: float, n: int, tau: float,
         partials=(1.0, 2.0, 3.01), gains=(1.0, 0.34, 0.10)) -> np.ndarray:
    """钟/木琴感：整数倍泛音 + 指数衰减"""
    out = np.zeros(n)
    for p, g in zip(partials, gains):
        out += g * sine(f * p, n)
    return out * env(n, tau)


def metal(f: float, n: int, tau: float) -> np.ndarray:
    """金属撞击：非谐波泛音（金币/暴击的"亮"）"""
    out = np.zeros(n)
    for p, g in zip((1.0, 1.34, 2.37, 3.42, 4.51), (1.0, 0.7, 0.5, 0.34, 0.2)):
        out += g * sine(f * p, n)
    return out * env(n, tau, attack=0.001)


def thud(f: float, n: int, tau: float, drop: float = 0.45) -> np.ndarray:
    """闷击：基频随时间下滑（拳/锤的落地感）"""
    freq = f * (1.0 - drop * np.linspace(0.0, 1.0, n) ** 1.6)
    phase = np.cumsum(2.0 * np.pi * freq / SR)
    return np.sin(phase) * env(n, tau, attack=0.001)


def sweep(f0: float, f1: float, n: int) -> np.ndarray:
    """对数扫频正弦（"起势/掠空"）"""
    freq = np.geomspace(f0, f1, n)
    phase = np.cumsum(2.0 * np.pi * freq / SR)
    return np.sin(phase)


def brass(f: float, n: int, tau: float, bright: float = 0.55) -> np.ndarray:
    """铜管感：谐波堆叠 + 缓起音（胜利/升级收尾用）"""
    out = np.zeros(n)
    for k in range(1, 9):
        out += (bright ** (k - 1)) * sine(f * k, n) / k
    return out * env(n, tau, attack=0.012)


def mix_at(base: np.ndarray, part: np.ndarray, at: float, gain: float = 1.0) -> np.ndarray:
    out = base.copy()
    i = int(at * SR)
    if i >= out.size:
        return out
    j = min(out.size, i + part.size)
    out[i:j] += part[: j - i] * gain
    return out


def save(name: str, x: np.ndarray, peak: float) -> None:
    x = np.asarray(x, dtype=np.float64)
    m = float(np.max(np.abs(x))) or 1.0
    x = x / m * peak
    nf = min(x.size, int(0.006 * SR))
    x[-nf:] *= np.linspace(1.0, 0.0, nf)   # 结尾淡出，防"咔"声
    pcm = np.clip(x * 32767.0, -32768, 32767).astype(np.int16)
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"  {path.name:18s} {x.size / SR * 1000:6.0f} ms   peak {peak:.2f}")


# ---------- UI 音（峰值 0.5~0.6：频繁点击不刺耳） ----------
def ui_click() -> np.ndarray:
    n = n_of(0.085)
    x = 0.9 * sine(1500, n) * env(n, 0.016, attack=0.0008)
    x += 0.5 * sine(3200, n) * env(n, 0.008, attack=0.0005)
    x += 0.35 * hp(noise(n), 1800) * env(n, 0.006, attack=0.0003)
    return x


def ui_open() -> np.ndarray:
    n = n_of(0.24)
    x = 0.55 * sweep(320, 760, n) * env(n, 0.075, attack=0.004)
    x += 0.30 * lp(noise(n), 1400) * env(n, 0.05, attack=0.002)
    return x


def ui_close() -> np.ndarray:
    n = n_of(0.18)
    x = 0.6 * sweep(640, 260, n) * env(n, 0.055, attack=0.003)
    x += 0.25 * thud(220, n, 0.06)
    return x


def ui_page() -> np.ndarray:
    n = n_of(0.16)
    paper = hp(noise(n), 1200)
    shape = np.sin(np.linspace(0.0, np.pi, n)) ** 1.2   # 两端弱中间强：像纸被捻起再落下
    return 0.9 * paper * shape


def ui_confirm() -> np.ndarray:
    n = n_of(0.30)
    x = mix_at(np.zeros(n), bell(784, n_of(0.16), 0.085), 0.0, 1.0)     # G5
    x = mix_at(x, bell(1046, n_of(0.18), 0.095), 0.085, 0.9)            # C6
    return x


def ui_cancel() -> np.ndarray:
    n = n_of(0.26)
    a = lp(bell(659, n_of(0.14), 0.07), 2200)
    b = lp(bell(494, n_of(0.18), 0.09), 1800)
    return mix_at(mix_at(np.zeros(n), a, 0.0, 1.0), b, 0.08, 0.9)


def ui_locked() -> np.ndarray:
    n = n_of(0.20)
    x = 0.8 * thud(180, n, 0.07)
    x += 0.4 * lp(noise(n), 900) * env(n, 0.03, attack=0.001)
    return x


# ---------- 奖励音（峰值 0.7~0.8：值得听见） ----------
def coin() -> np.ndarray:
    n = n_of(0.22)
    x = mix_at(np.zeros(n), metal(1975, n_of(0.12), 0.055), 0.0, 0.9)
    x = mix_at(x, metal(2637, n_of(0.14), 0.07), 0.055, 0.8)
    return x


def reward() -> np.ndarray:
    n = n_of(0.62)
    x = np.zeros(n)
    for i, f in enumerate((523, 659, 784, 1046)):
        part = bell(f, n_of(0.30), 0.16) + 0.25 * brass(f, n_of(0.30), 0.12)
        x = mix_at(x, part, 0.075 * i, 0.85)
    return x


def level_up() -> np.ndarray:
    n = n_of(0.82)
    x = np.zeros(n)
    for i, f in enumerate((523, 659, 784, 988, 1046)):
        x = mix_at(x, bell(f, n_of(0.40), 0.20), 0.07 * i, 0.9)
    x = mix_at(x, brass(1046, n_of(0.5), 0.30), 0.28, 0.5)
    return x


# ---------- 战斗音（峰值 0.8：该重就重） ----------
def hit_light() -> np.ndarray:
    n = n_of(0.10)
    x = 0.8 * hp(noise(n), 900) * env(n, 0.020, attack=0.0005)
    x += 0.7 * thud(320, n, 0.03)
    return x


def hit_heavy() -> np.ndarray:
    n = n_of(0.20)
    x = 0.9 * thud(190, n, 0.065)
    x += 0.55 * lp(noise(n), 1600) * env(n, 0.03, attack=0.0006)
    x += 0.35 * thud(95, n, 0.09)
    return x


def hit_crit() -> np.ndarray:
    n = n_of(0.30)
    x = metal(680, n, 0.10)
    x += 0.7 * sweep(600, 2400, n) * env(n, 0.05, attack=0.001)
    x += 0.5 * hp(noise(n), 2500) * env(n, 0.04, attack=0.0006)
    return x


def skill_cast() -> np.ndarray:
    n = n_of(0.34)
    x = 0.8 * sweep(280, 1500, n) * env(n, 0.13, attack=0.01)
    x += 0.35 * hp(noise(n), 1800) * env(n, 0.08, attack=0.004)
    x += 0.30 * sine(660, n) * env(n, 0.16, attack=0.05)
    return x


def boss_warn() -> np.ndarray:
    n = n_of(0.55)
    d1 = thud(85, n_of(0.22), 0.10, drop=0.35)
    d2 = thud(72, n_of(0.30), 0.14, drop=0.30)
    x = mix_at(np.zeros(n), d1, 0.0, 1.0)
    x = mix_at(x, d2, 0.22, 0.95)
    x += 0.2 * lp(noise(n), 300) * env(n, 0.08, attack=0.002)
    return x


def low_hp() -> np.ndarray:
    n = n_of(0.50)
    h1 = thud(68, n_of(0.12), 0.05, drop=0.4)
    h2 = thud(62, n_of(0.16), 0.07, drop=0.4)
    x = mix_at(np.zeros(n), h1, 0.0, 1.0)
    x = mix_at(x, h2, 0.18, 0.8)
    return x


def victory() -> np.ndarray:
    n = n_of(1.02)
    x = np.zeros(n)
    for i, f in enumerate((523, 659, 784)):
        x = mix_at(x, brass(f, n_of(0.35), 0.14), 0.10 * i, 0.8)
    chord = sum(brass(f, n_of(0.6), 0.30) for f in (523, 659, 784, 1046)) / 2.4
    x = mix_at(x, chord, 0.30, 1.0)
    return x


def defeat() -> np.ndarray:
    n = n_of(0.92)
    a = lp(brass(392, n_of(0.30), 0.16), 1200)
    b = lp(brass(294, n_of(0.50), 0.32), 900)
    x = mix_at(np.zeros(n), a, 0.0, 0.85)
    x = mix_at(x, b, 0.24, 0.95)
    return x


# ---------- 清单 ----------
UI_SFX = [ui_click, ui_open, ui_close, ui_page, ui_confirm, ui_cancel, ui_locked]
REWARD_SFX = [coin, reward, level_up]
BATTLE_SFX = [hit_light, hit_heavy, hit_crit, skill_cast, boss_warn, low_hp, victory, defeat]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    print(f"输出目录：{OUT}")
    print("[UI]")
    for f in UI_SFX:
        save(f.__name__, f(), 0.55)
    print("[奖励]")
    for f in REWARD_SFX:
        save(f.__name__, f(), 0.75)
    print("[战斗]")
    for f in BATTLE_SFX:
        save(f.__name__, f(), 0.8)
    total = len(UI_SFX) + len(REWARD_SFX) + len(BATTLE_SFX)
    print(f"完成：{total} 个音效。接着跑 godot --headless --path . --import 让引擎导入。")


if __name__ == "__main__":
    main()
