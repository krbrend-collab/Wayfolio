#!/usr/bin/env python3
"""Build a short encounter cue from recorded creature vocalizations."""

from __future__ import annotations

import argparse
import struct
import wave
from array import array
from pathlib import Path


def read_mono(path: Path) -> tuple[int, array]:
    with wave.open(str(path), "rb") as reader:
        if reader.getsampwidth() != 2:
            raise ValueError("Input must be 16-bit PCM WAV")
        rate = reader.getframerate()
        channels = reader.getnchannels()
        frames = reader.readframes(reader.getnframes())
    values = array("h")
    values.frombytes(frames)
    if channels == 1:
        return rate, values
    mono = array("h")
    for index in range(0, len(values), channels):
        mono.append(round(sum(values[index : index + channels]) / channels))
    return rate, mono


def compose(first: Path, second: Path, destination: Path) -> None:
    rate, opening = read_mono(first)
    second_rate, response = read_mono(second)
    if second_rate != rate:
        source = response
        target_count = round(len(source) * rate / second_rate)
        response = array("h", (
            source[min(len(source) - 1, round(index * second_rate / rate))]
            for index in range(target_count)
        ))

    # A brief pause followed by a lower-volume response reads as an encounter
    # vocalization instead of a UI notification.
    pause = array("h", [0]) * int(rate * 0.28)
    response = array("h", (round(value * 0.72) for value in response))
    result = opening + pause + response
    minimum_frames = int(rate * 1.65)
    if len(result) < minimum_frames:
        result.extend([0] * (minimum_frames - len(result)))

    fade_frames = min(int(rate * 0.22), len(result))
    for index in range(fade_frames):
        position = len(result) - fade_frames + index
        result[position] = round(result[position] * (1.0 - index / fade_frames))

    destination.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(destination), "wb") as writer:
        writer.setnchannels(1)
        writer.setsampwidth(2)
        writer.setframerate(rate)
        writer.writeframes(result.tobytes())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("first", type=Path)
    parser.add_argument("second", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    compose(args.first, args.second, args.destination)
