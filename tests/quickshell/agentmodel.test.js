const test = require("node:test");
const assert = require("node:assert/strict");
const M = require("../../quickshell/.config/quickshell/AgentModel.js");

test("parseRecord accepts objects, rejects garbage", () => {
    assert.deepEqual(M.parseRecord('{"id":"claude"}'), { id: "claude" });
    assert.equal(M.parseRecord("not json"), null);
    assert.equal(M.parseRecord("[1,2]"), null);
    assert.equal(M.parseRecord(""), null);
});

test("readyProviders filters not-ready and nulls, sorts by id", () => {
    const rows = M.readyProviders([
        { id: "codex", ready: true },
        null,
        { id: "gemini", ready: false },
        { id: "claude", ready: true },
    ]);
    assert.deepEqual(rows.map((r) => r.id), ["claude", "codex"]);
    assert.deepEqual(M.readyProviders(null), []);
});

test("friendlyModelName strips vendor prefix and date, dots numeric runs", () => {
    assert.equal(M.friendlyModelName("claude-opus-4-8"), "Opus 4.8");
    assert.equal(M.friendlyModelName("claude-sonnet-4-5-20250929"), "Sonnet 4.5");
    assert.equal(M.friendlyModelName("gpt-5.6-sol"), "GPT 5.6 Sol");
    assert.equal(M.friendlyModelName(""), "Unknown");
});

test("formatTokenCount", () => {
    assert.equal(M.formatTokenCount(0), "0");
    assert.equal(M.formatTokenCount(999), "999");
    assert.equal(M.formatTokenCount(1200), "1.2K");
    assert.equal(M.formatTokenCount(2000), "2K");
    assert.equal(M.formatTokenCount(3400000), "3.4M");
    assert.equal(M.formatTokenCount(1100000000), "1.1B");
});

test("limitRows clamps, prefers title, skips negatives, flags hot", () => {
    const rows = M.limitRows({ limits: [
        { label: "weekly", title: "Weekly (7-day)", percent: 0.37, resetsAt: "2026-09-05T00:00:00Z" },
        { label: "session", percent: 1.4 },
        { label: "bad", percent: -1 },
        { label: "hot", percent: 0.9 },
    ] });
    assert.equal(rows.length, 3);
    assert.equal(rows[0].label, "Weekly (7-day)");
    assert.equal(rows[0].percentText, "37%");
    assert.equal(rows[0].hot, false);
    assert.equal(rows[1].percent, 1);
    assert.equal(rows[1].hot, true);
    assert.equal(rows[2].hot, true);
    assert.deepEqual(M.limitRows({}), []);
    assert.deepEqual(M.limitRows(null), []);
});

test("resetText future, past, blank, garbage", () => {
    const now = Date.parse("2026-09-02T12:00:00Z");
    assert.equal(M.resetText("2026-09-02T14:14:00Z", now), "Resets in 2h 14m");
    assert.equal(M.resetText("2026-09-04T13:00:00Z", now), "Resets in 2d 1h");
    assert.equal(M.resetText("2026-09-02T12:05:00Z", now), "Resets in 5m");
    assert.equal(M.resetText("2026-09-02T11:00:00Z", now), "Resets soon");
    assert.equal(M.resetText("", now), "");
    assert.equal(M.resetText("garbage", now), "");
});

test("weekRows pads to 7, scales to peak, marks today", () => {
    const rows = M.weekRows({ recentDays: [
        { date: "2026-09-01", messageCount: 500 },
        { date: "2026-09-02", messageCount: 1000 },
    ] }, "2026-09-02");
    assert.equal(rows.length, 7);
    assert.equal(rows[6].label, "Today");
    assert.equal(rows[6].isToday, true);
    assert.equal(rows[6].ratio, 1);
    assert.equal(rows[5].ratio, 0.5);
    assert.equal(rows[0].tokens, 0);
    assert.equal(rows[0].isToday, false);
});

test("modelRows sums the same 7 days weekRows shows, keeps top 4, drops zero rows", () => {
    const rows = M.modelRows({ recentDays: [
        { date: "2026-08-26", messageCount: 900, byModel: { c: 900 } },          // 7 days back: outside
        { date: "2026-08-27", messageCount: 100, byModel: { a: 100 } },          // 6 days back: first row
        { date: "2026-09-01", messageCount: 265, byModel: { a: 100, b: 50, c: 100, d: 10, e: 5 } },
        { date: "2026-09-02", messageCount: 150, byModel: { c: 150, zero: 0 } },
    ] }, "2026-09-02");
    assert.deepEqual(rows.map((r) => [r.name, r.total]), [["C", 250], ["A", 200], ["B", 50], ["D", 10]]);
    assert.equal(rows[0].ratio, 1);
    assert.equal(rows[1].ratio, 0.8);
    // All-time modelUsage is no longer read; a record without byModel (pre-upgrade) yields no rows.
    assert.deepEqual(M.modelRows({ modelUsage: { a: { inputTokens: 5 } } }, "2026-09-02"), []);
    assert.deepEqual(M.modelRows({ recentDays: [{ date: "2026-09-02", messageCount: 5 }] }, "2026-09-02"), []);
    assert.deepEqual(M.modelRows({}, "2026-09-02"), []);
    assert.deepEqual(M.modelRows(null, ""), []);
});

test("anyLimitHot at the 0.9 boundary", () => {
    assert.equal(M.anyLimitHot([{ ready: true, limits: [{ label: "x", percent: 0.9 }] }]), true);
    assert.equal(M.anyLimitHot([{ ready: true, limits: [{ label: "x", percent: 0.89 }] }]), false);
    assert.equal(M.anyLimitHot([]), false);
    assert.equal(M.anyLimitHot(null), false);
});

test("heroStatus and statusLine precedence", () => {
    assert.equal(M.heroStatus({ usageStatusText: "Sign-in expired", tierLabel: "Max 20x" }), "Sign-in expired");
    assert.equal(M.heroStatus({ tierLabel: "Max 20x" }), "Max 20x");
    assert.equal(M.heroStatus({}), "Subscription");
    assert.equal(M.statusLine({ authHelpText: "Run /login", usageStatusText: "Sign-in expired" }), "Run /login");
    assert.equal(M.statusLine({ authHelpText: "help" }), "");
    assert.equal(M.statusLine({ authHelpText: "help", retryAdvised: true }), "help");
});

test("promptsToday is blank without prompts", () => {
    assert.equal(M.promptsToday({ todayPrompts: 1272 }), "1272 prompts today");
    assert.equal(M.promptsToday({ todayPrompts: 0 }), "");
    assert.equal(M.promptsToday({}), "");
    assert.equal(M.promptsToday(null), "");
});
