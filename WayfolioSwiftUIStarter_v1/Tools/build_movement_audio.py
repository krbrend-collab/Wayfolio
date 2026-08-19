#!/usr/bin/env python3
"""Build short, iOS-safe movement sequences from the licensed OGG source pack."""

from pathlib import Path
import argparse
import numpy as np
import soundfile as sf


def mono(path: Path, target_rate: int = 24000) -> np.ndarray:
    audio, rate = sf.read(path, dtype="float32", always_2d=True)
    audio = audio.mean(axis=1)
    if rate != target_rate:
        positions = np.linspace(0, len(audio) - 1, round(len(audio) * target_rate / rate))
        audio = np.interp(positions, np.arange(len(audio)), audio).astype(np.float32)
    return audio


def sequence(source: Path, category: str, *, pace: float = 0.34) -> np.ndarray:
    paths = sorted((source / category).glob("*.ogg"))[:4]
    if not paths:
        raise FileNotFoundError(f"No recordings for {category}")
    gap = np.zeros(round(24000 * pace), dtype=np.float32)
    parts = []
    for index, path in enumerate(paths):
        step = mono(path)
        step *= 0.78 + index * 0.035
        parts.extend((step, gap))
    result = np.concatenate(parts)
    peak = max(float(np.max(np.abs(result))), 0.001)
    result = result * min(0.82 / peak, 1.8)
    fade = min(480, len(result) // 4)
    result[:fade] *= np.linspace(0, 1, fade)
    result[-fade:] *= np.linspace(1, 0, fade)
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    sources = {
        "wood": "wood", "grass": "grass", "dirt": "grass", "gravel": "gravel",
        "stone": "tile", "metal": "metal", "water": "water", "mud": "water",
        "snow": "grass", "bones": "bones",
    }
    for surface, category in sources.items():
        audio = sequence(args.source, category)
        if surface in {"dirt", "mud", "snow"}:
            # Gentle smoothing differentiates related surfaces and removes brittle highs.
            width = {"dirt": 5, "mud": 11, "snow": 17}[surface]
            audio = np.convolve(audio, np.ones(width) / width, mode="same").astype(np.float32)
        sf.write(args.output / f"movement_{surface}.wav", audio, 24000, subtype="PCM_16")


if __name__ == "__main__":
    main()
