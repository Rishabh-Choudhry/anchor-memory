import os
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
import memory_lint as ml  # noqa: E402
import unittest


class TestParseMetaBlocks(unittest.TestCase):
    def test_parses_single_block_with_id_and_status(self):
        text = """## Some heading
<!-- @meta
id: my-entry
status: active
-->
Prose here.
"""
        entries = ml.parse_meta_blocks(text)
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0].id, "my-entry")
        self.assertEqual(entries[0].status, "active")
        self.assertEqual(entries[0].anchors, [])

    def test_entry_without_meta_block_is_ignored(self):
        text = "## Heading\nJust prose, no meta.\n"
        self.assertEqual(ml.parse_meta_blocks(text), [])

    def test_status_defaults_to_active_when_omitted(self):
        text = "<!-- @meta\nid: x\n-->\n"
        entries = ml.parse_meta_blocks(text)
        self.assertEqual(entries[0].status, "active")


import os
import tempfile


class TestFileAnchors(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def _write(self, name, content):
        p = os.path.join(self.tmp, name)
        with open(p, "w") as f:
            f.write(content)
        return p

    def test_file_grep_present_matches(self):
        self._write("c.swift", "let setMergeWindowSec: TimeInterval = 20.0\n")
        a = {"kind": "file_grep", "file": "c.swift",
             "pattern": "setMergeWindowSec: TimeInterval = 20.0", "expect": "present"}
        r = ml.evaluate_anchor(a, root=self.tmp)
        self.assertEqual(r.status, "MATCH")

    def test_file_grep_present_but_missing_is_drift(self):
        self._write("c.swift", "let setMergeWindowSec: TimeInterval = 30.0\n")
        a = {"kind": "file_grep", "file": "c.swift",
             "pattern": "setMergeWindowSec: TimeInterval = 20.0", "expect": "present"}
        r = ml.evaluate_anchor(a, root=self.tmp)
        self.assertEqual(r.status, "DRIFT")

    def test_file_grep_missing_file_is_broken(self):
        a = {"kind": "file_grep", "file": "nope.swift", "pattern": "x", "expect": "present"}
        r = ml.evaluate_anchor(a, root=self.tmp)
        self.assertEqual(r.status, "BROKEN")

    def test_scope_after_disambiguates(self):
        self._write("p.txt", "config A\nCURRENT_PROJECT_VERSION = 1\n"
                             "name = GymVision\nCURRENT_PROJECT_VERSION = 12\n")
        a = {"kind": "file_grep", "file": "p.txt",
             "pattern": "CURRENT_PROJECT_VERSION = 12",
             "scope_after": "name = GymVision", "expect": "present"}
        self.assertEqual(ml.evaluate_anchor(a, root=self.tmp).status, "MATCH")

    def test_file_exists_present(self):
        self._write("here.txt", "x")
        a = {"kind": "file_exists", "file": "here.txt", "expect": "present"}
        self.assertEqual(ml.evaluate_anchor(a, root=self.tmp).status, "MATCH")

    def test_file_exists_absent_expected_absent(self):
        a = {"kind": "file_exists", "file": "gone.txt", "expect": "absent"}
        self.assertEqual(ml.evaluate_anchor(a, root=self.tmp).status, "MATCH")


import json


class TestJsonAndGoldenAnchors(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def _write(self, name, content):
        p = os.path.join(self.tmp, name)
        with open(p, "w") as f:
            f.write(content)
        return p

    def test_json_field_ge_passes(self):
        self._write("m.json", json.dumps({"cv_within_1": 0.9356}))
        a = {"kind": "json_field", "file": "m.json", "field": "cv_within_1", "expect": ">= 0.93"}
        self.assertEqual(ml.evaluate_anchor(a, root=self.tmp).status, "MATCH")

    def test_json_field_ge_drifts_when_below(self):
        self._write("m.json", json.dumps({"cv_within_1": 0.80}))
        a = {"kind": "json_field", "file": "m.json", "field": "cv_within_1", "expect": ">= 0.93"}
        self.assertEqual(ml.evaluate_anchor(a, root=self.tmp).status, "DRIFT")

    def test_json_field_eq_string(self):
        self._write("m.json", json.dumps({"feature_mode": "hip_bones_motion"}))
        a = {"kind": "json_field", "file": "m.json", "field": "feature_mode",
             "expect": "== hip_bones_motion"}
        self.assertEqual(ml.evaluate_anchor(a, root=self.tmp).status, "MATCH")

    def test_json_field_missing_key_is_broken(self):
        self._write("m.json", json.dumps({"other": 1}))
        a = {"kind": "json_field", "file": "m.json", "field": "nope", "expect": "== 1"}
        self.assertEqual(ml.evaluate_anchor(a, root=self.tmp).status, "BROKEN")

    def test_golden_metric_count_true_matches(self):
        self._write("g.csv", "id,v2_pass\na,True\nb,False\nc,True\n")
        a = {"kind": "golden_metric", "file": "g.csv", "column": "v2_pass",
             "match_value": "True", "expect": "count == 2"}
        self.assertEqual(ml.evaluate_anchor(a, root=self.tmp).status, "MATCH")

    def test_golden_metric_count_drifts(self):
        self._write("g.csv", "id,v2_pass\na,True\nb,True\nc,True\n")
        a = {"kind": "golden_metric", "file": "g.csv", "column": "v2_pass",
             "match_value": "True", "expect": "count == 2"}
        self.assertEqual(ml.evaluate_anchor(a, root=self.tmp).status, "DRIFT")


class TestLintReport(unittest.TestCase):
    def test_superseded_entry_anchors_are_skipped(self):
        text = """<!-- @meta
id: old
status: superseded
-->
<!-- @meta
id: new
status: active
supersedes: old
-->
"""
        report = ml.lint_text(text, root=".")
        # superseded 'old' produces no anchor results, no dangling (its replacement 'new' exists)
        self.assertFalse(any(r.kind == "DANGLING" for r in report))

    def test_supersedes_unknown_id_is_dangling(self):
        text = """<!-- @meta
id: new
status: active
supersedes: ghost
-->
"""
        report = ml.lint_text(text, root=".")
        self.assertTrue(any(r.kind == "DANGLING" for r in report))

    def test_duplicate_id_is_reported(self):
        text = "<!-- @meta\nid: dup\n-->\n<!-- @meta\nid: dup\n-->\n"
        report = ml.lint_text(text, root=".")
        self.assertTrue(any(r.kind == "DUPLICATE" for r in report))


import io
import contextlib


class TestCli(unittest.TestCase):
    def test_quiet_silent_when_clean(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = ml.main(["--quiet", "--files", "/dev/null"])
        self.assertEqual(out.getvalue(), "")
        self.assertEqual(code, 0)

    def test_json_mode_emits_list(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            ml.main(["--json", "--files", "/dev/null"])
        self.assertEqual(json.loads(out.getvalue()), [])

    def test_check_flag_is_accepted(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = ml.main(["--check", "--files", "/dev/null"])
        self.assertEqual(code, 0)
        self.assertIn("all anchors MATCH", out.getvalue())


class ConfigResolutionTest(unittest.TestCase):
    def test_reads_ledger_files_from_config(self):
        with tempfile.TemporaryDirectory() as root:
            with open(os.path.join(root, "anchor.config.json"), "w") as f:
                json.dump({"memory": {"dir": "mem",
                                      "ledger_files": ["mem/facts.md"]}}, f)
            self.assertEqual(ml._files_from_config(root), ["mem/facts.md"])

    def test_missing_config_returns_none(self):
        with tempfile.TemporaryDirectory() as root:
            self.assertIsNone(ml._files_from_config(root))


if __name__ == "__main__":
    unittest.main()
