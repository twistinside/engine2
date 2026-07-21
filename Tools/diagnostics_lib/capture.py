"""Launch a built Engine2 app and retain its validated diagnostic stream."""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import subprocess
import time
from typing import Any

from .artifact import ArtifactValidationError, validate_ndjson
from .logs import LogCapturePolicy, capture_logs
from .traces import TraceCapturePolicy, capture_trace
from .summary import summarize_capture


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
    log_policy: LogCapturePolicy = LogCapturePolicy.BEST_EFFORT
    trace_policy: TraceCapturePolicy = TraceCapturePolicy.BEST_EFFORT


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
    start_unix_seconds = time.time()
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
    log_result: dict[str, Any]
    if request.log_policy == LogCapturePolicy.SKIP:
        log_result = {"status": "skipped"}
    else:
        log_result = capture_logs(
            output=request.output,
            start_unix_seconds=start_unix_seconds,
            session_id=artifact.manifest["sessionID"]["rawValue"],
        )
    _write_json(request.output / "logs-result.json", log_result)
    if request.log_policy == LogCapturePolicy.REQUIRED and log_result["status"] != "complete":
        failure = _result(
            status="failed",
            command=command,
            reason="required-unified-logs-unavailable",
            logs=log_result,
        )
        _write_json(result_path, failure)
        raise CaptureError("required unified-log evidence is unavailable")

    trace_result: dict[str, Any]
    if request.trace_policy == TraceCapturePolicy.SKIP:
        trace_result = {"status": "skipped"}
    else:
        trace_result = capture_trace(
            output=request.output,
            app_executable=executable,
            scenario_arguments=command[1:],
        )
    _write_json(request.output / "trace-result.json", trace_result)
    if request.trace_policy == TraceCapturePolicy.REQUIRED and trace_result["status"] != "complete":
        failure = _result(
            status="failed",
            command=command,
            reason="required-instruments-trace-unavailable",
            trace=trace_result,
        )
        _write_json(result_path, failure)
        raise CaptureError("required Instruments trace evidence is unavailable")

    success = _result(
        status="complete",
        command=command,
        sample_count=len(artifact.records) - 1,
        logs=log_result,
        trace=trace_result,
    )
    _write_json(result_path, success)
    summarize_capture(request.output)
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
