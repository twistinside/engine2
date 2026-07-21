from __future__ import annotations

import copy
import unittest

from diagnostics_lib.comparison import ComparisonExitCode, compare_summaries


def summary() -> dict:
    return {
        "manifest": {
            "schemaVersion": 1,
            "scenarioID": "baseline-six-ball",
            "scenarioSchemaVersion": 1,
            "buildConfiguration": "release",
            "randomSeed": 42,
            "fixedStepNanoseconds": 16_666_666,
            "warmUpNanoseconds": 1,
            "measurementNanoseconds": 2,
        },
        "environment": {
            "schemaVersion": 1,
            "machineArchitecture": "arm64",
            "machineModel": "MacFixture",
            "operatingSystem": "Darwin",
            "operatingSystemVersion": "27.0",
        },
        "distributions": {
            "simulationStep": {"unit": "nanoseconds", "p95": 100},
        },
        "structuralInventory": {"presentationEntityCount": 6},
        "missingEvidence": [],
        "correctnessFailures": [],
    }


class ComparisonTests(unittest.TestCase):
    def test_identical_and_improved_captures_pass(self) -> None:
        baseline = summary()
        self.assertEqual(compare_summaries(baseline, copy.deepcopy(baseline))["exitCode"], ComparisonExitCode.PASS)
        improved = copy.deepcopy(baseline)
        improved["distributions"]["simulationStep"]["p95"] = 90
        self.assertEqual(compare_summaries(baseline, improved)["exitCode"], ComparisonExitCode.PASS)

    def test_regression_has_a_distinct_exit_code(self) -> None:
        baseline = summary()
        regressed = copy.deepcopy(baseline)
        regressed["distributions"]["simulationStep"]["p95"] = 110
        self.assertEqual(compare_summaries(baseline, regressed)["exitCode"], ComparisonExitCode.REGRESSION)

    def test_incompatible_hardware_and_scenario_are_rejected_first(self) -> None:
        baseline = summary()
        hardware = copy.deepcopy(baseline)
        hardware["environment"]["machineModel"] = "AnotherMac"
        self.assertEqual(compare_summaries(baseline, hardware)["exitCode"], ComparisonExitCode.INCOMPATIBLE)
        scenario = copy.deepcopy(baseline)
        scenario["manifest"]["scenarioID"] = "future-scenario"
        self.assertEqual(compare_summaries(baseline, scenario)["exitCode"], ComparisonExitCode.INCOMPATIBLE)

    def test_missing_artifact_and_correctness_failure_are_distinct(self) -> None:
        baseline = summary()
        missing = copy.deepcopy(baseline)
        missing["missingEvidence"] = ["simulationStep"]
        self.assertEqual(compare_summaries(baseline, missing)["exitCode"], ComparisonExitCode.MISSING_EVIDENCE)
        incorrect = copy.deepcopy(baseline)
        incorrect["correctnessFailures"] = ["ticks skipped"]
        self.assertEqual(compare_summaries(baseline, incorrect)["exitCode"], ComparisonExitCode.CORRECTNESS_FAILURE)


if __name__ == "__main__":
    unittest.main()
