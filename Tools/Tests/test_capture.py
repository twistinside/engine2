from __future__ import annotations

import json
from pathlib import Path
import stat
import tempfile
import unittest

from diagnostics_lib.artifact import ArtifactValidationError, validate_ndjson
from diagnostics_lib.capture import CaptureError, CaptureRequest, capture
from diagnostics_lib.cli import build_parser


MANIFEST = {
    "schemaVersion": 1,
    "sessionID": {"rawValue": "00000000-0000-0000-0000-000000000001"},
    "scenarioID": "baseline-six-ball",
    "scenarioSchemaVersion": 1,
    "buildConfiguration": "release",
    "randomSeed": 42,
    "fixedStepNanoseconds": 16_666_666,
    "warmUpNanoseconds": 0,
    "measurementNanoseconds": 16_666_666,
}
SAMPLE = {
    "schemaVersion": 1,
    "kind": "sample",
    "sample": {
        "sessionID": MANIFEST["sessionID"],
        "timestamp": {"nanosecondsSinceSessionStart": 1},
        "category": "simulation.loop",
        "payload": {"simulationStep": {"_0": {"durationNanoseconds": 1}}},
    },
}


def stream() -> bytes:
    records = [
        {"schemaVersion": 1, "kind": "manifest", "manifest": MANIFEST},
        SAMPLE,
    ]
    return b"".join((json.dumps(record) + "\n").encode() for record in records)


class ArtifactTests(unittest.TestCase):
    def test_validation_requires_complete_stream_and_samples(self) -> None:
        self.assertEqual(validate_ndjson(stream()).manifest, MANIFEST)
        with self.assertRaises(ArtifactValidationError):
            validate_ndjson(stream().rstrip())
        with self.assertRaises(ArtifactValidationError):
            validate_ndjson((json.dumps({"schemaVersion": 1, "kind": "manifest", "manifest": MANIFEST}) + "\n").encode())


class CaptureTests(unittest.TestCase):
    def test_parser_resolves_explicit_capture_inputs(self) -> None:
        args = build_parser().parse_args(["capture", "--app", "/tmp/Engine2.app", "--output", "/tmp/run"])
        self.assertEqual(args.command, "capture")
        self.assertEqual(args.seed, 42)

    def test_capture_refuses_existing_output(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaises(CaptureError):
                capture(CaptureRequest(root / "missing", root, "baseline-six-ball", 42, 0, 1))

    def test_capture_records_child_failure(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = self._script(root, "failure", "#!/bin/sh\necho broken >&2\nexit 7\n")
            output = root / "capture"
            with self.assertRaises(CaptureError):
                capture(CaptureRequest(app, output, "baseline-six-ball", 42, 0, 1))
            result = json.loads((output / "capture-result.json").read_text())
            self.assertEqual(result["reason"], "child-process-failure")
            self.assertEqual(result["exit_code"], 7)

    def test_capture_persists_only_a_validated_stream(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            payload = stream().decode().replace("'", "'\\''")
            app = self._script(root, "success", f"#!/bin/sh\nprintf '%s' '{payload}'\n")
            output = root / "capture"
            from diagnostics_lib.logs import LogCapturePolicy
            from diagnostics_lib.traces import TraceCapturePolicy

            result = capture(
                CaptureRequest(
                    app,
                    output,
                    "baseline-six-ball",
                    42,
                    0,
                    1,
                    LogCapturePolicy.SKIP,
                    TraceCapturePolicy.SKIP,
                )
            )
            self.assertEqual(result["status"], "complete")
            self.assertEqual(validate_ndjson((output / "diagnostics.ndjson").read_bytes()).manifest, MANIFEST)

    def _script(self, root: Path, name: str, body: str) -> Path:
        path = root / name
        path.write_text(body)
        path.chmod(path.stat().st_mode | stat.S_IXUSR)
        return path


if __name__ == "__main__":
    unittest.main()
