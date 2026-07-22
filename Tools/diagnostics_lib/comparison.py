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


def compare_captures(
    baseline_path: Path,
    candidate_path: Path,
    budget_path: Path | None = None,
) -> dict[str, Any]:
    """Compare existing summaries and persist the candidate-side result."""

    baseline = _read_summary(baseline_path)
    candidate = _read_summary(candidate_path)
    budget = _read_budget(budget_path) if budget_path is not None else None
    result = compare_summaries(baseline, candidate, budget)
    (candidate_path / "comparison.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    (candidate_path / "comparison.md").write_text(render_comparison_markdown(result), encoding="utf-8")
    return result


def compare_summaries(
    baseline: dict[str, Any],
    candidate: dict[str, Any],
    budget: dict[str, Any] | None = None,
) -> dict[str, Any]:
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

    if budget is None:
        code = ComparisonExitCode.REGRESSION if regressed else ComparisonExitCode.PASS
        return _result(code, deltas=deltas, regressedDistributions=regressed)

    budget_incompatibilities = _budget_compatibility_differences(budget, candidate)
    if budget_incompatibilities:
        return _result(
            ComparisonExitCode.INCOMPATIBLE,
            incompatibilities=budget_incompatibilities,
        )
    budget_missing, violations = _evaluate_budget(budget, candidate)
    if budget_missing:
        return _result(
            ComparisonExitCode.MISSING_EVIDENCE,
            missingEvidence=budget_missing,
        )
    code = ComparisonExitCode.REGRESSION if violations else ComparisonExitCode.PASS
    return _result(
        code,
        deltas=deltas,
        regressedDistributions=regressed,
        budgetMetadata={
            "owner": budget.get("owner"),
            "lastReviewed": budget.get("lastReviewed"),
            "rationale": budget.get("rationale"),
        },
        budgetViolations=violations,
    )


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
    if result.get("budgetMetadata"):
        metadata = result["budgetMetadata"]
        lines.extend(
            [
                "",
                "## Reviewed budget",
                "",
                f"- Owner: {metadata.get('owner')}",
                f"- Last reviewed: {metadata.get('lastReviewed')}",
                f"- Rationale: {metadata.get('rationale')}",
            ]
        )
    if result.get("budgetViolations"):
        lines.extend(["", "## Budget violations", ""])
        lines.extend(f"- {value}" for value in result["budgetViolations"])
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


def _budget_compatibility_differences(
    budget: dict[str, Any], candidate: dict[str, Any]
) -> list[str]:
    differences: list[str] = []
    manifest = candidate.get("manifest") or {}
    environment = candidate.get("environment") or {}
    if budget.get("schemaVersion") != 1:
        differences.append("budget schema version is not supported")
    for field in ("scenarioID", "buildConfiguration"):
        if budget.get(field) != manifest.get(field):
            differences.append(f"budget manifest field differs: {field}")
    for field, expected in (budget.get("environment") or {}).items():
        if environment.get(field) != expected:
            differences.append(f"budget environment field differs: {field}")
    return differences


def _evaluate_budget(
    budget: dict[str, Any], candidate: dict[str, Any]
) -> tuple[list[str], list[str]]:
    missing: list[str] = []
    violations: list[str] = []
    distributions = candidate.get("distributions") or {}
    expected_inventory = budget.get("structuralInventory")
    if expected_inventory is not None and candidate.get("structuralInventory") != expected_inventory:
        violations.append("structural inventory does not match the reviewed budget")
    for name, constraint in sorted((budget.get("distributions") or {}).items()):
        measured = distributions.get(name)
        if measured is None:
            missing.append(name)
            continue
        if measured.get("unit") != constraint.get("unit"):
            violations.append(f"{name} unit is {measured.get('unit')}, expected {constraint.get('unit')}")
            continue
        _append_limit_violation(violations, name, "p95", measured, constraint, "maximumP95")
        _append_limit_violation(violations, name, "maximum", measured, constraint, "maximumValue")
        minimum_count = constraint.get("minimumCount")
        if minimum_count is not None and measured.get("count", 0) < minimum_count:
            violations.append(
                f"{name} count {measured.get('count', 0):g} is below {minimum_count:g}"
            )
    return missing, violations


def _append_limit_violation(
    violations: list[str],
    name: str,
    measurement_field: str,
    measured: dict[str, Any],
    constraint: dict[str, Any],
    constraint_field: str,
) -> None:
    limit = constraint.get(constraint_field)
    value = measured.get(measurement_field)
    if limit is not None and value is not None and value > limit:
        violations.append(f"{name} {measurement_field} {value:g} exceeds {limit:g}")


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


def _read_budget(path: Path) -> dict[str, Any]:
    resolved = path.expanduser().resolve()
    if not resolved.is_file():
        raise FileNotFoundError(f"budget does not exist: {resolved}")
    return json.loads(resolved.read_text(encoding="utf-8"))
