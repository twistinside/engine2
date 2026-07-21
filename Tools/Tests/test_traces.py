from __future__ import annotations

import unittest

from diagnostics_lib.traces import inspect_toc


class TraceSchemaTests(unittest.TestCase):
    def test_toc_selects_stable_schema_identities(self) -> None:
        toc = b"""<?xml version="1.0"?>
        <trace-toc><run><data>
          <table schema="time-profile" />
          <table schema="OSSignpostIntervals" />
          <table schema="os-signpost" />
        </data></run></trace-toc>
        """
        self.assertEqual(
            inspect_toc(toc),
            {"time-profile", "OSSignpostIntervals", "os-signpost"},
        )

    def test_unknown_toc_remains_visible_to_caller(self) -> None:
        toc = b'<trace-toc><run><data><table schema="future-signposts" /></data></run></trace-toc>'
        self.assertEqual(inspect_toc(toc), {"future-signposts"})


if __name__ == "__main__":
    unittest.main()
