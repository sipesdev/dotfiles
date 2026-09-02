"""Unit tests for the agent-usage collectors: pure functions + fixture scans.

Run: python tests/agents/test_collectors.py   (wired into `make test`)
The collectors are extensionless scripts, loaded by path. No network.
"""
import importlib.machinery
import importlib.util
import json
import os
import pathlib
import tempfile
import unittest
from datetime import datetime, timezone

REPO = pathlib.Path(__file__).resolve().parents[2]
BIN = REPO / "localbin" / ".local" / "bin"


def load(name):
    loader = importlib.machinery.SourceFileLoader(name.replace("-", "_"), str(BIN / name))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


claude = load("agent-usage-claude")
codex = load("agent-usage-codex")
gemini = load("agent-usage-gemini")


def write_session(dirpath, name, lines):
    p = dirpath / name
    p.write_text("\n".join(json.dumps(l) if isinstance(l, dict) else l for l in lines) + "\n")
    return p


def entry(mid, model, ts, i=10, o=20, cr=5, cw=1):
    return {"type": "assistant", "timestamp": ts,
            "message": {"id": mid, "model": model, "role": "assistant",
                        "usage": {"input_tokens": i, "output_tokens": o,
                                  "cache_read_input_tokens": cr,
                                  "cache_creation_input_tokens": cw}}}


class PlanLabel(unittest.TestCase):
    def test_max_tier(self):
        self.assertEqual(claude.plan_label("max_20x tier", ""), "Max 20x")

    def test_subscription_fallback(self):
        self.assertEqual(claude.plan_label("", "pro"), "Pro")

    def test_empty(self):
        self.assertEqual(claude.plan_label("", ""), "")


class LocalDay(unittest.TestCase):
    def test_iso_z(self):
        self.assertRegex(claude.local_day("2026-09-01T18:00:00.000Z"), r"^\d{4}-\d{2}-\d{2}$")

    def test_epoch_ms(self):
        self.assertRegex(claude.local_day(1756742400000), r"^\d{4}-\d{2}-\d{2}$")

    def test_garbage(self):
        self.assertIsNone(claude.local_day("not a time"))
        self.assertIsNone(claude.local_day(None))


class UsageTokens(unittest.TestCase):
    def test_snake(self):
        self.assertEqual(claude.usage_tokens({
            "input_tokens": 1, "output_tokens": 2,
            "cache_read_input_tokens": 3, "cache_creation_input_tokens": 4}), (1, 2, 3, 4))

    def test_camel(self):
        self.assertEqual(claude.usage_tokens({
            "inputTokens": 1, "outputTokens": 2,
            "cacheReadInputTokens": 3, "cacheCreationInputTokens": 4}), (1, 2, 3, 4))

    def test_missing(self):
        self.assertEqual(claude.usage_tokens({}), (0, 0, 0, 0))


class Scan(unittest.TestCase):
    def test_dedupes_and_sums(self):
        with tempfile.TemporaryDirectory() as td:
            root = pathlib.Path(td)
            proj = root / "projects" / "p1"
            proj.mkdir(parents=True)
            ts = "2026-09-01T12:00:00.000Z"
            write_session(proj, "s1.jsonl", [
                entry("m1", "claude-opus-4-8", ts),
                entry("m1", "claude-opus-4-8", ts),               # streaming repeat
                {"type": "user", "message": {"role": "user"}},    # not assistant
                "{not json",                                       # malformed
                entry("m2", "claude-sonnet-4-5", ts, i=100),
            ])
            stats = claude.scan(root)
            self.assertEqual(stats["modelUsage"]["claude-opus-4-8"]["inputTokens"], 10)
            self.assertEqual(stats["modelUsage"]["claude-sonnet-4-5"]["inputTokens"], 100)
            self.assertEqual(stats["totalPrompts"], 2)
            self.assertEqual(stats["totalSessions"], 1)
            self.assertEqual(len(stats["recentDays"]), 7)

    def test_today_bucketing(self):
        with tempfile.TemporaryDirectory() as td:
            root = pathlib.Path(td)
            proj = root / "projects" / "p"
            proj.mkdir(parents=True)
            now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")
            write_session(proj, "s.jsonl", [entry("m1", "claude-opus-4-8", now_iso)])
            stats = claude.scan(root)
            self.assertEqual(stats["todayTotalTokens"], 36)     # 10+20+5+1
            self.assertEqual(stats["recentDays"][-1]["messageCount"], 36)
            self.assertEqual(stats["todayPrompts"], 1)
            self.assertEqual(stats["todaySessions"], 1)

    def test_incremental_cache(self):
        with tempfile.TemporaryDirectory() as td:
            root = pathlib.Path(td)
            proj = root / "projects" / "p"
            proj.mkdir(parents=True)
            cache = root / "cache.json"
            f = write_session(proj, "s.jsonl",
                              [entry("m1", "claude-opus-4-8", "2026-09-01T12:00:00.000Z")])
            s1 = claude.scan(root, cache_path=cache)
            self.assertEqual(s1["totalPrompts"], 1)
            saved = json.loads(cache.read_text())
            self.assertIn(str(f), saved["files"])
            # Unchanged file: events must come from the cache. Poison the cached
            # inputTokens to prove the file is not reparsed.
            saved["files"][str(f)]["events"][0][3] = 999
            cache.write_text(json.dumps(saved))
            s2 = claude.scan(root, cache_path=cache)
            self.assertEqual(s2["modelUsage"]["claude-opus-4-8"]["inputTokens"], 999)
            # Touched file: mtime invalidates, the real value returns.
            st = f.stat()
            os.utime(f, (st.st_mtime + 5, st.st_mtime + 5))
            s3 = claude.scan(root, cache_path=cache)
            self.assertEqual(s3["modelUsage"]["claude-opus-4-8"]["inputTokens"], 10)


class CodexLimits(unittest.TestCase):
    def test_weekly_window(self):
        e = codex.limit_entry({"usedPercent": 50, "windowDurationMins": 10080,
                               "resetsAt": "2026-09-03T00:00:00Z"})
        self.assertEqual(e["label"], "Weekly (7-day)")
        self.assertAlmostEqual(e["percent"], 0.5)
        self.assertEqual(e["resetsAt"], "2026-09-03T00:00:00Z")

    def test_session_window(self):
        e = codex.limit_entry({"usedPercent": 12.5, "windowDurationMins": 300, "resetsAt": None})
        self.assertEqual(e["label"], "Session (5h)")
        self.assertAlmostEqual(e["percent"], 0.125)
        self.assertEqual(e["resetsAt"], "")

    def test_rejects_junk(self):
        self.assertIsNone(codex.limit_entry({}))
        self.assertIsNone(codex.limit_entry(None))


class GeminiParse(unittest.TestCase):
    def test_control_and_user_skipped(self):
        self.assertIsNone(gemini.parse_message({"$set": {"model": "x"}}))
        self.assertIsNone(gemini.parse_message({"type": "user", "tokens": {"input": 1}}))
        self.assertIsNone(gemini.parse_message({"type": "gemini"}))   # tokenless

    def test_token_mapping(self):
        ev = gemini.parse_message({
            "id": "x", "type": "gemini", "model": "gemini-2.5-pro",
            "timestamp": "2026-09-01T12:00:00.000Z",
            "tokens": {"input": 10, "output": 5, "cached": 3, "thoughts": 2,
                       "tool": 1, "total": 21}})
        self.assertEqual(ev["inputTokens"], 10)
        self.assertEqual(ev["outputTokens"], 8)        # output + thoughts + tool
        self.assertEqual(ev["cacheReadInputTokens"], 3)
        self.assertEqual(ev["model"], "gemini-2.5-pro")


if __name__ == "__main__":
    unittest.main()
