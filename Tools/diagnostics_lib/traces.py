"""Instruments recording and schema-checked textual trace export."""

from __future__ import annotations

from enum import Enum
import json
from pathlib import Path
import shutil
import subprocess
from typing import Any, Callable
import xml.etree.ElementTree as ET


class TraceCapturePolicy(str, Enum):
    """Whether Instruments evidence is required in this environment."""

    REQUIRED = "required"
    BEST_EFFORT = "best-effort"
    SKIP = "skip"


def capture_trace(
    output: Path,
    app_executable: Path,
    scenario_arguments: list[str],
    runner: Callable[..., subprocess.CompletedProcess[bytes]] = subprocess.run,
) -> dict[str, Any]:
    """Record a native trace, retain its ToC, and export known signpost tables."""

    xctrace = shutil.which("xctrace")
    if xctrace is None:
        return {"status": "unavailable", "reason": "xctrace-not-found"}

    tool_root = Path(__file__).resolve().parent.parent
    configuration_path = tool_root / "diagnostics-trace.json"
    configuration = json.loads(configuration_path.read_text(encoding="utf-8"))
    recording_options = output / "xctrace-recording-options.json"
    recording_options.write_text(
        json.dumps(configuration["recordingOptions"], indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    trace_path = output / "diagnostics.trace"
    # Launching through `env` makes the explicit product path authoritative;
    # xctrace otherwise resolves duplicate Engine2 bundles by display name.
    record_command = [
        xctrace,
        "record",
        "--quiet",
        "--template",
        "Time Profiler",
        "--recording-options",
        str(recording_options),
        "--output",
        str(trace_path),
        "--no-prompt",
        "--target-stdout",
        "/dev/null",
        "--launch",
        "--",
        "/usr/bin/env",
        str(app_executable),
        *scenario_arguments,
    ]
    recorded = runner(record_command, capture_output=True, check=False)
    if recorded.returncode != 0:
        return _failure("xctrace-record-failure", recorded)

    toc_path = output / "trace-toc.xml"
    export_toc_command = [xctrace, "export", str(trace_path), "--toc", "--output", str(toc_path)]
    toc_result = runner(export_toc_command, capture_output=True, check=False)
    if toc_result.returncode != 0:
        return _failure("xctrace-toc-export-failure", toc_result)

    known_schemas = set(configuration["knownSignpostSchemas"])
    present_schemas = inspect_toc(toc_path.read_bytes())
    selected_schemas = sorted(known_schemas.intersection(present_schemas))
    if not selected_schemas:
        return {
            "status": "unavailable",
            "reason": "unrecognized-signpost-table-schema",
            "presentSchemas": sorted(present_schemas),
        }

    exported_schemas: list[str] = []
    for schema in selected_schemas:
        destination = output / f"trace-{schema}.xml"
        xpath = f'/trace-toc/run/data/table[@schema="{schema}"]'
        export_command = [
            xctrace,
            "export",
            str(trace_path),
            "--xpath",
            xpath,
            "--output",
            str(destination),
        ]
        exported = runner(export_command, capture_output=True, check=False)
        if exported.returncode != 0:
            return _failure("xctrace-table-export-failure", exported, schema=schema)
        exported_schemas.append(schema)

    return {
        "status": "complete",
        "presentSchemas": sorted(present_schemas),
        "exportedSignpostSchemas": exported_schemas,
    }


def inspect_toc(data: bytes) -> set[str]:
    """Return all table schema identities from an exported xctrace ToC."""

    root = ET.fromstring(data)
    return {
        schema
        for table in root.iter("table")
        if (schema := table.attrib.get("schema")) is not None
    }


def _failure(
    reason: str,
    completed: subprocess.CompletedProcess[bytes],
    **details: Any,
) -> dict[str, Any]:
    return {
        "status": "unavailable",
        "reason": reason,
        "exitCode": completed.returncode,
        "standardError": completed.stderr.decode("utf-8", errors="replace"),
        **details,
    }
