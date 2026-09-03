// Pure logic behind the agents pill and drawer: usage-record parsing and
// display formatting. No QML types; tested by tests/quickshell/agentmodel.test.js.
// Records are written by agent-usage-update (see the schema in that script).

function parseRecord(text) {
    try {
        var o = JSON.parse(text);
        return (o && typeof o === "object" && !Array.isArray(o)) ? o : null;
    } catch (e) {
        return null;
    }
}

// Records with ready: true, sorted by id, so the drawer's provider order is stable.
function readyProviders(records) {
    var out = [];
    for (var i = 0; i < (records ? records.length : 0); i++) {
        var r = records[i];
        if (r && r.ready === true) out.push(r);
    }
    out.sort(function (a, b) { return (a.id || "") < (b.id || "") ? -1 : 1; });
    return out;
}

// "claude-opus-4-8" -> "Opus 4.8"; "claude-sonnet-4-5-20250929" -> "Sonnet 4.5".
// Strip the vendor prefix and a trailing date stamp, rejoin numeric runs with
// dots, then title-case (GPT stays upper).
function friendlyModelName(id) {
    if (!id) return "Unknown";
    var s = String(id).replace(/^claude-/, "").replace(/-\d{8}$/, "");
    var parts = s.split("-"), words = [], nums = [];
    for (var i = 0; i < parts.length; i++) {
        if (/^\d+$/.test(parts[i])) nums.push(parts[i]);
        else {
            if (nums.length) { words.push(nums.join(".")); nums = []; }
            words.push(parts[i]);
        }
    }
    if (nums.length) words.push(nums.join("."));
    for (var j = 0; j < words.length; j++) {
        var w = words[j];
        if (/^gpt/i.test(w)) w = w.toUpperCase();
        else if (/^[a-z]/.test(w)) w = w.charAt(0).toUpperCase() + w.slice(1);
        words[j] = w;
    }
    return words.join(" ");
}

function trim1(v) { return v.toFixed(1).replace(/\.0$/, ""); }

function formatTokenCount(n) {
    n = Number(n) || 0;
    if (n >= 1e9) return trim1(n / 1e9) + "B";
    if (n >= 1e6) return trim1(n / 1e6) + "M";
    if (n >= 1e3) return trim1(n / 1e3) + "K";
    return String(Math.round(n));
}

// Meter rows from record.limits; hot at >= 90% (drives the accent).
function limitRows(record) {
    var out = [], ls = (record && record.limits) || [];
    for (var i = 0; i < ls.length; i++) {
        var l = ls[i];
        if (!l || typeof l.percent !== "number" || l.percent < 0) continue;
        var p = Math.min(1, l.percent);
        out.push({
            label: l.title || l.label || "Limit",
            percent: p,
            percentText: Math.round(p * 100) + "%",
            resetsAt: l.resetsAt || "",
            hot: p >= 0.9
        });
    }
    return out;
}

function formatDuration(ms) {
    var m = Math.floor(ms / 60000);
    var d = Math.floor(m / 1440), h = Math.floor((m % 1440) / 60), mm = m % 60;
    if (d > 0) return d + "d " + h + "h";
    if (h > 0) return h + "h " + mm + "m";
    return Math.max(1, mm) + "m";
}

function resetText(resetsAt, nowMs) {
    if (!resetsAt) return "";
    var t = Date.parse(resetsAt);
    if (isNaN(t)) return "";
    if (t - nowMs <= 0) return "Resets soon";
    return "Resets in " + formatDuration(t - nowMs);
}

// Exactly 7 rows ending today, scaled to the week's peak. recentDays'
// messageCount IS a token total (legacy key name, kept for schema parity).
// todayStr ("YYYY-MM-DD") anchors the window; "" means the current date.
function weekRows(record, todayStr) {
    var byDate = {}, rd = (record && record.recentDays) || [];
    for (var i = 0; i < rd.length; i++)
        if (rd[i] && rd[i].date) byDate[rd[i].date] = Number(rd[i].messageCount) || 0;
    var names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    var base = todayStr ? new Date(todayStr + "T12:00:00") : new Date();
    var out = [], peak = 1;
    for (var back = 6; back >= 0; back--) {
        var day = new Date(base.getTime() - back * 86400000);
        var key = day.getFullYear() + "-" + pad2(day.getMonth() + 1) + "-" + pad2(day.getDate());
        var tokens = byDate[key] || 0;
        if (tokens > peak) peak = tokens;
        out.push({ date: key, label: back === 0 ? "Today" : names[day.getDay()],
                   tokens: tokens, isToday: back === 0 });
    }
    for (var j = 0; j < out.length; j++) out[j].ratio = out[j].tokens / peak;
    return out;
}

function pad2(n) { return (n < 10 ? "0" : "") + n; }

// Top 4 models by total tokens, bar ratios scaled to the heaviest.
function modelRows(record) {
    var mu = (record && record.modelUsage) || {}, rows = [];
    for (var k in mu) {
        var u = mu[k] || {};
        var total = (Number(u.inputTokens) || 0) + (Number(u.outputTokens) || 0)
                  + (Number(u.cacheReadInputTokens) || 0) + (Number(u.cacheCreationInputTokens) || 0);
        if (total > 0) rows.push({ name: friendlyModelName(k), total: total });
    }
    rows.sort(function (a, b) { return b.total - a.total; });
    rows = rows.slice(0, 4);
    var peak = rows.length ? rows[0].total : 1;
    for (var i = 0; i < rows.length; i++) rows[i].ratio = rows[i].total / peak;
    return rows;
}

function heroStatus(record) {
    if (!record) return "";
    if (record.usageStatusText) return record.usageStatusText;
    if (record.tierLabel) return record.tierLabel;
    return "Subscription";
}

// Detail beside the TOKENS header; today's token total already has its own row.
function promptsToday(record) {
    var p = (record && Number(record.todayPrompts)) || 0;
    return p > 0 ? p + " prompts today" : "";
}

// Auth help surfaces only when something is actually wrong.
function statusLine(record) {
    if (!record) return "";
    if (record.authHelpText && (record.usageStatusText || record.retryAdvised))
        return record.authHelpText;
    return "";
}

// Any ready record with a limit at >= 90%: the pill glyph goes accent.
function anyLimitHot(records) {
    for (var i = 0; i < (records ? records.length : 0); i++) {
        var rows = limitRows(records[i]);
        for (var j = 0; j < rows.length; j++) if (rows[j].hot) return true;
    }
    return false;
}

if (typeof module !== "undefined") {
    module.exports = {
        parseRecord: parseRecord, readyProviders: readyProviders,
        friendlyModelName: friendlyModelName, formatTokenCount: formatTokenCount,
        limitRows: limitRows, formatDuration: formatDuration, resetText: resetText,
        weekRows: weekRows, modelRows: modelRows, heroStatus: heroStatus,
        promptsToday: promptsToday, statusLine: statusLine, anyLimitHot: anyLimitHot
    };
}
