#!/usr/bin/env python3
"""Prepare a compact, loopable mono WAV from a PCM field recording."""

from __future__ import annotations

import argparse
import math
import struct
import wave
from array import array
from pathlib import Path


def decode_sample(data: bytes, width: int) -> int:
    if width == 2:
        return struct.unpack("<h", data)[0]
    if width == 3:
        value = int.from_bytes(data, "little", signed=False)
        if value & 0x800000:
            value -= 1 << 24
        return value >> 8
    raise ValueError(f"Unsupported PCM sample width: {width}")


def prepare(source: Path, destination: Path, start: float, duration: float, cutoff: float) -> None:
    with wave.open(str(source), "rb") as reader:
        channels = reader.getnchannels()
        rate = reader.getframerate()
        width = reader.getsampwidth()
        if channels < 1 or width not in (2, 3):
            raise ValueError("Expected 16- or 24-bit PCM WAV audio")
        reader.setpos(min(int(start * rate), reader.getnframes()))
        frames = reader.readframes(min(int(duration * rate), reader.getnframes() - reader.tell()))

    frame_width = channels * width
    samples = array("h")
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / rate)
    filtered = 0.0
    for offset in range(0, len(frames) - frame_width + 1, frame_width):
        total = 0
        for channel in range(channels):
            begin = offset + channel * width
            total += decode_sample(frames[begin : begin + width], width)
        mono = total / channels
        filtered += alpha * (mono - filtered)
        samples.append(max(-32768, min(32767, round(filtered))))

    # 48 kHz sources become compact 24 kHz mono files while retaining the
    # full useful spectrum after the safety filter.
    output_rate = rate // 2
    samples = array("h", samples[::2])
    fade_count = min(int(output_rate * 2.0), len(samples) // 4)
    for index in range(fade_count):
        blend = index / fade_count
        mixed = round(samples[index] * blend + samples[-fade_count + index] * (1.0 - blend))
        samples[index] = max(-32768, min(32767, mixed))

    destination.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(destination), "wb") as writer:
        writer.setnchannels(1)
        writer.setsampwidth(2)
        writer.setframerate(output_rate)
        writer.writeframes(samples.tobytes())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--start", type=float, default=0.0)
    parser.add_argument("--duration", type=float, default=90.0)
    parser.add_argument("--cutoff", type=float, default=9000.0)
    args = parser.parse_args()
    prepare(args.source, args.destination, args.start, args.duration, args.cutoff)
