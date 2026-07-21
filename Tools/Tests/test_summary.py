from __future__ import annotations

import unittest

from diagnostics_lib.summary import Measurement, summarize_measurements


class SummaryStatisticsTests(unittest.TestCase):
    def test_exact_nearest_rank_statistics(self) -> None:
        summary = summarize_measurements(
            Measurement(float(value), "nanoseconds") for value in range(1, 101)
        )
        self.assertEqual(summary["count"], 100)
        self.assertEqual(summary["p50"], 50)
        self.assertEqual(summary["p95"], 95)
        self.assertEqual(summary["p99"], 99)
        self.assertEqual(summary["maximum"], 100)

    def test_single_sample_is_every_percentile(self) -> None:
        summary = summarize_measurements([Measurement(7, "nanoseconds")])
        self.assertEqual(summary["p50"], 7)
        self.assertEqual(summary["p95"], 7)
        self.assertEqual(summary["p99"], 7)

    def test_empty_and_incompatible_units_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            summarize_measurements([])
        with self.assertRaises(ValueError):
            summarize_measurements(
                [Measurement(1, "nanoseconds"), Measurement(1, "count")]
            )


if __name__ == "__main__":
    unittest.main()
