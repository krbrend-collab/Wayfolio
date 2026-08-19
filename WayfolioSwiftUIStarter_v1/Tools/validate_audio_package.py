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


def resolve_creature_cue(properties: dict, profiles: dict) -> str | None:
    behavior = properties.get("behavior")
    override = profiles["creature_overrides"].get(properties.get("creature_id"), {})
    if override.get("cue"): return override["cue"]
    if override.get("profile"):
        cue = profiles["profiles"].get(override["profile"], {}).get(behavior)
        if cue: return cue
    for composite in profiles["composite_profiles"]:
        selectors = {key:value for key, value in composite.items() if key != "cue"}
        if all(properties.get(key) == value for key, value in selectors.items()): return composite["cue"]
    cue = profiles["body_form_profiles"].get(properties.get("body_form"), {}).get(behavior)
    if cue: return cue
    cue = profiles["profiles"].get(properties.get("creature_type"), {}).get(behavior)
    if cue: return cue
    return profiles["profiles"][profiles["fallback_profile"]].get(behavior)


def validate_voice_registry(registry: dict, errors: list[str]) -> None:
    profiles = registry.get("profiles", {})
    if registry.get("registry_version") != 1: fail(errors, "Unexpected voice registry version")
    if registry.get("default_profile") not in profiles: fail(errors, "Unknown default voice profile")
    identities: set[str] = set(profiles)
    for profile_id, profile in profiles.items():
        if not profile.get("display_name"): fail(errors, f"{profile_id}: missing display name")
        if profile.get("status") not in {"draft", "approved"}: fail(errors, f"{profile_id}: invalid status")
        browser = profile.get("browser_voice", {})
        if not 0.5 <= browser.get("rate", -1) <= 2: fail(errors, f"{profile_id}: invalid browser rate")
        if not 0 <= browser.get("pitch", -1) <= 2: fail(errors, f"{profile_id}: invalid browser pitch")
        if not isinstance(browser.get("voice_index"), int) or browser["voice_index"] < 0:
            fail(errors, f"{profile_id}: invalid browser voice index")
        for alias in profile.get("aliases", []):
            normalized = alias.lower()
            if normalized in identities: fail(errors, f"Duplicate voice identity: {alias}")
            identities.add(normalized)
    for name, modifier in registry.get("performance_modifiers", {}).items():
        if not 0.5 <= modifier.get("rate_multiplier", -1) <= 2:
            fail(errors, f"{name}: invalid performance rate multiplier")
        if not -1 <= modifier.get("pitch_delta", -2) <= 1:
            fail(errors, f"{name}: invalid performance pitch delta")


def main() -> int:
    errors: list[str] = []
    catalog = load_json("AudioCueCatalog.json")
    profiles = load_json("CreatureAudioProfiles.json")
    voice_registry = load_json("CharacterVoiceProfiles.json")
    fixture = load_json("hemlock_presentation_fixture.json")
    creature_fixture = load_json("creature_resolution_fixture.json")
    load_json("PresentationEvent.schema.json")
    load_json("CharacterVoiceProfiles.schema.json")
    validate_voice_registry(voice_registry, errors)

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
    for form_name, behavior_map in profiles["body_form_profiles"].items():
        for behavior, cue_id in behavior_map.items():
            if cue_id not in cue_ids: fail(errors, f"{form_name}.{behavior} references unknown cue {cue_id}")
    for composite in profiles["composite_profiles"]:
        if composite["cue"] not in cue_ids: fail(errors, f"Composite references unknown cue {composite['cue']}")
        if composite["body_form"] not in profiles["body_form_profiles"]:
            fail(errors, f"Composite references unknown body form {composite['body_form']}")
    if profiles["fallback_profile"] not in profiles["profiles"]: fail(errors, "Unknown fallback profile")
    for case in creature_fixture["cases"]:
        actual = resolve_creature_cue(case["input"], profiles)
        if actual != case["expected_cue"]:
            fail(errors, f"{case['name']}: expected {case['expected_cue']}, resolved {actual}")

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
    print(f"Audio package valid: {len(cue_ids)} cues, {len(profiles['profiles'])} type profiles, {len(profiles['body_form_profiles'])} body forms, {len(voice_registry['profiles'])} character voices, {len(creature_fixture['cases'])} creature cases, {len(fixture['events'])} presentation events.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
