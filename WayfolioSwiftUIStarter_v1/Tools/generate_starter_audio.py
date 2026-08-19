#!/usr/bin/env python3
"""Generate Wayfolio's original, dependency-free starter audio cues."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


RATE = 44_100
ROOT = Path(__file__).resolve().parents[1] / "Wayfolio" / "Resources" / "Audio"


def envelope(t: float, duration: float, attack: float = 0.01, release: float = 0.08) -> float:
    return min(1.0, t / attack) * min(1.0, (duration - t) / release)


def write_cue(relative_path: str, samples: list[float]) -> None:
    path = ROOT / relative_path
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max(1.0, max(abs(sample) for sample in samples) / 0.92)
    frames = b"".join(
        struct.pack("<h", int(max(-1, min(1, sample / peak)) * 32_767))
        for sample in samples
    )
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(frames)


def ui_chime(descending: bool) -> list[float]:
    duration = 0.18
    first, second = ((660, 494) if descending else (494, 740))
    samples = []
    for index in range(int(RATE * duration)):
        t = index / RATE
        frequency = first if t < 0.065 else second
        local = t if t < 0.065 else t - 0.065
        tone = math.sin(2 * math.pi * frequency * local)
        shimmer = 0.28 * math.sin(2 * math.pi * frequency * 2 * local)
        samples.append(0.26 * (tone + shimmer) * envelope(t, duration, 0.004, 0.075))
    return samples


def wooden_creak() -> list[float]:
    random.seed(14)
    duration = 2.35
    samples = []
    smoothed_noise = 0.0
    for index in range(int(RATE * duration)):
        t = index / RATE
        smoothed_noise += 0.025 * (random.uniform(-1, 1) - smoothed_noise)
        bend = 95 + 42 * math.sin(math.pi * min(t / duration, 1))
        groan = math.sin(2 * math.pi * bend * t + 2.3 * math.sin(2 * math.pi * 1.4 * t))
        grain = smoothed_noise * (0.35 + 0.65 * abs(math.sin(2 * math.pi * 3.1 * t)))
        pulse = 0.55 + 0.45 * math.sin(math.pi * min(t / duration, 1))
        samples.append(0.32 * (0.72 * groan + grain) * pulse * envelope(t, duration, 0.08, 0.3))
    return samples


def forest_ambience() -> list[float]:
    random.seed(83)
    duration = 20.0
    count = int(RATE * duration)
    samples = [0.0] * count
    wind = 0.0
    for index in range(count):
        t = index / RATE
        wind += 0.0022 * (random.uniform(-1, 1) - wind)
        breeze = 0.055 * wind * (1.2 + 0.55 * math.sin(2 * math.pi * t / 7.0))
        insects = 0.009 * math.sin(2 * math.pi * 3470 * t) * (0.5 + 0.5 * math.sin(2 * math.pi * 0.17 * t))
        samples[index] = breeze + insects

    for start, frequency in [(1.8, 1850), (5.4, 2240), (9.7, 1720), (14.2, 2050), (17.1, 1940)]:
        for offset in range(int(RATE * 0.32)):
            index = int(start * RATE) + offset
            if index >= count:
                break
            t = offset / RATE
            chirp = math.sin(2 * math.pi * (frequency + 620 * t) * t)
            samples[index] += 0.045 * chirp * envelope(t, 0.32, 0.012, 0.12)

    crossfade = int(RATE * 1.0)
    for index in range(crossfade):
        blend = index / crossfade
        value = samples[index] * blend + samples[count - crossfade + index] * (1 - blend)
        samples[index] = value
        samples[count - crossfade + index] = value
    return samples


def exploration_music() -> list[float]:
    duration = 24.0
    samples = [0.0] * int(RATE * duration)
    chords = [
        (146.83, 220.00, 293.66),
        (130.81, 196.00, 261.63),
        (164.81, 246.94, 329.63),
        (146.83, 220.00, 293.66),
    ]
    chord_duration = duration / len(chords)
    for index in range(len(samples)):
        t = index / RATE
        chord_index = min(int(t / chord_duration), len(chords) - 1)
        local = t - chord_index * chord_duration
        tone = 0.0
        for voice, frequency in enumerate(chords[chord_index]):
            drift = 1 + 0.0015 * math.sin(2 * math.pi * (0.08 + voice * 0.015) * t)
            tone += math.sin(2 * math.pi * frequency * drift * t + voice * 0.7) / (voice + 1)
        swell = 0.45 + 0.55 * math.sin(math.pi * local / chord_duration)
        bell_step = int((t % 3.0) / 0.75)
        bell_frequency = chords[chord_index][bell_step % 3] * 2
        bell_local = t % 0.75
        bell = math.sin(2 * math.pi * bell_frequency * bell_local) * math.exp(-5.5 * bell_local)
        samples[index] = 0.085 * tone * swell + 0.035 * bell

    crossfade = int(RATE * 1.5)
    for index in range(crossfade):
        blend = index / crossfade
        value = samples[index] * blend + samples[-crossfade + index] * (1 - blend)
        samples[index] = value
        samples[-crossfade + index] = value
    return samples


def main() -> None:
    write_cue("UI/navigation_select.wav", ui_chime(descending=False))
    write_cue("UI/navigation_back.wav", ui_chime(descending=True))
    write_cue("SFX/wood_bridge_creak.wav", wooden_creak())
    write_cue("Ambience/hemlock_forest.wav", forest_ambience())
    write_cue("Music/forest_exploration.wav", exploration_music())


if __name__ == "__main__":
    main()
