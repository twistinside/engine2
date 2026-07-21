from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from diagnostics_lib.logs import capture_logs, inspect_log_ndjson


class LogInspectionTests(unittest.TestCase):
    def test_normal_redacted_signpost_and_loss_records_remain_distinct(self) -> None:
        records = [
            {"type": "logEvent", "eventMessage": "normal"},
            {"type": "logEvent", "eventMessage": "value=<private>"},
            {"type": "signpostEvent", "signpostName": "SimulationStep"},
            {"type": "lossEvent", "eventMessage": "messages lost"},
        ]
        data = b"".join((json.dumps(record) + "\n").encode() for record in records)
        inspection = inspect_log_ndjson(data)
        self.assertEqual(inspection.record_count, 4)
        self.assertEqual(inspection.redacted_record_count, 1)
        self.assertEqual(inspection.loss_record_count, 1)

    def test_capture_reports_collect_failure_without_claiming_absence(self) -> None:
        def runner(*_args: object, **_kwargs: object) -> subprocess.CompletedProcess[bytes]:
            return subprocess.CompletedProcess([], 1, b"", b"not permitted")

        with tempfile.TemporaryDirectory() as directory:
            result = capture_logs(Path(directory), 1.0, "session", runner=runner)
        self.assertEqual(result["status"], "unavailable")
        self.assertEqual(result["reason"], "log-collect-failure")


if __name__ == "__main__":
    unittest.main()
