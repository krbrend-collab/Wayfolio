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


def write_cue(relative_path: str, samples: list[float], target_rms: float | None = None) -> None:
    path = ROOT / relative_path
    path.parent.mkdir(parents=True, exist_ok=True)
    if relative_path.startswith("Ambience/") and "/Details/" not in relative_path:
        edge = min(int(RATE * 0.08), len(samples) // 4)
        for index in range(edge):
            fade = index / max(1, edge - 1)
            samples[index] *= fade
            samples[-1 - index] *= fade
    if target_rms:
        rms = math.sqrt(sum(sample * sample for sample in samples) / max(1, len(samples)))
        if rms:
            gain = min(64.0, target_rms / rms)
            samples = [sample * gain for sample in samples]
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


def tone_sequence(frequencies: tuple[float, ...], note_duration: float = 0.065, amplitude: float = 0.22) -> list[float]:
    duration = note_duration * len(frequencies) + 0.07
    samples = []
    for index in range(int(RATE * duration)):
        t = index / RATE
        note_index = min(int(t / note_duration), len(frequencies) - 1)
        local = t - note_index * note_duration
        frequency = frequencies[note_index]
        decay = math.exp(-8 * local)
        fundamental = math.sin(2 * math.pi * frequency * local)
        overtone = 0.2 * math.sin(2 * math.pi * frequency * 2.01 * local)
        samples.append(amplitude * (fundamental + overtone) * decay * envelope(t, duration, 0.003, 0.06))
    return samples


def parchment_tap(bright: bool = False) -> list[float]:
    random.seed(31 if bright else 30)
    duration = 0.14
    samples = []
    smoothed = 0.0
    frequency = 920 if bright else 610
    for index in range(int(RATE * duration)):
        t = index / RATE
        smoothed += 0.18 * (random.uniform(-1, 1) - smoothed)
        body = 0.6 * smoothed + 0.4 * math.sin(2 * math.pi * frequency * t)
        samples.append(0.2 * body * math.exp(-28 * t) * envelope(t, duration, 0.002, 0.04))
    return samples


def magical_reveal() -> list[float]:
    duration = 0.85
    notes = (587.33, 739.99, 880.00, 1174.66)
    samples = []
    for index in range(int(RATE * duration)):
        t = index / RATE
        value = 0.0
        for note_index, frequency in enumerate(notes):
            start = note_index * 0.12
            if t >= start:
                local = t - start
                value += math.sin(2 * math.pi * frequency * local) * math.exp(-4.6 * local)
        shimmer = math.sin(2 * math.pi * (1400 + 900 * t) * t) * math.exp(-3.2 * t)
        samples.append(0.095 * value + 0.025 * shimmer)
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


def creature_call(kind: str) -> list[float]:
    seeds = {"beast": 101, "avian": 102, "reptile": 103, "insect": 104, "ooze": 105,
             "construct": 106, "undead": 107, "dragon": 108, "plant": 109, "elemental": 110}
    random.seed(seeds[kind])
    durations = {"beast": 0.7, "avian": 0.55, "reptile": 1.1, "insect": 0.8, "ooze": 0.9,
                 "construct": 0.75, "undead": 1.35, "dragon": 1.8, "plant": 1.0, "elemental": 1.1}
    duration = durations[kind]
    samples = []
    noise = 0.0
    for index in range(int(RATE * duration)):
        t = index / RATE
        raw = random.uniform(-1, 1)
        smoothing = 0.04 if kind in {"beast", "dragon", "ooze"} else 0.2
        noise += smoothing * (raw - noise)
        if kind == "beast":
            value = math.sin(2 * math.pi * (270 - 90 * t) * t + 0.5 * math.sin(2 * math.pi * 9 * t))
        elif kind == "avian":
            value = math.sin(2 * math.pi * (1500 + 1800 * t) * t) * (0.4 + 0.6 * abs(math.sin(2 * math.pi * 7 * t)))
        elif kind == "reptile":
            value = noise * (0.55 + 0.45 * math.sin(2 * math.pi * 18 * t))
        elif kind == "insect":
            value = math.sin(2 * math.pi * 3100 * t) * (1 if math.sin(2 * math.pi * 28 * t) > 0 else 0.08)
        elif kind == "ooze":
            value = noise + 0.5 * math.sin(2 * math.pi * (85 + 18 * math.sin(2 * math.pi * 3 * t)) * t)
        elif kind == "construct":
            value = 0.7 * math.sin(2 * math.pi * 180 * t) + noise * math.exp(-22 * (t % 0.24))
        elif kind == "undead":
            value = noise + 0.35 * math.sin(2 * math.pi * 115 * t) * math.sin(2 * math.pi * 2.2 * t)
        elif kind == "dragon":
            value = 0.65 * math.sin(2 * math.pi * (92 - 22 * t) * t) + 0.6 * noise
        elif kind == "plant":
            value = noise * (0.45 + 0.55 * abs(math.sin(2 * math.pi * 4.5 * t)))
        else:
            value = noise + 0.35 * math.sin(2 * math.pi * (620 + 420 * t) * t)
        samples.append(0.28 * value * envelope(t, duration, 0.025, 0.16))
    return samples


def physical_effect(kind: str) -> list[float]:
    seeds = {"footsteps": 201, "door": 202, "splash": 203, "dice": 204}
    random.seed(seeds[kind])
    duration = {"footsteps": 1.4, "door": 0.65, "splash": 0.9, "dice": 1.0}[kind]
    samples = [0.0] * int(RATE * duration)
    events = {
        "footsteps": [0.05, 0.48, 0.91, 1.28],
        "door": [0.04, 0.22],
        "splash": [0.03, 0.18, 0.34],
        "dice": [0.02, 0.13, 0.25, 0.38, 0.55, 0.73],
    }[kind]
    for start in events:
        length = 0.18 if kind != "splash" else 0.3
        for offset in range(int(RATE * length)):
            index = int(start * RATE) + offset
            if index >= len(samples): break
            t = offset / RATE
            noise = random.uniform(-1, 1)
            resonance = math.sin(2 * math.pi * ({"footsteps":120,"door":240,"splash":520,"dice":780}[kind]) * t)
            samples[index] += 0.22 * (0.65 * noise + 0.35 * resonance) * math.exp(-18 * t)
    return samples


def unusual_creature_sound(kind: str) -> list[float]:
    seeds = {name: 300 + index for index, name in enumerate((
        "small_timid_startle", "large_predator_warning", "slime_curious_move",
        "slime_hostile_attack", "spirit_mournful_appear", "spirit_hostile_whisper",
        "skeletal_idle_rattle", "swarm_agitated", "crystalline_alert",
        "fungal_spore_release", "shell_armored_move", "floating_arcane_pulse",
    ))}
    random.seed(seeds[kind])
    duration = {
        "small_timid_startle": 0.38, "large_predator_warning": 1.35,
        "slime_curious_move": 0.85, "slime_hostile_attack": 0.72,
        "spirit_mournful_appear": 1.65, "spirit_hostile_whisper": 1.15,
        "skeletal_idle_rattle": 0.95, "swarm_agitated": 1.05,
        "crystalline_alert": 1.2, "fungal_spore_release": 1.1,
        "shell_armored_move": 1.15, "floating_arcane_pulse": 1.4,
    }[kind]
    samples = []
    smooth = 0.0
    for index in range(int(RATE * duration)):
        t = index / RATE
        raw = random.uniform(-1, 1)
        smooth += 0.055 * (raw - smooth)
        if kind == "small_timid_startle":
            value = math.sin(2 * math.pi * (1250 + 850 * t) * t) * math.exp(-8 * t)
        elif kind == "large_predator_warning":
            value = 0.72 * math.sin(2 * math.pi * (82 + 8 * math.sin(2 * math.pi * 4 * t)) * t) + 0.4 * smooth
        elif kind == "slime_curious_move":
            value = 0.65 * smooth + math.sin(2 * math.pi * (105 + 35 * math.sin(2 * math.pi * 2.5 * t)) * t)
        elif kind == "slime_hostile_attack":
            value = smooth + 0.7 * math.sin(2 * math.pi * (180 - 95 * t) * t)
        elif kind == "spirit_mournful_appear":
            value = 0.55 * math.sin(2 * math.pi * (410 - 120 * t) * t) + 0.32 * math.sin(2 * math.pi * 615 * t)
        elif kind == "spirit_hostile_whisper":
            value = smooth * (0.5 + 0.5 * math.sin(2 * math.pi * 13 * t)) + 0.25 * math.sin(2 * math.pi * 155 * t)
        elif kind == "skeletal_idle_rattle":
            impulse = math.exp(-45 * (t % 0.17))
            value = impulse * (0.7 * raw + 0.3 * math.sin(2 * math.pi * 920 * t))
        elif kind == "swarm_agitated":
            value = math.sin(2 * math.pi * 2650 * t) * (0.35 + 0.65 * abs(math.sin(2 * math.pi * 31 * t))) + 0.35 * smooth
        elif kind == "crystalline_alert":
            value = sum(math.sin(2 * math.pi * frequency * t) for frequency in (740, 1110, 1485)) / 3
        elif kind == "fungal_spore_release":
            pops = math.exp(-55 * (t % 0.21)) * raw
            value = 0.65 * smooth + 0.5 * pops
        elif kind == "shell_armored_move":
            impact = math.exp(-35 * (t % 0.29))
            value = impact * (0.6 * math.sin(2 * math.pi * 210 * t) + 0.45 * raw)
        else:
            pulse = 0.45 + 0.55 * math.sin(2 * math.pi * 2.2 * t)
            value = pulse * (0.55 * math.sin(2 * math.pi * 520 * t) + 0.3 * math.sin(2 * math.pi * 780 * t))
        samples.append(0.25 * value * envelope(t, duration, 0.018, 0.14))
    return samples


def tavern_ambience() -> list[float]:
    random.seed(205)
    duration = 16.0
    samples = []
    murmur = 0.0
    for index in range(int(RATE * duration)):
        t = index / RATE
        murmur += 0.003 * (random.uniform(-1, 1) - murmur)
        room = 0.05 * murmur * (1.1 + 0.4 * math.sin(2 * math.pi * t / 5.2))
        fire = 0.012 * random.uniform(-1, 1) * (0.4 + 0.6 * abs(math.sin(2 * math.pi * 3.7 * t)))
        samples.append(room + fire)
    crossfade = int(RATE)
    for index in range(crossfade):
        blend = index / crossfade
        value = samples[index] * blend + samples[-crossfade + index] * (1 - blend)
        samples[index] = value
        samples[-crossfade + index] = value
    return samples


def forest_ambience() -> list[float]:
    random.seed(83)
    duration = 20.0
    count = int(RATE * duration)
    samples = [0.0] * count
    wind = leaves = 0.0
    for index in range(count):
        t = index / RATE
        raw = random.uniform(-1, 1)
        wind += 0.0014 * (raw - wind)
        leaves += 0.018 * (raw - leaves)
        slow_swell = 0.72 + 0.28 * math.sin(2 * math.pi * t / 8.5)
        breeze = 0.072 * wind * slow_swell
        canopy = 0.012 * leaves * (0.45 + 0.55 * abs(math.sin(2 * math.pi * t / 3.8)))
        samples[index] = breeze + canopy

    # Sparse, soft woodland calls stay below 1.2 kHz. The previous loop used a
    # continuous 3.47 kHz insect tone and sharp 1.7–2.8 kHz chirps, which were
    # fatiguing and could be especially unpleasant for animals in the room.
    for start, frequency in [(3.1, 540), (8.8, 690), (15.4, 585)]:
        for offset in range(int(RATE * 0.72)):
            index = int(start * RATE) + offset
            if index >= count:
                break
            t = offset / RATE
            call = math.sin(2 * math.pi * (frequency + 55 * math.sin(2 * math.pi * 1.4 * t)) * t)
            warmth = 0.35 * math.sin(2 * math.pi * frequency * 0.5 * t)
            samples[index] += 0.018 * (call + warmth) * envelope(t, 0.72, 0.08, 0.3)

    crossfade = int(RATE * 1.0)
    for index in range(crossfade):
        blend = index / crossfade
        value = samples[index] * blend + samples[count - crossfade + index] * (1 - blend)
        samples[index] = value
        samples[count - crossfade + index] = value
    return samples


def location_ambience(kind: str) -> list[float]:
    """Create restrained, seamless beds intended to sit beneath music and voice."""
    kinds = ("festival", "market", "river", "village", "cave", "ruins", "coast", "rain")
    random.seed(500 + kinds.index(kind))
    duration = 18.0
    count = int(RATE * duration)
    samples = [0.0] * count
    low = mid = high = 0.0
    for index in range(count):
        t = index / RATE
        raw = random.uniform(-1, 1)
        low += 0.0015 * (raw - low)
        mid += 0.012 * (raw - mid)
        high += 0.18 * (raw - high)
        if kind == "festival":
            value = 0.045 * low * (1.5 + math.sin(2 * math.pi * t / 4.7)) + 0.004 * mid
        elif kind == "market":
            value = 0.05 * low * (1.4 + 0.45 * math.sin(2 * math.pi * t / 6.1)) + 0.006 * mid
        elif kind == "river":
            ripple = math.sin(2 * math.pi * (390 + 45 * math.sin(2 * math.pi * 0.13 * t)) * t)
            value = 0.028 * mid + 0.009 * high + 0.006 * ripple
        elif kind == "village":
            value = 0.042 * low * (1.2 + 0.35 * math.sin(2 * math.pi * t / 7.3)) + 0.004 * mid
        elif kind == "cave":
            value = 0.05 * low + 0.008 * math.sin(2 * math.pi * 74 * t) * (0.5 + 0.5 * math.sin(2 * math.pi * 0.08 * t))
        elif kind == "ruins":
            gust = 0.55 + 0.45 * math.sin(2 * math.pi * t / 8.2)
            value = 0.065 * low * gust + 0.004 * mid
        elif kind == "coast":
            wave = max(0, math.sin(2 * math.pi * t / 5.8)) ** 2
            value = 0.035 * mid * (0.8 + 1.8 * wave) + 0.025 * low
        else:
            patter = max(0, high) * (0.65 + 0.35 * math.sin(2 * math.pi * 0.21 * t))
            value = 0.032 * mid + 0.025 * patter + 0.025 * low
        samples[index] = value

    crossfade = int(RATE * 1.25)
    for index in range(crossfade):
        blend = index / crossfade
        value = samples[index] * blend + samples[-crossfade + index] * (1 - blend)
        samples[index] = value
        samples[-crossfade + index] = value
    return samples


def ambient_detail(kind: str) -> list[float]:
    kinds = (
        "mug_clink", "tavern_laugh", "festival_cheer", "festival_bells",
        "market_vendor", "cart_wheels", "river_splash", "river_bird",
        "village_door", "village_dog", "cave_drip", "cave_stone",
        "ruins_groan", "ruins_bird", "coast_gull", "harbor_rope",
        "rain_thunder", "rain_runoff",
    )
    random.seed(600 + kinds.index(kind))
    duration = 0.7 if kind not in {"tavern_laugh", "festival_cheer", "market_vendor", "rain_thunder", "rain_runoff"} else 1.8
    samples = []
    smooth = 0.0
    for index in range(int(RATE * duration)):
        t = index / RATE
        raw = random.uniform(-1, 1)
        smooth += 0.035 * (raw - smooth)
        if kind in {"mug_clink", "festival_bells"}:
            frequency = 1450 if kind == "mug_clink" else 880
            value = sum(math.sin(2 * math.pi * frequency * ratio * t) for ratio in (1, 1.49, 2.08)) / 3 * math.exp(-6 * t)
        elif kind in {"tavern_laugh", "festival_cheer", "market_vendor"}:
            pulse = 0.45 + 0.55 * abs(math.sin(2 * math.pi * (3.2 if kind == "festival_cheer" else 2.1) * t))
            value = smooth * pulse + 0.2 * math.sin(2 * math.pi * (190 + 35 * math.sin(2 * math.pi * 2 * t)) * t)
        elif kind == "cart_wheels":
            value = smooth + 0.35 * math.sin(2 * math.pi * (105 + 22 * math.sin(2 * math.pi * 3 * t)) * t)
        elif kind in {"river_splash", "rain_runoff"}:
            value = smooth + 0.35 * raw * math.exp(-4 * t)
        elif kind in {"river_bird", "ruins_bird", "coast_gull"}:
            base = {"river_bird":1800, "ruins_bird":1150, "coast_gull":920}[kind]
            value = math.sin(2 * math.pi * (base + 420 * t) * t) * (0.5 + 0.5 * math.sin(2 * math.pi * 3.4 * t))
        elif kind in {"village_door", "cave_stone", "ruins_groan", "harbor_rope"}:
            base = {"village_door":170, "cave_stone":120, "ruins_groan":82, "harbor_rope":145}[kind]
            value = 0.65 * smooth + 0.55 * math.sin(2 * math.pi * (base - 18 * t) * t)
        elif kind == "village_dog":
            value = math.sin(2 * math.pi * (310 - 75 * t) * t) * (1 if t < 0.24 or 0.38 < t < 0.58 else 0.04)
        elif kind == "cave_drip":
            value = (math.sin(2 * math.pi * 1250 * t) + 0.4 * math.sin(2 * math.pi * 1810 * t)) * math.exp(-12 * t)
        elif kind == "rain_thunder":
            value = 0.8 * smooth + 0.5 * math.sin(2 * math.pi * (52 - 8 * t) * t)
        else:
            value = smooth
        samples.append(0.24 * value * envelope(t, duration, 0.012, 0.16))
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
    write_cue("UI/entry_open.wav", tone_sequence((440, 659, 880), 0.055))
    write_cue("UI/filter_change.wav", parchment_tap(bright=True))
    write_cue("UI/search_clear.wav", tone_sequence((760, 540), 0.045, 0.16))
    write_cue("UI/note_new.wav", tone_sequence((392, 523, 659), 0.06))
    write_cue("UI/note_save.wav", tone_sequence((523, 659, 784), 0.075, 0.24))
    write_cue("UI/note_cancel.wav", tone_sequence((523, 392), 0.06, 0.16))
    write_cue("UI/map_reset.wav", tone_sequence((330, 440, 330), 0.05, 0.18))
    write_cue("UI/discovery_reveal.wav", magical_reveal())
    write_cue("UI/creatures_open.wav", tone_sequence((220, 293, 370), 0.07))
    write_cue("UI/botanicals_open.wav", tone_sequence((349, 440, 587), 0.07, 0.18))
    write_cue("UI/alchemy_open.wav", tone_sequence((466, 622, 831), 0.065, 0.2))
    write_cue("UI/settings_open.wav", parchment_tap(bright=False))
    write_cue("UI/profile_open.wav", tone_sequence((392, 494), 0.07, 0.17))
    write_cue("SFX/wood_bridge_creak.wav", wooden_creak())
    write_cue("SFX/footsteps_wood.wav", physical_effect("footsteps"))
    write_cue("SFX/door_latch.wav", physical_effect("door"))
    write_cue("SFX/water_splash.wav", physical_effect("splash"))
    write_cue("SFX/dice_roll.wav", physical_effect("dice"))
    write_cue("SFX/spell_chime.wav", magical_reveal())
    for creature_type in ("beast", "avian", "reptile", "insect", "ooze", "construct", "undead", "dragon", "plant", "elemental"):
        write_cue(f"SFX/Creature/{creature_type}_alert.wav", creature_call(creature_type))
    for profile in (
        "small_timid_startle", "large_predator_warning", "slime_curious_move",
        "slime_hostile_attack", "spirit_mournful_appear", "spirit_hostile_whisper",
        "skeletal_idle_rattle", "swarm_agitated", "crystalline_alert",
        "fungal_spore_release", "shell_armored_move", "floating_arcane_pulse",
    ):
        write_cue(f"SFX/Creature/Form/{profile}.wav", unusual_creature_sound(profile))
    write_cue("Ambience/hemlock_forest.wav", forest_ambience(), target_rms=0.055)
    write_cue("Ambience/hemlock_tavern.wav", tavern_ambience(), target_rms=0.055)
    for location in ("festival", "market", "river", "village", "cave", "ruins", "coast", "rain"):
        write_cue(f"Ambience/{location}.wav", location_ambience(location), target_rms=0.055)
    for detail in (
        "mug_clink", "tavern_laugh", "festival_cheer", "festival_bells",
        "market_vendor", "cart_wheels", "river_splash", "river_bird",
        "village_door", "village_dog", "cave_drip", "cave_stone",
        "ruins_groan", "ruins_bird", "coast_gull", "harbor_rope",
        "rain_thunder", "rain_runoff",
    ):
        write_cue(f"Ambience/Details/{detail}.wav", ambient_detail(detail))
    write_cue("Music/forest_exploration.wav", exploration_music())


if __name__ == "__main__":
    main()
