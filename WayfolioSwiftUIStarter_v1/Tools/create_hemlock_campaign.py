#!/usr/bin/env python3
"""Create the clean Hemlock Contract 1.1 development campaign package."""

from __future__ import annotations

import argparse
import importlib.util
import json
import re
import sys
from pathlib import Path


def load_engine(path: Path):
    spec = importlib.util.spec_from_file_location("aidm_campaign", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load campaign engine: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def public_journal_entry(value: str) -> str:
    """Remove the legacy sentence that restates a DM-only warning."""
    return value.split(" A private warning", 1)[0].strip()


def write_text(path: Path, value: str) -> None:
    path.write_text(value, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", required=True, type=Path)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--world", required=True, type=Path)
    parser.add_argument("--campaign", required=True, type=Path)
    args = parser.parse_args()

    engine = load_engine(args.engine.resolve())
    source = json.loads(args.source.read_text(encoding="utf-8"))
    world_fallback = json.loads(args.world.read_text(encoding="utf-8"))
    world = source.get("openPlay", {}).get("worldState") or world_fallback
    character = source.get("characterState", {})
    public_journal = [
        public_journal_entry(entry) for entry in character.get("journal", [])
    ]
    root = args.campaign.resolve()
    if root.exists():
        entries = list(root.iterdir())
        allowed_empty_directories = {"books", "checkpoints", "migrations"}
        if any(
            entry.name not in allowed_empty_directories
            or not entry.is_dir()
            or any(entry.iterdir())
            for entry in entries
        ):
            raise RuntimeError(f"Campaign target is not empty: {root}")

    root.mkdir(parents=True, exist_ok=True)
    for directory in ("books", "checkpoints", "migrations"):
        (root / directory).mkdir(exist_ok=True)

    campaign_id = "wayfolio-hemlock-development"
    created = engine.utc_now()
    campaign_time = {
        "axis": "hemlock-local",
        "period": world.get("time", {}).get("period", "evening"),
        "elapsed_minutes": world.get("time", {}).get("elapsed_minutes", 0),
    }

    write_text(
        root / "AI_DM_RUNTIME_PRIMER.md",
        """# Hemlock Development Runtime Primer

This package is the authoritative development campaign state for Wayfolio.

- Play is open-ended. Never invent, select, or rewrite a player character's voluntary action, dialogue, belief, emotion, or intent.
- Preserve each declaration exactly and give it a stable unique turn ID before resolving it.
- The DM may propose consequences, checks, NPC reactions, discoveries, and world changes; gameplay state changes only through a validated atomic transaction.
- Renn Hazel is the player character. Soren Hazel and Lupin are present companions controlled as NPCs by the DM.
- Public projections must never expose sealed clues or private declarations.
- Physical dice and shared-screen digital dice are both valid when their recorded outcome is explicit.
- This is a non-production development package. Repeated simulator tests and undone actions are audit material, not canon.
""",
    )
    write_text(
        root / "STORY_SO_FAR.md",
        """# Story So Far

Renn Hazel, accompanied by Soren Hazel and Lupin, is at the Southern Hemlock Bridge during the evening. Blue motes gather beneath the southern rail and move against the wind. Tracks end where the blue light begins, and a wary Crown Hare has been glimpsed near the fern line.

The current development scene is open play. No prewritten player decision is pending. Renn's Wayfolio contains the imported inventory, discoveries, and field-journal notes from the previous development save. One clue remains sealed for the DM and is not included in public projections.
""",
    )

    public_world = {key: value for key, value in world.items() if key != "sealed_clues"}
    engine.atomic_write_json(root / "books" / "HEMLOCK_WORLD_STATE.json", public_world)
    engine.atomic_write_json(
        root / "books" / "RENN_WAYFOLIO_STATE.json",
        {
            "inventory": character.get("inventory", []),
            "discoveries": character.get("discoveries", []),
            "journal": public_journal,
            "provenance": "BOUNDED",
        },
    )
    engine.atomic_write_json(
        root / "migrations" / "NORMALIZATION_REGISTER.json",
        {
            "campaign_id": campaign_id,
            "source": str(args.source.resolve()),
            "source_state_head": world.get("state_head"),
            "normalizations": [
                {
                    "field": "campaign genesis",
                    "classification": "BOUNDED",
                    "decision": "Imported the current accepted world and Wayfolio state as a clean Contract 1.1 genesis.",
                },
                {
                    "field": "development action history",
                    "classification": "NOT_TRACKED",
                    "decision": "Repeated automated tests, undone transactions, and review clicks remain in the legacy JSON audit source but are not campaign canon.",
                },
                {
                    "field": "sealed clues",
                    "classification": "SEALED",
                    "decision": "Imported into sealed_state and excluded from all visible projections and public books.",
                },
            ],
            "production": False,
        },
    )

    con = engine.connect(root)
    con.executescript(engine.SCHEMA)
    con.execute(
        """INSERT INTO campaign_metadata(
          campaign_id,campaign_schema_version,engine_contract_version,
          compatible_engine,production,genesis_id,genesis_hash,created_at
        ) VALUES(?,?,?,?,?,?,?,?)""",
        (
            campaign_id,
            "1.1",
            engine.CONTRACT_VERSION,
            f"AI-DM Engine >={engine.ENGINE_VERSION}",
            0,
            f"genesis:{campaign_id}",
            engine.ZERO_HASH,
            created,
        ),
    )

    notes = [
        world.get("location", {}).get("description", ""),
        *world.get("open_pressures", []),
        "Open play: no prewritten player choice is pending.",
    ]
    resources = {
        "party": world.get("party", []),
        "active_entities": world.get("active_entities", []),
        "known_clues": world.get("known_clues", []),
        "inventory_count": len(character.get("inventory", [])),
        "discoveries_count": len(character.get("discoveries", [])),
    }
    con.execute(
        """INSERT INTO campaign_status(
          singleton,phase,campaign_time_json,location,condition_json,
          resources_json,notes_json,provenance,last_changed_state_head
        ) VALUES(1,?,?,?,?,?,?,?,?)""",
        (
            "Open Play",
            engine.canonical_json(campaign_time),
            world.get("location", {}).get("name", "Southern Hemlock Bridge"),
            engine.canonical_json({"conditions": world.get("conditions", [])}),
            engine.canonical_json(resources),
            engine.canonical_json([note for note in notes if note]),
            "BOUNDED",
            "PENDING",
        ),
    )

    for index, item in enumerate(character.get("inventory", []), start=1):
        con.execute(
            """INSERT INTO ledger_entry(
              entry_id,campaign_time_json,account,amount,unit,memo,
              provenance,visibility,last_changed_state_head
            ) VALUES(?,?,?,?,?,?,?,?,?)""",
            (
                f"inventory:{index:02d}:{slug(item)}",
                engine.canonical_json(campaign_time),
                "renn-inventory",
                1,
                "item",
                item,
                "BOUNDED",
                "VISIBLE",
                "PENDING",
            ),
        )

    for index, pressure in enumerate(world.get("open_pressures", []), start=1):
        con.execute(
            """INSERT INTO progress_instance(
              progress_id,model_type,title,owner_id,status,visibility,state_json,
              prerequisites_json,blockers_json,dependencies_json,source_authority,
              created_at_campaign_time,last_changed_state_head,legacy_progress_json
            ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,NULL)""",
            (
                f"pressure:hemlock:{index:02d}",
                "PRESSURE_ESCALATION",
                pressure,
                "world:hemlock",
                "ACTIVE",
                "VISIBLE",
                engine.canonical_json({"level": 0, "description": pressure}),
                "[]",
                "[]",
                "[]",
                "BOUNDED",
                engine.canonical_json(campaign_time),
                "PENDING",
            ),
        )

    con.execute(
        """INSERT INTO timeline_event(
          event_id,campaign_time_json,summary,provenance,visibility,last_changed_state_head
        ) VALUES(?,?,?,?,?,?)""",
        (
            "event:genesis:hemlock-bridge",
            engine.canonical_json(campaign_time),
            "Renn, Soren, and Lupin are together at the Southern Hemlock Bridge as blue motes gather beneath the rail.",
            "BOUNDED",
            "VISIBLE",
            "PENDING",
        ),
    )
    for index, discovery in enumerate(character.get("discoveries", []), start=1):
        con.execute(
            """INSERT INTO timeline_event(
              event_id,campaign_time_json,summary,provenance,visibility,last_changed_state_head
            ) VALUES(?,?,?,?,?,?)""",
            (
                f"event:imported-discovery:{index:02d}",
                engine.canonical_json(campaign_time),
                f"Wayfolio discovery: {discovery}",
                "BOUNDED",
                "VISIBLE",
                "PENDING",
            ),
        )
    for index, entry in enumerate(public_journal, start=1):
        con.execute(
            """INSERT INTO recap_entry(
              recap_id,campaign_time_json,text,provenance,visibility,last_changed_state_head
            ) VALUES(?,?,?,?,?,?)""",
            (
                f"recap:imported-journal:{index:02d}",
                engine.canonical_json(campaign_time),
                entry,
                "BOUNDED",
                "VISIBLE",
                "PENDING",
            ),
        )

    private_journal_sources = [
        entry
        for entry in character.get("journal", [])
        if public_journal_entry(entry) != entry
    ]
    for index, clue in enumerate(world.get("sealed_clues", []), start=1):
        con.execute(
            """INSERT INTO sealed_state(
              sealed_id,scope,payload_json,provenance,last_changed_state_head
            ) VALUES(?,?,?,?,?)""",
            (
                f"sealed:hemlock:{index:02d}",
                "hemlock-dm-clue",
                engine.canonical_json(
                    {
                        "clue": clue,
                        "private_journal_sources": private_journal_sources,
                    }
                ),
                "SEALED",
                "PENDING",
            ),
        )

    snapshot_hash = engine.hash_json(engine.domain_snapshot(con))
    genesis_head = "state:" + engine.hash_json(
        {
            "prior_state_head": "GENESIS_ZERO",
            "turn_id": "GENESIS",
            "domain_snapshot_sha256": snapshot_hash,
        }
    )
    genesis_delta = {
        "full_genesis_establishment": True,
        "campaign_id": campaign_id,
        "legacy_source_state_head": world.get("state_head"),
        "normalization": "BOUNDED",
    }
    receipt = {
        "status": "PASS",
        "contract": engine.CONTRACT_VERSION,
        "player_sovereignty": "PASS",
        "sealed_projection_check": "PASS",
    }
    core = {
        "turn_id": "GENESIS",
        "declaration": "GENESIS",
        "prior_state_head": "GENESIS_ZERO",
        "resulting_state_head": genesis_head,
        "previous_transaction_hash": engine.ZERO_HASH,
        "phase_before": "Control",
        "phase_after": "Open Play",
        "campaign_time_before": {"axis": "GENESIS_ZERO"},
        "campaign_time_after": campaign_time,
        "domain_delta": genesis_delta,
        "validation_receipt": receipt,
        "source_references": [
            "Host/data/campaign-state.json",
            "Host/content/hemlock-world.json",
        ],
        "committed": True,
    }
    transaction_hash = engine.hash_json(core)
    transaction_id = f"txn:{transaction_hash[:32]}"
    con.execute(
        """INSERT INTO transaction_log(
          seq,transaction_id,turn_id,declaration,declaration_sha256,prior_state_head,
          resulting_state_head,previous_transaction_hash,transaction_hash,
          phase_before,phase_after,campaign_time_before_json,campaign_time_after_json,
          domain_delta_json,validation_receipt_json,source_references_json,committed,committed_at
        ) VALUES(0,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        (
            transaction_id,
            "GENESIS",
            "GENESIS",
            engine.sha256_text("GENESIS"),
            "GENESIS_ZERO",
            genesis_head,
            engine.ZERO_HASH,
            transaction_hash,
            "Control",
            "Open Play",
            engine.canonical_json({"axis": "GENESIS_ZERO"}),
            engine.canonical_json(campaign_time),
            engine.canonical_json(genesis_delta),
            engine.canonical_json(receipt),
            engine.canonical_json(core["source_references"]),
            1,
            created,
        ),
    )
    for table in (
        "campaign_status",
        "ledger_entry",
        "progress_instance",
        "timeline_event",
        "recap_entry",
        "sealed_state",
    ):
        con.execute(
            f"UPDATE {table} SET last_changed_state_head=? WHERE last_changed_state_head='PENDING'",
            (genesis_head,),
        )
    con.execute(
        "INSERT INTO state_head(singleton,state_head_id,transaction_hash,campaign_time_json,updated_at) VALUES(1,?,?,?,?)",
        (genesis_head, transaction_hash, engine.canonical_json(campaign_time), created),
    )
    con.execute(
        "INSERT INTO manifest_recovery(singleton,target_state_head,target_transaction_hash,pending,updated_at) VALUES(1,?,?,0,?)",
        (genesis_head, transaction_hash, created),
    )
    con.execute(
        "UPDATE campaign_metadata SET genesis_hash=? WHERE campaign_id=?",
        (transaction_hash, campaign_id),
    )
    engine.rebuild_projections(con, genesis_head, transaction_hash, None)
    con.commit()
    con.close()

    base_manifest = {"campaign_package_version": "1.1", "created_at": created}
    engine.atomic_write_json(
        root / "CAMPAIGN_MANIFEST.json",
        engine.manifest_from_database(root, base_manifest),
    )
    result = engine.validate_campaign(root)
    print(json.dumps(result, indent=2, sort_keys=True))
    if result["status"] != "PASS":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
