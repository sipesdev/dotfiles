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
from datetime import datetime, timedelta, timezone

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

    def test_by_model_per_day(self):
        with tempfile.TemporaryDirectory() as td:
            root = pathlib.Path(td)
            proj = root / "projects" / "p"
            proj.mkdir(parents=True)
            now = datetime.now(timezone.utc)
            fmt = "%Y-%m-%dT%H:%M:%S.000Z"
            write_session(proj, "s.jsonl", [
                entry("m1", "claude-opus-4-8", now.strftime(fmt)),                       # today: 36
                entry("m2", "claude-sonnet-4-5", now.strftime(fmt), i=100),              # today: 126
                entry("m3", "claude-opus-4-8", (now - timedelta(days=30)).strftime(fmt)),  # outside the week
            ])
            stats = claude.scan(root)
            self.assertEqual(stats["recentDays"][-1]["byModel"],
                             {"claude-opus-4-8": 36, "claude-sonnet-4-5": 126})
            self.assertEqual(stats["todayTokensByModel"], stats["recentDays"][-1]["byModel"])
            self.assertEqual(stats["recentDays"][0]["byModel"], {})
            # The week carries only this week's opus tokens; all-time modelUsage still counts m3.
            self.assertEqual(sum(d["byModel"].get("claude-opus-4-8", 0) for d in stats["recentDays"]), 36)
            self.assertEqual(stats["modelUsage"]["claude-opus-4-8"]["inputTokens"], 20)


class CodexAggregate(unittest.TestCase):
    def test_by_model_per_day(self):
        today = datetime.now().astimezone().strftime("%Y-%m-%d")
        old = (datetime.now().astimezone() - timedelta(days=30)).strftime("%Y-%m-%d")
        stats = codex.aggregate({"f": {"events": [
            ["m1", "gpt-5", today, 10, 20, 5, 1],
            ["m2", "gpt-5-mini", today, 100, 0, 0, 0],
            ["m3", "gpt-5", old, 1000, 0, 0, 0],
        ]}})
        self.assertEqual(stats["recentDays"][-1]["byModel"], {"gpt-5": 36, "gpt-5-mini": 100})
        self.assertEqual(stats["todayTokensByModel"], stats["recentDays"][-1]["byModel"])
        self.assertEqual(stats["recentDays"][0]["byModel"], {})
        self.assertEqual(stats["modelUsage"]["gpt-5"]["inputTokens"], 1010)


class GeminiScan(unittest.TestCase):
    def test_by_model_per_day(self):
        with tempfile.TemporaryDirectory() as td:
            root = pathlib.Path(td)
            chats = root / "tmp" / "proj" / "chats"
            chats.mkdir(parents=True)
            now = datetime.now(timezone.utc)
            fmt = "%Y-%m-%dT%H:%M:%S.000Z"

            def msg(mid, model, ts, inp):
                return {"id": mid, "type": "gemini", "model": model, "timestamp": ts,
                        "tokens": {"input": inp, "output": 5, "cached": 3, "thoughts": 2,
                                   "tool": 1, "total": inp + 11}}

            write_session(chats, "s.jsonl", [
                msg("g1", "gemini-2.5-pro", now.strftime(fmt), 10),                        # today: 21
                msg("g2", "gemini-2.5-flash", now.strftime(fmt), 100),                     # today: 111
                msg("g3", "gemini-2.5-pro", (now - timedelta(days=30)).strftime(fmt), 1000),  # outside
            ])
            stats = gemini.scan(root)
            self.assertEqual(stats["recentDays"][-1]["byModel"],
                             {"gemini-2.5-pro": 21, "gemini-2.5-flash": 111})
            self.assertEqual(stats["todayTokensByModel"], stats["recentDays"][-1]["byModel"])
            self.assertEqual(stats["recentDays"][0]["byModel"], {})
            self.assertEqual(stats["modelUsage"]["gemini-2.5-pro"]["inputTokens"], 1010)


class ClaudeLimits(unittest.TestCase):
    # The shape the live endpoint returns today: a limits[] array of percent
    # entries (0-100). Probed 2026-09-02; the buckets below are the older shape.
    LIVE = {
        "limits": [
            {"kind": "session", "group": "session", "percent": 21,
             "resets_at": "2026-09-03T02:20:00.000000+00:00",
             "severity": "info", "is_active": True, "scope": None},
            {"kind": "weekly_all", "group": "weekly", "percent": 21,
             "resets_at": "2026-09-08T14:00:00.000000+00:00",
             "severity": "info", "is_active": True, "scope": None},
            {"kind": "weekly_scoped", "group": "weekly", "percent": 32,
             "resets_at": "2026-09-08T14:00:00.000000+00:00",
             "severity": "info", "is_active": True,
             "scope": {"model": {"id": None, "display_name": "Fable"}, "surface": None}},
        ]
    }

    def test_live_percent_entries(self):
        rows = claude.parse_limits(self.LIVE)
        self.assertEqual([r["label"] for r in rows],
                         ["Session (5h)", "Weekly (7-day)", "Weekly (Fable)"])
        self.assertAlmostEqual(rows[0]["percent"], 0.21)
        self.assertAlmostEqual(rows[1]["percent"], 0.21)
        self.assertAlmostEqual(rows[2]["percent"], 0.32)
        self.assertEqual(rows[0]["resetsAt"], "2026-09-03T02:20:00.000000+00:00")
        self.assertEqual(rows[2]["resetsAt"], "2026-09-08T14:00:00.000000+00:00")

    def test_scoped_without_model_name_and_unknown_kind(self):
        rows = claude.parse_limits({"limits": [
            {"kind": "weekly_scoped", "percent": 5, "scope": None},
            {"kind": "monthly_extra", "percent": 10},
            {"kind": "session", "percent": "n/a"},          # not numeric: skipped
        ]})
        self.assertEqual([r["label"] for r in rows], ["Weekly (model)", "Monthly Extra"])

    def test_percent_entries_supersede_buckets(self):
        payload = dict(self.LIVE)
        payload["five_hour"] = {"utilization": 0.9, "resets_at": "2026-09-03T02:20:00Z"}
        self.assertEqual(len(claude.parse_limits(payload)), 3)

    def test_bucket_fallback(self):
        rows = claude.parse_limits({
            "five_hour": {"utilization": 0.4, "resets_at": "2026-09-03T02:20:00Z"},
            "seven_day": {"utilization": 0.6, "resets_at": "2026-09-08T14:00:00Z"},
            "limits": [{"kind": "session"}],               # no usable percent
        })
        self.assertEqual([r["label"] for r in rows], ["Session (5h)", "Weekly (7-day)"])
        self.assertAlmostEqual(rows[0]["percent"], 0.4)
        self.assertAlmostEqual(rows[1]["percent"], 0.6)

    def test_rejects_junk(self):
        self.assertEqual(claude.parse_limits(None), [])
        self.assertEqual(claude.parse_limits({}), [])


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

    def test_epoch_reset_becomes_iso(self):
        # The live Anthropic probe returns resets_at as epoch seconds; codex's
        # app-server is expected to match, and the drawer needs a parseable date.
        e = codex.limit_entry({"usedPercent": 5, "windowDurationMins": 300,
                               "resetsAt": 1757000000})
        self.assertIsInstance(e["resetsAt"], str)
        self.assertEqual(datetime.fromisoformat(e["resetsAt"]),
                         datetime.fromtimestamp(1757000000, tz=timezone.utc))

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
