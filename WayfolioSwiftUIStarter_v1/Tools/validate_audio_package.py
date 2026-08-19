#!/usr/bin/env python3
"""Validate Wayfolio cue metadata, event fixtures, and bundled PCM WAV assets."""

from __future__ import annotations

import audioop
import json
import sys
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "Specifications" / "Audio"
RESOURCES = ROOT / "Wayfolio" / "Resources"


def load_json(name: str) -> object:
    with (SPEC / name).open(encoding="utf-8") as source:
        return json.load(source)


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def validate_wav(path: Path, loop: bool, errors: list[str]) -> None:
    try:
        with wave.open(str(path), "rb") as source:
            channels, width, rate, frames = source.getparams()[:4]
            payload = source.readframes(frames)
    except (wave.Error, OSError) as error:
        return fail(errors, f"Unreadable WAV {path}: {error}")

    if channels not in (1, 2): fail(errors, f"{path}: expected mono or stereo")
    if width != 2: fail(errors, f"{path}: expected 16-bit PCM")
    if rate != 44_100: fail(errors, f"{path}: expected 44100 Hz")
    if not frames: fail(errors, f"{path}: contains no audio frames")
    if audioop.max(payload, width) >= 32_767: fail(errors, f"{path}: clipped sample detected")

    if loop and frames > rate // 10:
        window = min(rate // 100, frames // 4) * channels * width
        start_rms = audioop.rms(payload[:window], width)
        end_rms = audioop.rms(payload[-window:], width)
        if abs(start_rms - end_rms) > 2_500:
            fail(errors, f"{path}: loop boundary energy differs too much")


def validate_event(event: dict, cue_ids: set[str], errors: list[str]) -> None:
    required = {"protocol", "event_id", "sequence", "session_code", "scene_id", "audience", "event"}
    missing = required - event.keys()
    if missing: fail(errors, f"Event {event.get('event_id', '?')} missing {sorted(missing)}")
    if event.get("protocol") != "wayfolio.presentation.v1": fail(errors, "Unexpected protocol version")
    audience = event.get("audience", {})
    if audience.get("kind") not in {"shared", "player", "players"}: fail(errors, "Invalid audience")
    if audience.get("kind") == "player" and not audience.get("player_id"): fail(errors, "Private event lacks player_id")
    payload = event.get("event", {})
    if payload.get("cue") and payload["cue"] not in cue_ids: fail(errors, f"Unknown cue {payload['cue']}")
    for key in ("volume", "intensity"):
        if key in payload and not 0 <= payload[key] <= 1: fail(errors, f"{key} outside 0...1")


def main() -> int:
    errors: list[str] = []
    catalog = load_json("AudioCueCatalog.json")
    profiles = load_json("CreatureAudioProfiles.json")
    fixture = load_json("hemlock_presentation_fixture.json")
    load_json("PresentationEvent.schema.json")

    cue_ids: set[str] = set()
    for cue in catalog["cues"]:
        cue_id = cue["id"]
        if cue_id in cue_ids: fail(errors, f"Duplicate cue ID: {cue_id}")
        cue_ids.add(cue_id)
        if cue["bus"] not in catalog["buses"]: fail(errors, f"Invalid bus for {cue_id}")
        if cue["audience"] not in {"shared", "player"}: fail(errors, f"Invalid audience for {cue_id}")
        if not 0 <= cue["default_volume"] <= 1: fail(errors, f"Invalid volume for {cue_id}")
        path = RESOURCES / cue["file"]
        if not path.is_file():
            fail(errors, f"Missing asset for {cue_id}: {path}")
        elif path.suffix.lower() == ".wav":
            validate_wav(path, cue["loop"], errors)

    for profile_name, behavior_map in profiles["profiles"].items():
        for behavior, cue_id in behavior_map.items():
            if cue_id not in cue_ids: fail(errors, f"{profile_name}.{behavior} references unknown cue {cue_id}")
    if profiles["fallback_profile"] not in profiles["profiles"]: fail(errors, "Unknown fallback profile")

    sequences = []
    event_ids = set()
    for event in fixture["events"]:
        validate_event(event, cue_ids, errors)
        payload = event.get("event", {})
        if payload.get("type") == "creature_sound":
            override = profiles["creature_overrides"].get(payload.get("creature_id"), {})
            profile_name = override.get("profile", payload.get("creature_type", profiles["fallback_profile"]))
            profile = profiles["profiles"].get(profile_name, profiles["profiles"][profiles["fallback_profile"]])
            if payload.get("behavior") not in profile:
                fail(errors, f"No {payload.get('behavior')} sound for creature profile {profile_name}")
        if event["event_id"] in event_ids: fail(errors, f"Duplicate event ID {event['event_id']}")
        event_ids.add(event["event_id"])
        sequences.append(event["sequence"])
    if sequences != sorted(sequences) or len(sequences) != len(set(sequences)):
        fail(errors, "Fixture sequences must be unique and ascending")

    if errors:
        print("Audio package validation failed:", file=sys.stderr)
        for error in errors: print(f"- {error}", file=sys.stderr)
        return 1
    print(f"Audio package valid: {len(cue_ids)} cues, {len(profiles['profiles'])} creature profiles, {len(fixture['events'])} fixture events.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
