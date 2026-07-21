"""Compatibility-first comparisons for Engine2 capture summaries."""

from __future__ import annotations

from enum import IntEnum
import json
from pathlib import Path
from typing import Any


class ComparisonExitCode(IntEnum):
    """Stable automation outcomes with no ambiguous generic failure."""

    PASS = 0
    INCOMPATIBLE = 2
    MISSING_EVIDENCE = 3
    CORRECTNESS_FAILURE = 4
    REGRESSION = 5


COMPATIBLE_MANIFEST_FIELDS = (
    "schemaVersion",
    "scenarioID",
    "scenarioSchemaVersion",
    "buildConfiguration",
    "randomSeed",
    "fixedStepNanoseconds",
    "warmUpNanoseconds",
    "measurementNanoseconds",
)
COMPATIBLE_ENVIRONMENT_FIELDS = (
    "schemaVersion",
    "machineArchitecture",
    "machineModel",
    "operatingSystem",
    "operatingSystemVersion",
)


def compare_captures(baseline_path: Path, candidate_path: Path) -> dict[str, Any]:
    """Compare existing summaries and persist the candidate-side result."""

    baseline = _read_summary(baseline_path)
    candidate = _read_summary(candidate_path)
    result = compare_summaries(baseline, candidate)
    (candidate_path / "comparison.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    (candidate_path / "comparison.md").write_text(render_comparison_markdown(result), encoding="utf-8")
    return result


def compare_summaries(baseline: dict[str, Any], candidate: dict[str, Any]) -> dict[str, Any]:
    """Stop at incompatibility or bad evidence before calculating deltas."""

    incompatibilities = _compatibility_differences(baseline, candidate)
    if incompatibilities:
        return _result(ComparisonExitCode.INCOMPATIBLE, incompatibilities=incompatibilities)

    missing = sorted(set(baseline.get("missingEvidence", [])) | set(candidate.get("missingEvidence", [])))
    baseline_distributions = baseline.get("distributions", {})
    candidate_distributions = candidate.get("distributions", {})
    missing.extend(sorted(set(baseline_distributions) ^ set(candidate_distributions)))
    if missing:
        return _result(ComparisonExitCode.MISSING_EVIDENCE, missingEvidence=sorted(set(missing)))

    failures = [
        *baseline.get("correctnessFailures", []),
        *candidate.get("correctnessFailures", []),
    ]
    if baseline.get("structuralInventory") != candidate.get("structuralInventory"):
        failures.append("structural inventory changed")
    if failures:
        return _result(ComparisonExitCode.CORRECTNESS_FAILURE, correctnessFailures=failures)

    deltas: dict[str, Any] = {}
    regressed: list[str] = []
    for name in sorted(baseline_distributions):
        before = baseline_distributions[name]
        after = candidate_distributions[name]
        if before["unit"] != after["unit"]:
            return _result(
                ComparisonExitCode.INCOMPATIBLE,
                incompatibilities=[f"distribution unit changed: {name}"],
            )
        before_p95 = float(before["p95"])
        after_p95 = float(after["p95"])
        absolute = after_p95 - before_p95
        percent = None if before_p95 == 0 else absolute / before_p95 * 100
        deltas[name] = {
            "unit": before["unit"],
            "baselineP95": before_p95,
            "candidateP95": after_p95,
            "absoluteP95Delta": absolute,
            "percentP95Delta": percent,
        }
        if absolute > 0:
            regressed.append(name)

    code = ComparisonExitCode.REGRESSION if regressed else ComparisonExitCode.PASS
    return _result(code, deltas=deltas, regressedDistributions=regressed)


def render_comparison_markdown(result: dict[str, Any]) -> str:
    lines = [
        "# Engine2 Diagnostics Comparison",
        "",
        f"- Status: `{result['status']}`",
        f"- Exit code: {result['exitCode']}",
    ]
    if result.get("incompatibilities"):
        lines.extend(["", "## Incompatibilities", ""])
        lines.extend(f"- {value}" for value in result["incompatibilities"])
    if result.get("missingEvidence"):
        lines.extend(["", "## Missing evidence", ""])
        lines.extend(f"- {value}" for value in result["missingEvidence"])
    if result.get("correctnessFailures"):
        lines.extend(["", "## Correctness failures", ""])
        lines.extend(f"- {value}" for value in result["correctnessFailures"])
    if result.get("deltas"):
        lines.extend(
            [
                "",
                "## p95 deltas",
                "",
                "| Measurement | Baseline | Candidate | Delta | Percent | Unit |",
                "| --- | ---: | ---: | ---: | ---: | --- |",
            ]
        )
        for name, delta in result["deltas"].items():
            percent = delta["percentP95Delta"]
            percent_text = "n/a" if percent is None else f"{percent:+.2f}%"
            lines.append(
                f"| {name} | {delta['baselineP95']:g} | {delta['candidateP95']:g} | "
                f"{delta['absoluteP95Delta']:+g} | {percent_text} | {delta['unit']} |"
            )
    return "\n".join(lines) + "\n"


def _compatibility_differences(
    baseline: dict[str, Any], candidate: dict[str, Any]
) -> list[str]:
    differences: list[str] = []
    baseline_manifest = baseline.get("manifest") or {}
    candidate_manifest = candidate.get("manifest") or {}
    baseline_environment = baseline.get("environment") or {}
    candidate_environment = candidate.get("environment") or {}
    for field in COMPATIBLE_MANIFEST_FIELDS:
        if baseline_manifest.get(field) != candidate_manifest.get(field):
            differences.append(f"manifest field differs: {field}")
    for field in COMPATIBLE_ENVIRONMENT_FIELDS:
        if baseline_environment.get(field) != candidate_environment.get(field):
            differences.append(f"environment field differs: {field}")
    return differences


def _result(code: ComparisonExitCode, **details: Any) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "status": code.name.lower().replace("_", "-"),
        "exitCode": int(code),
        **details,
    }


def _read_summary(capture_path: Path) -> dict[str, Any]:
    path = capture_path / "summary.json"
    if not path.is_file():
        raise FileNotFoundError(f"summary does not exist: {path}")
    return json.loads(path.read_text(encoding="utf-8"))
