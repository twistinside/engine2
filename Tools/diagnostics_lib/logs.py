"""Unified-log archival and small textual evidence inspection."""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
import json
from pathlib import Path
import subprocess
from typing import Any, Callable


SUBSYSTEM = "com.example.Engine2"


class LogCapturePolicy(str, Enum):
    """Whether unified-log evidence is required in this environment."""

    REQUIRED = "required"
    BEST_EFFORT = "best-effort"
    SKIP = "skip"


@dataclass(frozen=True)
class LogInspection:
    """Counts that prevent absence, privacy, and loss from being conflated."""

    record_count: int
    redacted_record_count: int
    loss_record_count: int


def capture_logs(
    output: Path,
    start_unix_seconds: float,
    session_id: str,
    runner: Callable[..., subprocess.CompletedProcess[bytes]] = subprocess.run,
) -> dict[str, Any]:
    """Preserve a native archive and a session-filtered NDJSON projection."""

    archive = output / "unified.logarchive"
    # `log` documents Unix time but rejects fractional forms on some macOS
    # versions. Rounding down includes the full launch second.
    start = f"@{int(start_unix_seconds)}"
    collect_command = [
        "/usr/bin/log",
        "collect",
        "--start",
        start,
        "--predicate",
        f'subsystem == "{SUBSYSTEM}"',
        "--output",
        str(archive),
    ]
    collected = runner(collect_command, capture_output=True, check=False)
    if collected.returncode != 0:
        return _failure("log-collect-failure", collected)

    predicate = (
        f'(subsystem == "{SUBSYSTEM}" AND composedMessage CONTAINS "{session_id}") '
        "OR type == lossEvent"
    )
    show_command = [
        "/usr/bin/log",
        "show",
        "--archive",
        str(archive),
        "--style",
        "ndjson",
        "--info",
        "--debug",
        "--signpost",
        "--loss",
        "--start",
        start,
        "--predicate",
        predicate,
    ]
    shown = runner(show_command, capture_output=True, check=False)
    if shown.returncode != 0:
        return _failure("log-show-failure", shown)

    inspection = inspect_log_ndjson(shown.stdout)
    (output / "engine2.log.ndjson").write_bytes(shown.stdout)
    return {
        "status": "complete",
        "recordCount": inspection.record_count,
        "redactedRecordCount": inspection.redacted_record_count,
        "lossRecordCount": inspection.loss_record_count,
    }


def inspect_log_ndjson(data: bytes) -> LogInspection:
    """Count valid records plus explicit redaction and loss evidence."""

    records: list[dict[str, Any]] = []
    for line in data.splitlines():
        if not line.strip():
            continue
        value = json.loads(line)
        if not isinstance(value, dict):
            raise ValueError("unified log line is not an object")
        records.append(value)

    redacted = 0
    loss = 0
    for record in records:
        encoded = json.dumps(record, sort_keys=True).lower()
        if "<private>" in encoded or "<redacted>" in encoded:
            redacted += 1
        record_type = str(record.get("type", record.get("eventType", ""))).lower()
        if "loss" in record_type:
            loss += 1
    return LogInspection(len(records), redacted, loss)


def _failure(reason: str, completed: subprocess.CompletedProcess[bytes]) -> dict[str, Any]:
    return {
        "status": "unavailable",
        "reason": reason,
        "exitCode": completed.returncode,
        "standardError": completed.stderr.decode("utf-8", errors="replace"),
    }
