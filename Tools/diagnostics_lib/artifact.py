"""Strict validation for the versioned Engine2 NDJSON stream."""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
from typing import Any


CURRENT_SCHEMA_VERSION = 2


class ArtifactValidationError(ValueError):
    """The stream is present but is not trustworthy diagnostic evidence."""


@dataclass(frozen=True)
class ValidatedArtifact:
    """Decoded records whose manifest, shape, and session agree."""

    manifest: dict[str, Any]
    records: tuple[dict[str, Any], ...]


def validate_ndjson(data: bytes) -> ValidatedArtifact:
    """Reject truncated, empty, mixed-session, or unsupported streams."""

    if not data.endswith(b"\n"):
        raise ArtifactValidationError("diagnostics.ndjson is truncated")
    raw_lines = data[:-1].split(b"\n")
    if not raw_lines or raw_lines == [b""]:
        raise ArtifactValidationError("diagnostics.ndjson is empty")
    if any(not line for line in raw_lines):
        raise ArtifactValidationError("diagnostics.ndjson contains an empty record")

    try:
        records = tuple(json.loads(line) for line in raw_lines)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ArtifactValidationError(f"invalid JSON record: {error}") from error

    first = records[0]
    if first.get("kind") != "manifest" or not isinstance(first.get("manifest"), dict):
        raise ArtifactValidationError("the first record must be a manifest")
    manifest = first["manifest"]
    if manifest.get("schemaVersion") != CURRENT_SCHEMA_VERSION:
        raise ArtifactValidationError("unsupported manifest schema version")
    session_id = _session_id(manifest)

    sample_count = 0
    for index, record in enumerate(records, start=1):
        if record.get("schemaVersion") != CURRENT_SCHEMA_VERSION:
            raise ArtifactValidationError(f"record {index} has an unsupported schema version")
        kind = record.get("kind")
        if index == 1:
            if kind != "manifest" or record.get("sample") is not None:
                raise ArtifactValidationError("the first record has an invalid manifest shape")
            continue
        if kind != "sample" or not isinstance(record.get("sample"), dict):
            raise ArtifactValidationError(f"record {index} is not a sample")
        sample = record["sample"]
        if _session_id(sample) != session_id:
            raise ArtifactValidationError(f"record {index} belongs to another session")
        payload = sample.get("payload")
        if not isinstance(payload, dict) or len(payload) != 1:
            raise ArtifactValidationError(f"record {index} has an invalid typed payload")
        sample_count += 1

    if sample_count == 0:
        raise ArtifactValidationError("the stream contains no samples")
    return ValidatedArtifact(manifest=manifest, records=records)


def validate_file(path: Path) -> ValidatedArtifact:
    """Read and validate a diagnostics stream from an explicit path."""

    return validate_ndjson(path.read_bytes())


def _session_id(container: dict[str, Any]) -> str:
    value = container.get("sessionID")
    if not isinstance(value, dict) or not isinstance(value.get("rawValue"), str):
        raise ArtifactValidationError("record is missing a typed session identity")
    return value["rawValue"]
