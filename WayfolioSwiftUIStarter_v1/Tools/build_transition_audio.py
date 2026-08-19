#!/usr/bin/env python3
"""Build presentation-only scene transition cues from the CC0 RPG pack."""

from io import BytesIO
from pathlib import Path
import argparse
import zipfile
import numpy as np
import soundfile as sf


MAPPINGS = {
    "transition_enter_building": ["inventory/wood-small.wav", "inventory/cloth.wav"],
    "transition_camp_setup": ["inventory/cloth-heavy.wav", "inventory/wood-small.wav"],
    "transition_danger_reveal": ["misc/random4.wav", "battle/sword-unsheathe2.wav"],
    "transition_combat_start": ["battle/sword-unsheathe.wav", "battle/swing3.wav"],
    "transition_victory": ["interface/interface2.wav", "inventory/metal-ringing.wav"],
    "transition_rest": ["inventory/cloth-heavy.wav", "interface/interface5.wav"],
    "transition_departure": ["inventory/cloth.wav", "inventory/chainmail1.wav"],
    "transition_arrival": ["inventory/wood-small.wav", "interface/interface4.wav"],
}


def decode(archive: zipfile.ZipFile, suffix: str) -> tuple[np.ndarray, int]:
    name = next(name for name in archive.namelist() if name.endswith(suffix) and not name.startswith("__MACOSX"))
    data, rate = sf.read(BytesIO(archive.read(name)), dtype="float32", always_2d=True)
    return data.mean(axis=1), rate


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.archive) as archive:
        for cue, sources in MAPPINGS.items():
            parts = []
            rate = None
            for source in sources:
                audio, current_rate = decode(archive, source)
                if rate is None:
                    rate = current_rate
                if current_rate != rate:
                    positions = np.linspace(0, len(audio) - 1, round(len(audio) * rate / current_rate))
                    audio = np.interp(positions, np.arange(len(audio)), audio).astype(np.float32)
                parts.extend((audio, np.zeros(round(rate * 0.08), dtype=np.float32)))
            result = np.concatenate(parts)
            peak = max(float(np.max(np.abs(result))), 0.001)
            result *= min(0.8 / peak, 1.6)
            fade = min(round(rate * 0.02), len(result) // 4)
            result[:fade] *= np.linspace(0, 1, fade)
            result[-fade:] *= np.linspace(1, 0, fade)
            sf.write(args.output / f"{cue}.wav", result, rate, subtype="PCM_16")


if __name__ == "__main__":
    main()
