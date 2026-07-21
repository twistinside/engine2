"""Deterministic JSON-first summaries for Engine2 diagnostic streams."""

from __future__ import annotations

from collections import Counter, defaultdict
from dataclasses import dataclass
import json
import math
from pathlib import Path
from typing import Any, Iterable

from .artifact import ValidatedArtifact, validate_file


@dataclass(frozen=True)
class Measurement:
    """One explicitly unit-bearing value used in a distribution."""

    value: float
    unit: str


def summarize_capture(capture_path: Path) -> dict[str, Any]:
    """Validate a capture and derive both human and machine summaries."""

    artifact = validate_file(capture_path / "diagnostics.ndjson")
    summary = calculate_summary(artifact)
    summary_path = capture_path / "summary.json"
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (capture_path / "summary.md").write_text(render_markdown(summary), encoding="utf-8")
    return summary


def calculate_summary(artifact: ValidatedArtifact) -> dict[str, Any]:
    """Aggregate durations, normalized costs, structure, and correctness."""

    kind_counts: Counter[str] = Counter()
    durations: dict[str, list[Measurement]] = defaultdict(list)
    normalized: dict[str, list[Measurement]] = defaultdict(list)
    inventories: list[dict[str, Any]] = []
    step_ticks: list[int] = []
    presentation_ticks: list[int] = []
    systems_by_tick: dict[int, list[str]] = defaultdict(list)

    for record in artifact.records[1:]:
        payload = record["sample"]["payload"]
        kind, value = payload_entry(payload)
        kind_counts[kind] += 1
        if kind == "simulationRuntimeInventory":
            inventories.append(value)
        if kind == "simulationStep":
            step_ticks.append(_tick(value))
        elif kind == "presentationSnapshot":
            presentation_ticks.append(_tick(value))
        elif kind == "systemUpdate":
            tick = _tick(value)
            system_id = value["systemID"]
            systems_by_tick[tick].append(system_id)

        duration = value.get("durationNanoseconds")
        if isinstance(duration, int):
            distribution_id = kind
            if kind == "systemUpdate":
                distribution_id = f"systemUpdate.{value['systemID']}"
            durations[distribution_id].append(Measurement(float(duration), "nanoseconds"))
            work_count = value.get("workCount")
            if isinstance(work_count, int) and work_count > 0:
                normalized[distribution_id].append(
                    Measurement(duration / work_count, "nanoseconds-per-work-unit")
                )

    failures: list[str] = []
    missing: list[str] = []
    if not inventories:
        missing.append("simulationRuntimeInventory")
    if not step_ticks:
        missing.append("simulationStep")
    if step_ticks and not _is_contiguous(step_ticks):
        failures.append("simulation step ticks are not contiguous")
    if step_ticks != presentation_ticks:
        failures.append("presentation snapshot ticks do not match completed step ticks")

    latest_inventory = inventories[-1] if inventories else None
    if latest_inventory is not None and step_ticks:
        expected_systems = [
            *latest_inventory.get("alwaysSystemIDs", []),
            *latest_inventory.get("simulationSystemIDs", []),
        ]
        for tick in step_ticks:
            if systems_by_tick.get(tick) != expected_systems:
                failures.append(f"tick {tick} does not match the invariant system schedule")
                break

    return {
        "schemaVersion": 1,
        "manifest": artifact.manifest,
        "sampleCount": len(artifact.records) - 1,
        "sampleKindCounts": dict(sorted(kind_counts.items())),
        "distributions": {
            name: summarize_measurements(values) for name, values in sorted(durations.items())
        },
        "normalizedDistributions": {
            name: summarize_measurements(values) for name, values in sorted(normalized.items())
        },
        "structuralInventory": latest_inventory,
        "tickRange": {
            "first": step_ticks[0] if step_ticks else None,
            "last": step_ticks[-1] if step_ticks else None,
            "count": len(step_ticks),
        },
        "missingEvidence": missing,
        "correctnessFailures": failures,
    }


def summarize_measurements(measurements: Iterable[Measurement]) -> dict[str, Any]:
    """Use nearest-rank percentiles and reject mixed-unit arithmetic."""

    values = list(measurements)
    if not values:
        raise ValueError("cannot summarize an empty measurement collection")
    units = {measurement.unit for measurement in values}
    if len(units) != 1:
        raise ValueError(f"cannot combine incompatible units: {sorted(units)}")
    ordered = sorted(measurement.value for measurement in values)
    return {
        "unit": values[0].unit,
        "count": len(ordered),
        "p50": _nearest_rank(ordered, 0.50),
        "p95": _nearest_rank(ordered, 0.95),
        "p99": _nearest_rank(ordered, 0.99),
        "maximum": ordered[-1],
    }


def render_markdown(summary: dict[str, Any]) -> str:
    """Render only from summary JSON so the two views cannot drift."""

    manifest = summary["manifest"]
    lines = [
        "# Engine2 Diagnostics Summary",
        "",
        f"- Scenario: `{manifest['scenarioID']}`",
        f"- Build: `{manifest['buildConfiguration']}`",
        f"- Samples: {summary['sampleCount']}",
        f"- Ticks: {summary['tickRange']['count']}",
        "",
        "## Duration distributions",
        "",
        "| Measurement | Count | p50 | p95 | p99 | Maximum | Unit |",
        "| --- | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for name, distribution in summary["distributions"].items():
        lines.append(
            f"| {name} | {distribution['count']} | {distribution['p50']:g} | "
            f"{distribution['p95']:g} | {distribution['p99']:g} | "
            f"{distribution['maximum']:g} | {distribution['unit']} |"
        )
    lines.extend(["", "## Evidence", ""])
    lines.append(f"- Missing: {', '.join(summary['missingEvidence']) or 'none'}")
    lines.append(f"- Correctness failures: {', '.join(summary['correctnessFailures']) or 'none'}")
    return "\n".join(lines) + "\n"


def payload_entry(payload: dict[str, Any]) -> tuple[str, dict[str, Any]]:
    if len(payload) != 1:
        raise ValueError("sample payload must have exactly one case")
    kind, encoded = next(iter(payload.items()))
    if not isinstance(encoded, dict) or not isinstance(encoded.get("_0"), dict):
        raise ValueError(f"sample payload {kind} does not contain its typed value")
    return kind, encoded["_0"]


def _nearest_rank(ordered: list[float], percentile: float) -> float:
    rank = max(1, math.ceil(percentile * len(ordered)))
    return ordered[rank - 1]


def _tick(value: dict[str, Any]) -> int:
    return value["tick"]["rawValue"]


def _is_contiguous(values: list[int]) -> bool:
    return all(right == left + 1 for left, right in zip(values, values[1:]))
