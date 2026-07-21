"""Launch a built Engine2 app and retain its validated diagnostic stream."""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import subprocess
from typing import Any

from .artifact import ArtifactValidationError, validate_ndjson


class CaptureError(RuntimeError):
    """A capture could not produce complete, validated evidence."""


@dataclass(frozen=True)
class CaptureRequest:
    """Resolved, explicit inputs for one deterministic app capture."""

    app: Path
    output: Path
    scenario: str
    seed: int
    warm_up_nanoseconds: int
    measurement_nanoseconds: int


def capture(request: CaptureRequest) -> dict[str, Any]:
    """Create one artifact directory, refusing to overwrite prior evidence."""

    if request.output.exists():
        raise CaptureError(f"output already exists: {request.output}")
    executable = _resolve_executable(request.app)
    request.output.mkdir(parents=True)
    result_path = request.output / "capture-result.json"

    command = [
        str(executable),
        "--diagnostics-scenario",
        request.scenario,
        "--diagnostics-seed",
        str(request.seed),
        "--diagnostics-warm-up-nanoseconds",
        str(request.warm_up_nanoseconds),
        "--diagnostics-measurement-nanoseconds",
        str(request.measurement_nanoseconds),
        "--diagnostics-ndjson-stdout",
    ]
    completed = subprocess.run(command, capture_output=True, check=False)
    if completed.returncode != 0:
        failure = _result(
            status="failed",
            command=command,
            reason="child-process-failure",
            exit_code=completed.returncode,
            standard_error=completed.stderr.decode("utf-8", errors="replace"),
        )
        _write_json(result_path, failure)
        raise CaptureError(f"app exited with status {completed.returncode}")

    try:
        artifact = validate_ndjson(completed.stdout)
    except ArtifactValidationError as error:
        failure = _result(
            status="failed",
            command=command,
            reason="invalid-diagnostics-stream",
            detail=str(error),
        )
        _write_json(result_path, failure)
        raise CaptureError(str(error)) from error

    (request.output / "diagnostics.ndjson").write_bytes(completed.stdout)
    _write_json(request.output / "manifest.json", artifact.manifest)
    success = _result(
        status="complete",
        command=command,
        sample_count=len(artifact.records) - 1,
    )
    _write_json(result_path, success)
    return success


def _resolve_executable(app: Path) -> Path:
    resolved = app.expanduser().resolve()
    if resolved.suffix == ".app":
        resolved = resolved / "Contents" / "MacOS" / resolved.stem
    if not resolved.is_file():
        raise CaptureError(f"app executable does not exist: {resolved}")
    return resolved


def _result(status: str, command: list[str], **details: Any) -> dict[str, Any]:
    return {"schemaVersion": 1, "status": status, "command": command, **details}


def _write_json(path: Path, value: dict[str, Any]) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
