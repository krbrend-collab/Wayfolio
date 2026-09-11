#!/usr/bin/env python3
"""Contract-1.1 Campaign binding, transaction, projection, and checkpoint tool.

This module intentionally owns no campaign-specific canon.  It operates only on
the Campaign package explicitly passed with ``--campaign``.
"""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import os
import re
import shutil
import sqlite3
import sys
import tempfile
import uuid
import zipfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


CONTRACT_VERSION = "1.1"
ENGINE_VERSION = "4.0.1"
ZERO_HASH = "0" * 64
HEX64 = re.compile(r"^[0-9a-f]{64}$")
REQUIRED_LAYOUT = (
    "CAMPAIGN_MANIFEST.json",
    "campaign.sqlite",
    "AI_DM_RUNTIME_PRIMER.md",
    "STORY_SO_FAR.md",
    "books",
    "checkpoints",
    "migrations",
)
REQUIRED_PROJECTIONS = {
    "status",
    "ledger",
    "projects",
    "timeline",
    "recap",
    "save",
}
PROVENANCE = {
    "EXACT",
    "DERIVED",
    "GENERATED_CANON",
    "NORMALIZED",
    "BOUNDED",
    "FUTURE_UNKNOWN",
    "SEALED",
    "NOT_TRACKED",
}
PROGRESS_MODELS = {
    "STAGED_PROJECT",
    "RESEARCH_EVIDENCE",
    "TRAINING_MASTERY",
    "MAINTENANCE_RECOVERY",
    "COUNTDOWN_DEADLINE",
    "PRESSURE_ESCALATION",
    "RESOURCE_ACCUMULATION",
    "CONTRACT_OBLIGATION",
    "LOCKED_UPGRADE",
    "OPERATION_PLAN",
}
PROGRESS_STATUSES = {
    "ACTIVE",
    "DORMANT",
    "BLOCKED",
    "LOCKED",
    "COMPLETE",
    "FAILED",
    "CANCELLED",
}
FORBIDDEN_VOLUNTARY_KEYS = {
    "player_action",
    "player_dialogue",
    "player_tactic",
    "player_tactics",
    "player_power_use",
    "player_belief",
    "player_conclusion",
    "player_emotion",
    "player_priority",
    "player_allocation",
    "player_acceptance",
    "player_intent",
}


SCHEMA = """
PRAGMA foreign_keys=ON;

CREATE TABLE campaign_metadata (
    campaign_id TEXT PRIMARY KEY,
    campaign_schema_version TEXT NOT NULL,
    engine_contract_version TEXT NOT NULL,
    compatible_engine TEXT NOT NULL,
    production INTEGER NOT NULL CHECK(production IN (0,1)),
    genesis_id TEXT NOT NULL,
    genesis_hash TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE state_head (
    singleton INTEGER PRIMARY KEY CHECK(singleton=1),
    state_head_id TEXT NOT NULL,
    transaction_hash TEXT NOT NULL,
    campaign_time_json TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE transaction_log (
    seq INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id TEXT NOT NULL UNIQUE,
    turn_id TEXT NOT NULL UNIQUE,
    declaration TEXT NOT NULL,
    declaration_sha256 TEXT NOT NULL,
    prior_state_head TEXT NOT NULL,
    resulting_state_head TEXT NOT NULL UNIQUE,
    previous_transaction_hash TEXT NOT NULL,
    transaction_hash TEXT NOT NULL UNIQUE,
    phase_before TEXT NOT NULL,
    phase_after TEXT NOT NULL,
    campaign_time_before_json TEXT NOT NULL,
    campaign_time_after_json TEXT NOT NULL,
    domain_delta_json TEXT NOT NULL,
    validation_receipt_json TEXT NOT NULL,
    source_references_json TEXT NOT NULL,
    committed INTEGER NOT NULL CHECK(committed IN (0,1)),
    committed_at TEXT NOT NULL
);

CREATE TABLE campaign_status (
    singleton INTEGER PRIMARY KEY CHECK(singleton=1),
    phase TEXT NOT NULL,
    campaign_time_json TEXT NOT NULL,
    location TEXT,
    condition_json TEXT NOT NULL,
    resources_json TEXT NOT NULL,
    notes_json TEXT NOT NULL,
    provenance TEXT NOT NULL,
    last_changed_state_head TEXT NOT NULL
);

CREATE TABLE ledger_entry (
    entry_id TEXT PRIMARY KEY,
    campaign_time_json TEXT NOT NULL,
    account TEXT NOT NULL,
    amount REAL NOT NULL,
    unit TEXT NOT NULL,
    memo TEXT NOT NULL,
    provenance TEXT NOT NULL,
    visibility TEXT NOT NULL CHECK(visibility IN ('VISIBLE','SEALED')),
    last_changed_state_head TEXT NOT NULL
);

CREATE TABLE progress_instance (
    progress_id TEXT PRIMARY KEY,
    model_type TEXT NOT NULL,
    title TEXT NOT NULL,
    owner_id TEXT NOT NULL,
    status TEXT NOT NULL,
    visibility TEXT NOT NULL CHECK(visibility IN ('VISIBLE','SEALED')),
    state_json TEXT NOT NULL,
    prerequisites_json TEXT NOT NULL,
    blockers_json TEXT NOT NULL,
    dependencies_json TEXT NOT NULL,
    source_authority TEXT NOT NULL,
    created_at_campaign_time TEXT,
    last_changed_state_head TEXT NOT NULL,
    legacy_progress_json TEXT
);

CREATE TABLE timeline_event (
    event_id TEXT PRIMARY KEY,
    campaign_time_json TEXT NOT NULL,
    summary TEXT NOT NULL,
    provenance TEXT NOT NULL,
    visibility TEXT NOT NULL CHECK(visibility IN ('VISIBLE','SEALED')),
    last_changed_state_head TEXT NOT NULL
);

CREATE TABLE recap_entry (
    recap_id TEXT PRIMARY KEY,
    campaign_time_json TEXT NOT NULL,
    text TEXT NOT NULL,
    provenance TEXT NOT NULL,
    visibility TEXT NOT NULL CHECK(visibility IN ('VISIBLE','SEALED')),
    last_changed_state_head TEXT NOT NULL
);

CREATE TABLE sealed_state (
    sealed_id TEXT PRIMARY KEY,
    scope TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    provenance TEXT NOT NULL CHECK(provenance='SEALED'),
    last_changed_state_head TEXT NOT NULL
);

CREATE TABLE current_projection (
    projection_kind TEXT PRIMARY KEY,
    state_head_id TEXT NOT NULL,
    transaction_hash TEXT NOT NULL,
    content_sha256 TEXT NOT NULL,
    visibility TEXT NOT NULL CHECK(visibility='VISIBLE'),
    payload_json TEXT NOT NULL
);

CREATE TABLE checkpoint (
    checkpoint_id TEXT PRIMARY KEY,
    state_head_id TEXT NOT NULL,
    transaction_hash TEXT NOT NULL,
    checkpoint_kind TEXT NOT NULL,
    created_at_campaign_time TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE manifest_recovery (
    singleton INTEGER PRIMARY KEY CHECK(singleton=1),
    target_state_head TEXT NOT NULL,
    target_transaction_hash TEXT NOT NULL,
    pending INTEGER NOT NULL CHECK(pending IN (0,1)),
    updated_at TEXT NOT NULL
);

CREATE INDEX idx_transaction_turn ON transaction_log(turn_id);
CREATE INDEX idx_ledger_visibility ON ledger_entry(visibility,account);
CREATE INDEX idx_progress_visibility ON progress_instance(visibility,status,model_type);
CREATE INDEX idx_timeline_visibility ON timeline_event(visibility);
"""


class CampaignError(RuntimeError):
    """A user-actionable Campaign contract or mutation error."""


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_text(text: str) -> str:
    return sha256_bytes(text.encode("utf-8"))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def hash_json(value: Any) -> str:
    return sha256_text(canonical_json(value))


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise CampaignError(f"cannot read valid JSON from {path.name}: {exc}") from exc


def atomic_write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent)
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def safe_extract_zip(archive: Path, destination: Path) -> None:
    destination_resolved = destination.resolve()
    with zipfile.ZipFile(archive) as zf:
        for info in zf.infolist():
            member = (destination / info.filename).resolve()
            if destination_resolved not in member.parents and member != destination_resolved:
                raise CampaignError(f"unsafe ZIP member: {info.filename}")
        zf.extractall(destination)


def locate_campaign_root(extracted: Path) -> Path:
    manifests = list(extracted.rglob("CAMPAIGN_MANIFEST.json"))
    if len(manifests) != 1:
        raise CampaignError(
            f"Campaign ZIP must contain exactly one CAMPAIGN_MANIFEST.json; found {len(manifests)}"
        )
    return manifests[0].parent


@dataclass
class CampaignBinding:
    source: Path
    root: Path
    is_zip: bool
    temporary: tempfile.TemporaryDirectory[str] | None = None

    @classmethod
    def open(cls, source: str | Path) -> "CampaignBinding":
        path = Path(source).expanduser().resolve()
        if path.is_dir():
            return cls(source=path, root=path, is_zip=False)
        if path.is_file() and zipfile.is_zipfile(path):
            temporary = tempfile.TemporaryDirectory(prefix="aidm4-campaign-")
            extracted = Path(temporary.name)
            safe_extract_zip(path, extracted)
            return cls(
                source=path,
                root=locate_campaign_root(extracted),
                is_zip=True,
                temporary=temporary,
            )
        raise CampaignError(f"Campaign path is not a directory or ZIP: {path}")

    def require_write_target(self, output: str | Path | None) -> Path | None:
        if not self.is_zip:
            return Path(output).expanduser().resolve() if output else None
        if output is None:
            raise CampaignError("mutating a ZIP Campaign requires --output")
        target = Path(output).expanduser().resolve()
        if target == self.source:
            raise CampaignError("refusing to overwrite the only supplied Campaign ZIP")
        return target

    def close(self) -> None:
        if self.temporary is not None:
            self.temporary.cleanup()

    def __enter__(self) -> "CampaignBinding":
        return self

    def __exit__(self, *_: Any) -> None:
        self.close()


def connect(root: Path) -> sqlite3.Connection:
    con = sqlite3.connect(root / "campaign.sqlite")
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA foreign_keys=ON")
    con.execute("PRAGMA busy_timeout=5000")
    return con


def required_manifest_fields() -> set[str]:
    return {
        "campaign_id",
        "campaign_package_version",
        "campaign_schema_version",
        "engine_contract_version",
        "compatible_engine",
        "production",
        "genesis_id",
        "genesis_hash",
        "current_state_head",
        "current_transaction_hash",
        "current_projection_head",
        "current_resume_hash",
        "runtime_primer_hash",
        "story_so_far_hash",
        "last_checkpoint_id",
        "normalization_register_hash",
        "created_at",
        "updated_at",
    }


def table_names(con: sqlite3.Connection) -> set[str]:
    return {
        row["name"]
        for row in con.execute("SELECT name FROM sqlite_master WHERE type='table'")
    }


def validate_campaign(root: Path) -> dict[str, Any]:
    errors: list[str] = []
    for relative in REQUIRED_LAYOUT:
        if not (root / relative).exists():
            errors.append(f"missing required Campaign package path: {relative}")
    if errors:
        return {"status": "FAIL", "errors": errors}

    manifest = read_json(root / "CAMPAIGN_MANIFEST.json")
    missing = sorted(required_manifest_fields() - set(manifest))
    if missing:
        errors.append(f"manifest missing fields: {missing}")
    if manifest.get("engine_contract_version") != CONTRACT_VERSION:
        errors.append(
            f"engine_contract_version must be {CONTRACT_VERSION}, "
            f"got {manifest.get('engine_contract_version')!r}"
        )
    if not isinstance(manifest.get("production"), bool):
        errors.append("manifest production must be a JSON boolean")
    for field in (
        "genesis_hash",
        "current_transaction_hash",
        "current_resume_hash",
        "runtime_primer_hash",
        "story_so_far_hash",
        "normalization_register_hash",
    ):
        value = manifest.get(field)
        if not isinstance(value, str) or not HEX64.fullmatch(value):
            errors.append(f"{field} must be lowercase SHA-256 hex")

    primer = root / "AI_DM_RUNTIME_PRIMER.md"
    story = root / "STORY_SO_FAR.md"
    normalization = root / "migrations" / "NORMALIZATION_REGISTER.json"
    if primer.exists() and manifest.get("runtime_primer_hash") != sha256_file(primer):
        errors.append("runtime_primer_hash mismatch")
    if story.exists() and manifest.get("story_so_far_hash") != sha256_file(story):
        errors.append("story_so_far_hash mismatch")
    if not normalization.exists():
        errors.append("missing migrations/NORMALIZATION_REGISTER.json")
    elif manifest.get("normalization_register_hash") != sha256_file(normalization):
        errors.append("normalization_register_hash mismatch")

    db_path = root / "campaign.sqlite"
    if not db_path.exists():
        return {"status": "FAIL", "errors": errors}

    try:
        con = connect(root)
        integrity = con.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            errors.append(f"SQLite integrity_check: {integrity}")
        required_tables = {
            "campaign_metadata",
            "state_head",
            "transaction_log",
            "campaign_status",
            "ledger_entry",
            "progress_instance",
            "timeline_event",
            "recap_entry",
            "sealed_state",
            "current_projection",
            "checkpoint",
            "manifest_recovery",
        }
        missing_tables = sorted(required_tables - table_names(con))
        if missing_tables:
            errors.append(f"missing contract tables: {missing_tables}")
        if not missing_tables:
            head = con.execute(
                "SELECT * FROM state_head WHERE singleton=1"
            ).fetchone()
            latest = con.execute(
                "SELECT * FROM transaction_log WHERE committed=1 ORDER BY seq DESC LIMIT 1"
            ).fetchone()
            metadata = con.execute("SELECT * FROM campaign_metadata").fetchall()
            if head is None:
                errors.append("state_head singleton missing")
            if latest is None:
                errors.append("committed transaction chain missing")
            if len(metadata) != 1:
                errors.append("campaign_metadata must contain exactly one row")
            elif metadata[0]["campaign_id"] != manifest.get("campaign_id"):
                errors.append("manifest campaign_id != database campaign_id")
            if head is not None:
                if head["state_head_id"] != manifest.get("current_state_head"):
                    errors.append("manifest current_state_head != database state_head")
                if head["transaction_hash"] != manifest.get("current_transaction_hash"):
                    errors.append(
                        "manifest current_transaction_hash != database state_head hash"
                    )
            if latest is not None and head is not None:
                if latest["resulting_state_head"] != head["state_head_id"]:
                    errors.append("latest committed transaction != database state head")
                if latest["transaction_hash"] != head["transaction_hash"]:
                    errors.append("latest committed transaction hash != state head hash")

            projections = con.execute(
                "SELECT * FROM current_projection"
            ).fetchall()
            kinds = {row["projection_kind"] for row in projections}
            missing_projections = sorted(REQUIRED_PROJECTIONS - kinds)
            if missing_projections:
                errors.append(f"missing current projections: {missing_projections}")
            for row in projections:
                if row["state_head_id"] != manifest.get("current_state_head"):
                    errors.append(
                        f"projection {row['projection_kind']} has stale state head"
                    )
                if row["transaction_hash"] != manifest.get(
                    "current_transaction_hash"
                ):
                    errors.append(
                        f"projection {row['projection_kind']} has stale transaction hash"
                    )
                if row["visibility"] != "VISIBLE":
                    errors.append(
                        f"projection {row['projection_kind']} is not visible-only"
                    )
                try:
                    payload = json.loads(row["payload_json"])
                except json.JSONDecodeError:
                    errors.append(
                        f"projection {row['projection_kind']} payload is invalid JSON"
                    )
                else:
                    if hash_json(payload) != row["content_sha256"]:
                        errors.append(
                            f"projection {row['projection_kind']} content hash mismatch"
                        )
            recap = next(
                (row for row in projections if row["projection_kind"] == "recap"),
                None,
            )
            if recap is not None and recap["content_sha256"] != manifest.get(
                "current_resume_hash"
            ):
                errors.append("manifest current_resume_hash != recap projection hash")
            if manifest.get("current_projection_head") != manifest.get(
                "current_state_head"
            ):
                errors.append("manifest current_projection_head != current_state_head")

            chain_errors = verify_transaction_chain(con)
            errors.extend(chain_errors)
        con.close()
    except sqlite3.Error as exc:
        errors.append(f"SQLite error: {exc}")

    return {
        "status": "PASS" if not errors else "FAIL",
        "errors": errors,
        "campaign_id": manifest.get("campaign_id"),
        "production": manifest.get("production"),
        "contract": manifest.get("engine_contract_version"),
        "state_head": manifest.get("current_state_head"),
        "transaction_hash": manifest.get("current_transaction_hash"),
    }


def verify_transaction_chain(con: sqlite3.Connection) -> list[str]:
    errors: list[str] = []
    rows = con.execute(
        "SELECT * FROM transaction_log WHERE committed=1 ORDER BY seq"
    ).fetchall()
    previous_hash = ZERO_HASH
    previous_head = "GENESIS_ZERO"
    seen_turns: set[str] = set()
    for index, row in enumerate(rows):
        if row["turn_id"] in seen_turns:
            errors.append(f"duplicate turn_id in chain: {row['turn_id']}")
        seen_turns.add(row["turn_id"])
        if row["previous_transaction_hash"] != previous_hash:
            errors.append(f"broken previous hash at turn {row['turn_id']}")
        if row["prior_state_head"] != previous_head:
            errors.append(f"broken prior state head at turn {row['turn_id']}")
        if sha256_text(row["declaration"]) != row["declaration_sha256"]:
            errors.append(f"declaration hash mismatch at turn {row['turn_id']}")
        core = transaction_core_from_row(row)
        expected_hash = hash_json(core)
        if expected_hash != row["transaction_hash"]:
            errors.append(f"transaction hash mismatch at turn {row['turn_id']}")
        expected_id = f"txn:{expected_hash[:32]}"
        if row["transaction_id"] != expected_id:
            errors.append(f"transaction id mismatch at turn {row['turn_id']}")
        if index == 0 and row["turn_id"] != "GENESIS":
            errors.append("first committed transaction is not GENESIS")
        previous_hash = row["transaction_hash"]
        previous_head = row["resulting_state_head"]
    return errors


def transaction_core_from_row(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "turn_id": row["turn_id"],
        "declaration": row["declaration"],
        "prior_state_head": row["prior_state_head"],
        "resulting_state_head": row["resulting_state_head"],
        "previous_transaction_hash": row["previous_transaction_hash"],
        "phase_before": row["phase_before"],
        "phase_after": row["phase_after"],
        "campaign_time_before": json.loads(row["campaign_time_before_json"]),
        "campaign_time_after": json.loads(row["campaign_time_after_json"]),
        "domain_delta": json.loads(row["domain_delta_json"]),
        "validation_receipt": json.loads(row["validation_receipt_json"]),
        "source_references": json.loads(row["source_references_json"]),
        "committed": bool(row["committed"]),
    }


def fetch_status(con: sqlite3.Connection) -> dict[str, Any]:
    row = con.execute("SELECT * FROM campaign_status WHERE singleton=1").fetchone()
    if row is None:
        raise CampaignError("campaign_status singleton missing")
    return {
        "phase": row["phase"],
        "campaign_time": json.loads(row["campaign_time_json"]),
        "location": row["location"],
        "condition": json.loads(row["condition_json"]),
        "resources": json.loads(row["resources_json"]),
        "notes": json.loads(row["notes_json"]),
        "provenance": row["provenance"],
    }


def domain_snapshot(con: sqlite3.Connection) -> dict[str, Any]:
    status = fetch_status(con)
    ledger = [
        {
            "entry_id": row["entry_id"],
            "campaign_time": json.loads(row["campaign_time_json"]),
            "account": row["account"],
            "amount": row["amount"],
            "unit": row["unit"],
            "memo": row["memo"],
            "provenance": row["provenance"],
            "visibility": row["visibility"],
        }
        for row in con.execute("SELECT * FROM ledger_entry ORDER BY entry_id")
    ]
    projects = [
        {
            "progress_id": row["progress_id"],
            "model_type": row["model_type"],
            "title": row["title"],
            "owner_id": row["owner_id"],
            "status": row["status"],
            "visibility": row["visibility"],
            "state": json.loads(row["state_json"]),
            "prerequisites": json.loads(row["prerequisites_json"]),
            "blockers": json.loads(row["blockers_json"]),
            "dependencies": json.loads(row["dependencies_json"]),
            "source_authority": row["source_authority"],
            "created_at_campaign_time": row["created_at_campaign_time"],
            "legacy_progress": (
                json.loads(row["legacy_progress_json"])
                if row["legacy_progress_json"]
                else None
            ),
        }
        for row in con.execute("SELECT * FROM progress_instance ORDER BY progress_id")
    ]
    timeline = [
        {
            "event_id": row["event_id"],
            "campaign_time": json.loads(row["campaign_time_json"]),
            "summary": row["summary"],
            "provenance": row["provenance"],
            "visibility": row["visibility"],
        }
        for row in con.execute("SELECT * FROM timeline_event ORDER BY event_id")
    ]
    recap = [
        {
            "recap_id": row["recap_id"],
            "campaign_time": json.loads(row["campaign_time_json"]),
            "text": row["text"],
            "provenance": row["provenance"],
            "visibility": row["visibility"],
        }
        for row in con.execute("SELECT * FROM recap_entry ORDER BY recap_id")
    ]
    sealed = [
        {
            "sealed_id": row["sealed_id"],
            "scope": row["scope"],
            "payload": json.loads(row["payload_json"]),
            "provenance": row["provenance"],
        }
        for row in con.execute("SELECT * FROM sealed_state ORDER BY sealed_id")
    ]
    return {
        "status": status,
        "ledger": ledger,
        "projects": projects,
        "timeline": timeline,
        "recap": recap,
        "sealed": sealed,
    }


def projection_payloads(
    con: sqlite3.Connection,
    state_head: str,
    transaction_hash: str,
    last_checkpoint_id: str | None,
) -> dict[str, Any]:
    status = fetch_status(con)
    ledger = [
        {
            "entry_id": row["entry_id"],
            "campaign_time": json.loads(row["campaign_time_json"]),
            "account": row["account"],
            "amount": row["amount"],
            "unit": row["unit"],
            "memo": row["memo"],
            "provenance": row["provenance"],
        }
        for row in con.execute(
            "SELECT * FROM ledger_entry WHERE visibility='VISIBLE' ORDER BY rowid"
        )
    ]
    projects = [
        {
            "progress_id": row["progress_id"],
            "model_type": row["model_type"],
            "title": row["title"],
            "owner_id": row["owner_id"],
            "status": row["status"],
            "state": json.loads(row["state_json"]),
            "prerequisites": json.loads(row["prerequisites_json"]),
            "blockers": json.loads(row["blockers_json"]),
            "dependencies": json.loads(row["dependencies_json"]),
            "source_authority": row["source_authority"],
            "legacy_progress": (
                json.loads(row["legacy_progress_json"])
                if row["legacy_progress_json"]
                else None
            ),
        }
        for row in con.execute(
            """
            SELECT * FROM progress_instance
            WHERE visibility='VISIBLE'
              AND status NOT IN ('COMPLETE','FAILED','CANCELLED')
            ORDER BY progress_id
            """
        )
    ]
    timeline = [
        {
            "event_id": row["event_id"],
            "campaign_time": json.loads(row["campaign_time_json"]),
            "summary": row["summary"],
            "provenance": row["provenance"],
        }
        for row in con.execute(
            "SELECT * FROM timeline_event WHERE visibility='VISIBLE' ORDER BY rowid"
        )
    ]
    recap = [
        {
            "campaign_time": json.loads(row["campaign_time_json"]),
            "text": row["text"],
            "provenance": row["provenance"],
        }
        for row in con.execute(
            "SELECT * FROM recap_entry WHERE visibility='VISIBLE' ORDER BY rowid"
        )
    ]
    envelope = {
        "state_head": state_head,
        "transaction_hash": transaction_hash,
    }
    return {
        "status": {**envelope, **status},
        "ledger": {**envelope, "entries": ledger},
        "projects": {**envelope, "projects": projects},
        "timeline": {**envelope, "events": timeline},
        "recap": {**envelope, "entries": recap},
        "save": {
            **envelope,
            "last_checkpoint_id": last_checkpoint_id,
            "checkpoint_advances_gameplay": False,
        },
    }


def rebuild_projections(
    con: sqlite3.Connection,
    state_head: str,
    transaction_hash: str,
    last_checkpoint_id: str | None,
) -> dict[str, str]:
    payloads = projection_payloads(
        con, state_head, transaction_hash, last_checkpoint_id
    )
    con.execute("DELETE FROM current_projection")
    hashes: dict[str, str] = {}
    for kind, payload in payloads.items():
        content_hash = hash_json(payload)
        hashes[kind] = content_hash
        con.execute(
            """
            INSERT INTO current_projection(
                projection_kind,state_head_id,transaction_hash,
                content_sha256,visibility,payload_json
            ) VALUES(?,?,?,?,?,?)
            """,
            (
                kind,
                state_head,
                transaction_hash,
                content_hash,
                "VISIBLE",
                canonical_json(payload),
            ),
        )
    return hashes


def manifest_from_database(
    root: Path, existing: dict[str, Any] | None = None
) -> dict[str, Any]:
    existing = dict(existing or {})
    con = connect(root)
    metadata = con.execute("SELECT * FROM campaign_metadata").fetchone()
    head = con.execute("SELECT * FROM state_head WHERE singleton=1").fetchone()
    recap = con.execute(
        "SELECT content_sha256 FROM current_projection WHERE projection_kind='recap'"
    ).fetchone()
    last_checkpoint = con.execute(
        "SELECT checkpoint_id FROM checkpoint ORDER BY created_at DESC, rowid DESC LIMIT 1"
    ).fetchone()
    con.close()
    if metadata is None or head is None or recap is None:
        raise CampaignError("cannot build manifest from incomplete database")
    existing.update(
        {
            "campaign_id": metadata["campaign_id"],
            "campaign_package_version": existing.get(
                "campaign_package_version", "1.1"
            ),
            "campaign_schema_version": metadata["campaign_schema_version"],
            "engine_contract_version": metadata["engine_contract_version"],
            "compatible_engine": metadata["compatible_engine"],
            "production": bool(metadata["production"]),
            "genesis_id": metadata["genesis_id"],
            "genesis_hash": metadata["genesis_hash"],
            "current_state_head": head["state_head_id"],
            "current_transaction_hash": head["transaction_hash"],
            "current_projection_head": head["state_head_id"],
            "current_resume_hash": recap["content_sha256"],
            "runtime_primer_hash": sha256_file(root / "AI_DM_RUNTIME_PRIMER.md"),
            "story_so_far_hash": sha256_file(root / "STORY_SO_FAR.md"),
            "last_checkpoint_id": (
                last_checkpoint["checkpoint_id"] if last_checkpoint else None
            ),
            "normalization_register_hash": sha256_file(
                root / "migrations" / "NORMALIZATION_REGISTER.json"
            ),
            "created_at": existing.get("created_at", metadata["created_at"]),
            "updated_at": utc_now(),
        }
    )
    return existing


def sync_manifest(root: Path) -> bool:
    path = root / "CAMPAIGN_MANIFEST.json"
    existing = read_json(path) if path.exists() else {}
    target = manifest_from_database(root, existing)
    comparable_existing = dict(existing)
    comparable_target = dict(target)
    comparable_existing.pop("updated_at", None)
    comparable_target.pop("updated_at", None)
    if comparable_existing == comparable_target:
        return False
    con = connect(root)
    head = con.execute("SELECT * FROM state_head WHERE singleton=1").fetchone()
    with con:
        con.execute(
            """
            INSERT INTO manifest_recovery(
                singleton,target_state_head,target_transaction_hash,pending,updated_at
            ) VALUES(1,?,?,1,?)
            ON CONFLICT(singleton) DO UPDATE SET
              target_state_head=excluded.target_state_head,
              target_transaction_hash=excluded.target_transaction_hash,
              pending=1,
              updated_at=excluded.updated_at
            """,
            (head["state_head_id"], head["transaction_hash"], utc_now()),
        )
    con.close()
    atomic_write_json(path, target)
    con = connect(root)
    with con:
        con.execute(
            "UPDATE manifest_recovery SET pending=0,updated_at=? WHERE singleton=1",
            (utc_now(),),
        )
    con.close()
    return True


def assert_no_voluntary_fields(value: Any, path: str = "delta") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            normalized = key.lower().replace("-", "_").replace(" ", "_")
            if normalized in FORBIDDEN_VOLUNTARY_KEYS:
                raise CampaignError(
                    f"player-sovereignty violation: delta may not author {path}.{key}"
                )
            assert_no_voluntary_fields(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            assert_no_voluntary_fields(child, f"{path}[{index}]")


def require_provenance(value: str) -> str:
    if value not in PROVENANCE:
        raise CampaignError(f"invalid provenance class: {value}")
    return value


def apply_delta(
    con: sqlite3.Connection,
    delta: dict[str, Any],
    turn_id: str,
    prior_head: str,
    phase_after: str | None,
    campaign_time_after: Any | None,
) -> tuple[str, Any, set[str]]:
    allowed = {
        "status_patch",
        "ledger_append",
        "project_updates",
        "timeline_append",
        "recap_append",
        "source_references",
    }
    unknown = sorted(set(delta) - allowed)
    if unknown:
        raise CampaignError(f"unsupported domain delta keys: {unknown}")
    assert_no_voluntary_fields(delta)
    changed_tables: set[str] = set()
    status = fetch_status(con)
    status_patch = dict(delta.get("status_patch") or {})
    allowed_status = {"phase", "campaign_time", "location", "condition", "resources", "notes"}
    unknown_status = sorted(set(status_patch) - allowed_status)
    if unknown_status:
        raise CampaignError(f"unsupported status fields: {unknown_status}")
    if phase_after is not None:
        status_patch["phase"] = phase_after
    if campaign_time_after is not None:
        status_patch["campaign_time"] = campaign_time_after
    if status_patch:
        updated = dict(status)
        updated.update(status_patch)
        con.execute(
            """
            UPDATE campaign_status
            SET phase=?,campaign_time_json=?,location=?,condition_json=?,
                resources_json=?,notes_json=?,last_changed_state_head=?
            WHERE singleton=1
            """,
            (
                updated["phase"],
                canonical_json(updated["campaign_time"]),
                updated.get("location"),
                canonical_json(updated.get("condition", {})),
                canonical_json(updated.get("resources", {})),
                canonical_json(updated.get("notes", [])),
                prior_head,
            ),
        )
        changed_tables.add("campaign_status")

    for index, entry in enumerate(delta.get("ledger_append") or []):
        provenance = require_provenance(entry.get("provenance", "EXACT"))
        visibility = entry.get("visibility", "VISIBLE")
        if visibility != "VISIBLE":
            raise CampaignError("ledger_append accepts visible entries only")
        entry_id = entry.get("entry_id") or f"ledger:{turn_id}:{index}"
        con.execute(
            """
            INSERT INTO ledger_entry(
                entry_id,campaign_time_json,account,amount,unit,memo,
                provenance,visibility,last_changed_state_head
            ) VALUES(?,?,?,?,?,?,?,?,?)
            """,
            (
                entry_id,
                canonical_json(entry.get("campaign_time", status["campaign_time"])),
                str(entry["account"]),
                float(entry["amount"]),
                str(entry["unit"]),
                str(entry["memo"]),
                provenance,
                visibility,
                prior_head,
            ),
        )
        changed_tables.add("ledger_entry")

    for update in delta.get("project_updates") or []:
        progress_id = str(update["progress_id"])
        current = con.execute(
            "SELECT * FROM progress_instance WHERE progress_id=?", (progress_id,)
        ).fetchone()
        if current is None:
            model_type = update["model_type"]
            status_value = update.get("status", "ACTIVE")
            if model_type not in PROGRESS_MODELS:
                raise CampaignError(f"invalid Progress Model type: {model_type}")
            if status_value not in PROGRESS_STATUSES:
                raise CampaignError(f"invalid progress status: {status_value}")
            if update.get("visibility", "VISIBLE") != "VISIBLE":
                raise CampaignError("project_updates accepts visible instances only")
            con.execute(
                """
                INSERT INTO progress_instance(
                    progress_id,model_type,title,owner_id,status,visibility,
                    state_json,prerequisites_json,blockers_json,dependencies_json,
                    source_authority,created_at_campaign_time,last_changed_state_head,
                    legacy_progress_json
                ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
                (
                    progress_id,
                    model_type,
                    str(update["title"]),
                    str(update["owner_id"]),
                    status_value,
                    "VISIBLE",
                    canonical_json(update.get("state", {})),
                    canonical_json(update.get("prerequisites", [])),
                    canonical_json(update.get("blockers", [])),
                    canonical_json(update.get("dependencies", [])),
                    str(update.get("source_authority", "GENERATED_CANON")),
                    canonical_json(
                        update.get("created_at_campaign_time", status["campaign_time"])
                    ),
                    prior_head,
                    (
                        canonical_json(update["legacy_progress"])
                        if update.get("legacy_progress") is not None
                        else None
                    ),
                ),
            )
        else:
            status_value = update.get("status", current["status"])
            model_type = update.get("model_type", current["model_type"])
            if model_type not in PROGRESS_MODELS:
                raise CampaignError(f"invalid Progress Model type: {model_type}")
            if status_value not in PROGRESS_STATUSES:
                raise CampaignError(f"invalid progress status: {status_value}")
            con.execute(
                """
                UPDATE progress_instance
                SET model_type=?,title=?,owner_id=?,status=?,state_json=?,
                    prerequisites_json=?,blockers_json=?,dependencies_json=?,
                    source_authority=?,last_changed_state_head=?,legacy_progress_json=?
                WHERE progress_id=?
                """,
                (
                    model_type,
                    str(update.get("title", current["title"])),
                    str(update.get("owner_id", current["owner_id"])),
                    status_value,
                    canonical_json(
                        update.get("state", json.loads(current["state_json"]))
                    ),
                    canonical_json(
                        update.get(
                            "prerequisites",
                            json.loads(current["prerequisites_json"]),
                        )
                    ),
                    canonical_json(
                        update.get("blockers", json.loads(current["blockers_json"]))
                    ),
                    canonical_json(
                        update.get(
                            "dependencies", json.loads(current["dependencies_json"])
                        )
                    ),
                    str(update.get("source_authority", current["source_authority"])),
                    prior_head,
                    (
                        canonical_json(update["legacy_progress"])
                        if "legacy_progress" in update
                        and update["legacy_progress"] is not None
                        else current["legacy_progress_json"]
                    ),
                    progress_id,
                ),
            )
        changed_tables.add("progress_instance")

    for index, event in enumerate(delta.get("timeline_append") or []):
        provenance = require_provenance(event.get("provenance", "EXACT"))
        if event.get("visibility", "VISIBLE") != "VISIBLE":
            raise CampaignError("timeline_append accepts visible events only")
        event_id = event.get("event_id") or f"event:{turn_id}:{index}"
        con.execute(
            """
            INSERT INTO timeline_event(
                event_id,campaign_time_json,summary,provenance,
                visibility,last_changed_state_head
            ) VALUES(?,?,?,?,?,?)
            """,
            (
                event_id,
                canonical_json(event.get("campaign_time", status["campaign_time"])),
                str(event["summary"]),
                provenance,
                "VISIBLE",
                prior_head,
            ),
        )
        changed_tables.add("timeline_event")

    recap_items = delta.get("recap_append") or []
    if isinstance(recap_items, str):
        recap_items = [{"text": recap_items}]
    for index, item in enumerate(recap_items):
        if isinstance(item, str):
            item = {"text": item}
        provenance = require_provenance(item.get("provenance", "EXACT"))
        if item.get("visibility", "VISIBLE") != "VISIBLE":
            raise CampaignError("recap_append accepts visible entries only")
        con.execute(
            """
            INSERT INTO recap_entry(
                recap_id,campaign_time_json,text,provenance,
                visibility,last_changed_state_head
            ) VALUES(?,?,?,?,?,?)
            """,
            (
                item.get("recap_id") or f"recap:{turn_id}:{index}",
                canonical_json(item.get("campaign_time", status["campaign_time"])),
                str(item["text"]),
                provenance,
                "VISIBLE",
                prior_head,
            ),
        )
        changed_tables.add("recap_entry")

    updated_status = fetch_status(con)
    return updated_status["phase"], updated_status["campaign_time"], changed_tables


def commit_turn(
    root: Path,
    turn_id: str,
    declaration: str,
    delta: dict[str, Any],
    expected_head: str | None = None,
    phase_after: str | None = None,
    campaign_time_after: Any | None = None,
) -> dict[str, Any]:
    if not turn_id or turn_id == "GENESIS":
        raise CampaignError("turn_id must be non-empty and cannot be GENESIS")
    if declaration == "":
        raise CampaignError("exact declaration cannot be empty")

    con = connect(root)
    existing = con.execute(
        "SELECT * FROM transaction_log WHERE turn_id=?", (turn_id,)
    ).fetchone()
    if existing is not None:
        con.close()
        if existing["declaration"] != declaration:
            raise CampaignError(
                "turn_id conflict: the same turn_id was committed with different declaration text"
            )
        sync_manifest(root)
        replay_validation = validate_campaign(root)
        if replay_validation["status"] != "PASS":
            raise CampaignError(
                f"idempotent replay recovery failed: {replay_validation['errors']}"
            )
        return {
            "status": "IDEMPOTENT_REPLAY",
            "turn_id": turn_id,
            "transaction_id": existing["transaction_id"],
            "state_head": existing["resulting_state_head"],
            "transaction_hash": existing["transaction_hash"],
            "mutated": False,
        }
    con.close()

    validation = validate_campaign(root)
    if validation["status"] != "PASS":
        raise CampaignError(f"Campaign validation failed: {validation['errors']}")

    con = connect(root)
    con.execute("BEGIN IMMEDIATE")
    try:
        head = con.execute("SELECT * FROM state_head WHERE singleton=1").fetchone()
        latest = con.execute(
            "SELECT * FROM transaction_log WHERE committed=1 ORDER BY seq DESC LIMIT 1"
        ).fetchone()
        if head is None or latest is None:
            raise CampaignError("Campaign transaction authority is incomplete")
        if expected_head is not None and head["state_head_id"] != expected_head:
            raise CampaignError(
                f"stale expected head: expected {expected_head}, "
                f"current is {head['state_head_id']}"
            )
        if latest["resulting_state_head"] != head["state_head_id"]:
            raise CampaignError("latest transaction and current state head disagree")
        if latest["transaction_hash"] != head["transaction_hash"]:
            raise CampaignError("latest transaction and current transaction hash disagree")

        status_before = fetch_status(con)
        phase_result, time_result, changed_tables = apply_delta(
            con,
            delta,
            turn_id,
            head["state_head_id"],
            phase_after,
            campaign_time_after,
        )
        snapshot_hash = hash_json(domain_snapshot(con))
        resulting_head = "state:" + hash_json(
            {
                "prior_state_head": head["state_head_id"],
                "turn_id": turn_id,
                "declaration_sha256": sha256_text(declaration),
                "domain_snapshot_sha256": snapshot_hash,
            }
        )
        receipt = {
            "status": "PASS",
            "contract": CONTRACT_VERSION,
            "expected_prior_head": head["state_head_id"],
            "changed_tables": sorted(changed_tables),
            "player_sovereignty": "PASS",
            "projection_rebuild_required": True,
        }
        source_references = delta.get("source_references") or []
        core = {
            "turn_id": turn_id,
            "declaration": declaration,
            "prior_state_head": head["state_head_id"],
            "resulting_state_head": resulting_head,
            "previous_transaction_hash": head["transaction_hash"],
            "phase_before": status_before["phase"],
            "phase_after": phase_result,
            "campaign_time_before": status_before["campaign_time"],
            "campaign_time_after": time_result,
            "domain_delta": delta,
            "validation_receipt": receipt,
            "source_references": source_references,
            "committed": True,
        }
        transaction_hash = hash_json(core)
        transaction_id = f"txn:{transaction_hash[:32]}"
        con.execute(
            """
            INSERT INTO transaction_log(
                transaction_id,turn_id,declaration,declaration_sha256,
                prior_state_head,resulting_state_head,previous_transaction_hash,
                transaction_hash,phase_before,phase_after,
                campaign_time_before_json,campaign_time_after_json,
                domain_delta_json,validation_receipt_json,source_references_json,
                committed,committed_at
            ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """,
            (
                transaction_id,
                turn_id,
                declaration,
                sha256_text(declaration),
                head["state_head_id"],
                resulting_head,
                head["transaction_hash"],
                transaction_hash,
                status_before["phase"],
                phase_result,
                canonical_json(status_before["campaign_time"]),
                canonical_json(time_result),
                canonical_json(delta),
                canonical_json(receipt),
                canonical_json(source_references),
                1,
                utc_now(),
            ),
        )
        for table in (
            "campaign_status",
            "ledger_entry",
            "progress_instance",
            "timeline_event",
            "recap_entry",
        ):
            if table in changed_tables:
                con.execute(
                    f"UPDATE {table} SET last_changed_state_head=? "
                    "WHERE last_changed_state_head=?",
                    (resulting_head, head["state_head_id"]),
                )
        con.execute(
            """
            UPDATE state_head
            SET state_head_id=?,transaction_hash=?,campaign_time_json=?,updated_at=?
            WHERE singleton=1
            """,
            (
                resulting_head,
                transaction_hash,
                canonical_json(time_result),
                utc_now(),
            ),
        )
        last_checkpoint = con.execute(
            "SELECT checkpoint_id FROM checkpoint ORDER BY created_at DESC,rowid DESC LIMIT 1"
        ).fetchone()
        rebuild_projections(
            con,
            resulting_head,
            transaction_hash,
            last_checkpoint["checkpoint_id"] if last_checkpoint else None,
        )
        bad_projection = con.execute(
            """
            SELECT projection_kind FROM current_projection
            WHERE state_head_id<>? OR transaction_hash<>?
            """,
            (resulting_head, transaction_hash),
        ).fetchone()
        if bad_projection is not None:
            raise CampaignError("projection rebuild did not converge on new head/hash")
        con.commit()
    except Exception:
        con.rollback()
        con.close()
        raise
    con.close()
    sync_manifest(root)
    post = validate_campaign(root)
    if post["status"] != "PASS":
        raise CampaignError(f"post-commit validation failed: {post['errors']}")
    return {
        "status": "COMMITTED",
        "turn_id": turn_id,
        "transaction_id": transaction_id,
        "prior_state_head": core["prior_state_head"],
        "state_head": resulting_head,
        "transaction_hash": transaction_hash,
        "mutated": True,
        "validation": "PASS",
    }


def command_projection(root: Path, name: str) -> dict[str, Any]:
    normalized = name.lower()
    if not normalized.startswith("/"):
        normalized = "/" + normalized
    kind = normalized[1:]
    if kind not in REQUIRED_PROJECTIONS:
        raise CampaignError(f"unsupported command: {name}")
    if kind == "save":
        raise CampaignError("/save requires checkpoint mode and --output")
    validation = validate_campaign(root)
    if validation["status"] != "PASS":
        raise CampaignError(f"Campaign validation failed: {validation['errors']}")
    con = connect(root)
    row = con.execute(
        "SELECT * FROM current_projection WHERE projection_kind=?", (kind,)
    ).fetchone()
    con.close()
    if row is None:
        raise CampaignError(f"projection unavailable: {kind}")
    return {
        "status": "PASS",
        "command": normalized,
        "state_head": row["state_head_id"],
        "transaction_hash": row["transaction_hash"],
        "content": json.loads(row["payload_json"]),
    }


def checkpoint_campaign(root: Path, output: Path) -> dict[str, Any]:
    validation = validate_campaign(root)
    if validation["status"] != "PASS":
        raise CampaignError(f"Campaign validation failed: {validation['errors']}")
    con = connect(root)
    con.execute("BEGIN IMMEDIATE")
    try:
        head = con.execute("SELECT * FROM state_head WHERE singleton=1").fetchone()
        campaign_time = json.loads(head["campaign_time_json"])
        checkpoint_id = (
            f"checkpoint:{head['state_head_id'].split(':')[-1][:16]}:"
            f"{uuid.uuid4().hex[:12]}"
        )
        con.execute(
            """
            INSERT INTO checkpoint(
                checkpoint_id,state_head_id,transaction_hash,checkpoint_kind,
                created_at_campaign_time,created_at
            ) VALUES(?,?,?,?,?,?)
            """,
            (
                checkpoint_id,
                head["state_head_id"],
                head["transaction_hash"],
                "EXPLICIT_SAVE",
                canonical_json(campaign_time),
                utc_now(),
            ),
        )
        rebuild_projections(
            con,
            head["state_head_id"],
            head["transaction_hash"],
            checkpoint_id,
        )
        con.commit()
    except Exception:
        con.rollback()
        con.close()
        raise
    con.close()
    sync_manifest(root)
    post = validate_campaign(root)
    if post["status"] != "PASS":
        raise CampaignError(f"checkpoint validation failed: {post['errors']}")
    export_campaign(root, output)
    return {
        "status": "PASS",
        "command": "/save",
        "checkpoint_id": checkpoint_id,
        "state_head": head["state_head_id"],
        "transaction_hash": head["transaction_hash"],
        "gameplay_head_advanced": False,
        "artifact": str(output),
        "artifact_sha256": sha256_file(output),
    }


def export_campaign(root: Path, output: Path) -> None:
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary_name = tempfile.mkstemp(
        prefix=f".{output.name}.", suffix=".tmp", dir=str(output.parent)
    )
    os.close(fd)
    temporary = Path(temporary_name)
    try:
        with zipfile.ZipFile(
            temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
        ) as zf:
            for directory in ("books", "checkpoints", "migrations"):
                info = zipfile.ZipInfo(directory.rstrip("/") + "/")
                info.date_time = (1980, 1, 1, 0, 0, 0)
                info.external_attr = 0o755 << 16
                zf.writestr(info, b"")
            files = sorted(path for path in root.rglob("*") if path.is_file())
            for path in files:
                if path.resolve() in {output, temporary}:
                    continue
                if "__pycache__" in path.parts:
                    continue
                relative = path.relative_to(root).as_posix()
                if relative.startswith("checkpoints/") and relative.endswith(".zip"):
                    continue
                info = zipfile.ZipInfo(relative)
                info.date_time = (1980, 1, 1, 0, 0, 0)
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o644 << 16
                zf.writestr(info, path.read_bytes())
        os.replace(temporary, output)
    finally:
        temporary.unlink(missing_ok=True)


def initialize_synthetic(root: Path) -> dict[str, Any]:
    if root.exists() and any(root.iterdir()):
        raise CampaignError(f"synthetic target is not empty: {root}")
    root.mkdir(parents=True, exist_ok=True)
    for directory in ("books", "checkpoints", "migrations"):
        (root / directory).mkdir(parents=True, exist_ok=True)
    (root / "AI_DM_RUNTIME_PRIMER.md").write_text(
        "# Synthetic Campaign Runtime Primer\n\n"
        "Campaign-free Contract 1.1 validation fixture. Player sovereignty is absolute.\n",
        encoding="utf-8",
    )
    (root / "STORY_SO_FAR.md").write_text(
        "# Story So Far\n\n"
        "The expedition has reached the Glass Observatory. No action is pending.\n",
        encoding="utf-8",
    )
    atomic_write_json(
        root / "migrations" / "NORMALIZATION_REGISTER.json",
        {"normalizations": [], "synthetic": True},
    )
    con = connect(root)
    con.executescript(SCHEMA)
    created = "2026-07-28T00:00:00+00:00"
    con.execute(
        """
        INSERT INTO campaign_metadata(
            campaign_id,campaign_schema_version,engine_contract_version,
            compatible_engine,production,genesis_id,genesis_hash,created_at
        ) VALUES(?,?,?,?,?,?,?,?)
        """,
        (
            "synthetic-glass-observatory",
            "1.1",
            CONTRACT_VERSION,
            f"AI-DM Engine >={ENGINE_VERSION}",
            0,
            "genesis:synthetic-glass-observatory",
            ZERO_HASH,
            created,
        ),
    )
    campaign_time = {
        "axis": "synthetic-local",
        "day": 1,
        "phase": "evening",
        "elapsed_minutes": 0,
    }
    con.execute(
        """
        INSERT INTO campaign_status(
            singleton,phase,campaign_time_json,location,condition_json,
            resources_json,notes_json,provenance,last_changed_state_head
        ) VALUES(1,?,?,?,?,?,?,?,?)
        """,
        (
            "Narrative",
            canonical_json(campaign_time),
            "Glass Observatory",
            canonical_json({"strain": 0, "health": "stable"}),
            canonical_json({"actions": 3, "credits": 40}),
            canonical_json(["Synthetic fixture; no production campaign facts."]),
            "EXACT",
            "PENDING",
        ),
    )
    con.execute(
        """
        INSERT INTO ledger_entry(
            entry_id,campaign_time_json,account,amount,unit,memo,
            provenance,visibility,last_changed_state_head
        ) VALUES(?,?,?,?,?,?,?,?,?)
        """,
        (
            "ledger:genesis:credits",
            canonical_json(campaign_time),
            "credits",
            40,
            "credit",
            "Synthetic starting balance",
            "EXACT",
            "VISIBLE",
            "PENDING",
        ),
    )
    con.execute(
        """
        INSERT INTO progress_instance(
            progress_id,model_type,title,owner_id,status,visibility,
            state_json,prerequisites_json,blockers_json,dependencies_json,
            source_authority,created_at_campaign_time,last_changed_state_head,
            legacy_progress_json
        ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,NULL)
        """,
        (
            "progress:align-observatory",
            "STAGED_PROJECT",
            "Align the Observatory",
            "player-character",
            "ACTIVE",
            "VISIBLE",
            canonical_json(
                {
                    "stages": ["survey", "align", "verify"],
                    "current_stage": "survey",
                    "completed_stages": [],
                }
            ),
            "[]",
            "[]",
            "[]",
            "EXACT",
            canonical_json(campaign_time),
            "PENDING",
        ),
    )
    con.execute(
        """
        INSERT INTO timeline_event(
            event_id,campaign_time_json,summary,provenance,
            visibility,last_changed_state_head
        ) VALUES(?,?,?,?,?,?)
        """,
        (
            "event:genesis:arrival",
            canonical_json(campaign_time),
            "The expedition reached the Glass Observatory.",
            "EXACT",
            "VISIBLE",
            "PENDING",
        ),
    )
    con.execute(
        """
        INSERT INTO recap_entry(
            recap_id,campaign_time_json,text,provenance,
            visibility,last_changed_state_head
        ) VALUES(?,?,?,?,?,?)
        """,
        (
            "recap:genesis",
            canonical_json(campaign_time),
            "The expedition is at the Glass Observatory with three Actions and forty credits.",
            "EXACT",
            "VISIBLE",
            "PENDING",
        ),
    )
    con.execute(
        """
        INSERT INTO sealed_state(
            sealed_id,scope,payload_json,provenance,last_changed_state_head
        ) VALUES(?,?,?,?,?)
        """,
        (
            "sealed:synthetic:signal",
            "observatory-mystery",
            canonical_json(
                {
                    "private_test_token": "SYNTHETIC-SEALED-ORCHID-7F91C2",
                    "truth": "The signal is a calibration echo.",
                }
            ),
            "SEALED",
            "PENDING",
        ),
    )
    snapshot_hash = hash_json(domain_snapshot(con))
    genesis_head = "state:" + hash_json(
        {
            "prior_state_head": "GENESIS_ZERO",
            "turn_id": "GENESIS",
            "domain_snapshot_sha256": snapshot_hash,
        }
    )
    genesis_delta = {
        "full_genesis_establishment": True,
        "campaign_id": "synthetic-glass-observatory",
    }
    receipt = {
        "status": "PASS",
        "contract": CONTRACT_VERSION,
        "synthetic": True,
        "player_sovereignty": "PASS",
    }
    core = {
        "turn_id": "GENESIS",
        "declaration": "GENESIS",
        "prior_state_head": "GENESIS_ZERO",
        "resulting_state_head": genesis_head,
        "previous_transaction_hash": ZERO_HASH,
        "phase_before": "Control",
        "phase_after": "Narrative",
        "campaign_time_before": {"axis": "GENESIS_ZERO"},
        "campaign_time_after": campaign_time,
        "domain_delta": genesis_delta,
        "validation_receipt": receipt,
        "source_references": ["synthetic-fixture:v1.1"],
        "committed": True,
    }
    genesis_transaction_hash = hash_json(core)
    genesis_transaction_id = f"txn:{genesis_transaction_hash[:32]}"
    con.execute(
        """
        INSERT INTO transaction_log(
            seq,transaction_id,turn_id,declaration,declaration_sha256,
            prior_state_head,resulting_state_head,previous_transaction_hash,
            transaction_hash,phase_before,phase_after,
            campaign_time_before_json,campaign_time_after_json,
            domain_delta_json,validation_receipt_json,source_references_json,
            committed,committed_at
        ) VALUES(0,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """,
        (
            genesis_transaction_id,
            "GENESIS",
            "GENESIS",
            sha256_text("GENESIS"),
            "GENESIS_ZERO",
            genesis_head,
            ZERO_HASH,
            genesis_transaction_hash,
            "Control",
            "Narrative",
            canonical_json({"axis": "GENESIS_ZERO"}),
            canonical_json(campaign_time),
            canonical_json(genesis_delta),
            canonical_json(receipt),
            canonical_json(["synthetic-fixture:v1.1"]),
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
            f"UPDATE {table} SET last_changed_state_head=? "
            "WHERE last_changed_state_head='PENDING'",
            (genesis_head,),
        )
    con.execute(
        """
        INSERT INTO state_head(
            singleton,state_head_id,transaction_hash,campaign_time_json,updated_at
        ) VALUES(1,?,?,?,?)
        """,
        (
            genesis_head,
            genesis_transaction_hash,
            canonical_json(campaign_time),
            created,
        ),
    )
    con.execute(
        """
        INSERT INTO manifest_recovery(
            singleton,target_state_head,target_transaction_hash,pending,updated_at
        ) VALUES(1,?,?,0,?)
        """,
        (genesis_head, genesis_transaction_hash, created),
    )
    rebuild_projections(con, genesis_head, genesis_transaction_hash, None)
    con.commit()
    con.close()

    base_manifest = {
        "campaign_package_version": "1.1",
        "created_at": created,
    }
    atomic_write_json(
        root / "CAMPAIGN_MANIFEST.json",
        manifest_from_database(root, base_manifest),
    )
    validation = validate_campaign(root)
    if validation["status"] != "PASS":
        raise CampaignError(f"synthetic fixture failed validation: {validation['errors']}")
    return validation


def load_delta(args: argparse.Namespace) -> dict[str, Any]:
    if args.delta_file:
        return read_json(Path(args.delta_file).expanduser().resolve())
    if args.delta_json:
        try:
            return json.loads(args.delta_json)
        except json.JSONDecodeError as exc:
            raise CampaignError(f"--delta-json is invalid: {exc}") from exc
    return {}


def parse_json_arg(value: str | None, label: str) -> Any | None:
    if value is None:
        return None
    try:
        return json.loads(value)
    except json.JSONDecodeError as exc:
        raise CampaignError(f"{label} is invalid JSON: {exc}") from exc


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="AI-DM 4 Engine Contract-1.1 Campaign tool"
    )
    sub = parser.add_subparsers(dest="operation", required=True)

    init = sub.add_parser("init-synthetic")
    init.add_argument("--campaign", required=True)

    validate = sub.add_parser("validate")
    validate.add_argument("--campaign", required=True)

    command = sub.add_parser("command")
    command.add_argument("--campaign", required=True)
    command.add_argument("--name", required=True)
    command.add_argument("--output")

    turn = sub.add_parser("turn")
    turn.add_argument("--campaign", required=True)
    turn.add_argument("--turn-id", required=True)
    turn.add_argument("--declaration", required=True)
    delta_group = turn.add_mutually_exclusive_group()
    delta_group.add_argument("--delta-file")
    delta_group.add_argument("--delta-json")
    turn.add_argument("--expected-head")
    turn.add_argument("--phase-after")
    turn.add_argument("--campaign-time-after-json")
    turn.add_argument("--output")

    checkpoint = sub.add_parser("checkpoint")
    checkpoint.add_argument("--campaign", required=True)
    checkpoint.add_argument("--output", required=True)

    export = sub.add_parser("export")
    export.add_argument("--campaign", required=True)
    export.add_argument("--output", required=True)

    repair = sub.add_parser("repair-manifest")
    repair.add_argument("--campaign", required=True)

    return parser


def execute(args: argparse.Namespace) -> dict[str, Any]:
    if args.operation == "init-synthetic":
        root = Path(args.campaign).expanduser().resolve()
        return initialize_synthetic(root)

    with CampaignBinding.open(args.campaign) as binding:
        if args.operation == "validate":
            return validate_campaign(binding.root)
        if args.operation == "command":
            if args.name.lower().lstrip("/") == "save":
                target = binding.require_write_target(args.output)
                if target is None:
                    raise CampaignError("/save requires --output")
                return checkpoint_campaign(binding.root, target)
            return command_projection(binding.root, args.name)
        if args.operation == "turn":
            target = binding.require_write_target(args.output)
            result = commit_turn(
                binding.root,
                turn_id=args.turn_id,
                declaration=args.declaration,
                delta=load_delta(args),
                expected_head=args.expected_head,
                phase_after=args.phase_after,
                campaign_time_after=parse_json_arg(
                    args.campaign_time_after_json, "--campaign-time-after-json"
                ),
            )
            if target is not None:
                export_campaign(binding.root, target)
                result["artifact"] = str(target)
                result["artifact_sha256"] = sha256_file(target)
            return result
        if args.operation == "checkpoint":
            target = binding.require_write_target(args.output)
            if target is None:
                target = Path(args.output).expanduser().resolve()
            return checkpoint_campaign(binding.root, target)
        if args.operation == "export":
            target = Path(args.output).expanduser().resolve()
            if binding.is_zip and target == binding.source:
                raise CampaignError("refusing to overwrite the supplied Campaign ZIP")
            validation = validate_campaign(binding.root)
            if validation["status"] != "PASS":
                raise CampaignError(
                    f"Campaign validation failed: {validation['errors']}"
                )
            export_campaign(binding.root, target)
            return {
                "status": "PASS",
                "artifact": str(target),
                "artifact_sha256": sha256_file(target),
                "state_head": validation["state_head"],
                "transaction_hash": validation["transaction_hash"],
            }
        if args.operation == "repair-manifest":
            if binding.is_zip:
                raise CampaignError(
                    "repair-manifest requires a directory Campaign; "
                    "extract a disposable copy first"
                )
            changed = sync_manifest(binding.root)
            validation = validate_campaign(binding.root)
            return {
                "status": validation["status"],
                "manifest_rewritten": changed,
                "validation": validation,
            }
    raise CampaignError(f"unsupported operation: {args.operation}")


def main(argv: Iterable[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(list(argv) if argv is not None else None)
    try:
        result = execute(args)
    except (CampaignError, KeyError, ValueError, sqlite3.Error, OSError) as exc:
        print(
            json.dumps(
                {
                    "status": "FAIL",
                    "error": str(exc),
                    "operation": args.operation,
                },
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            )
        )
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if result.get("status") != "FAIL" else 1


if __name__ == "__main__":
    raise SystemExit(main())
