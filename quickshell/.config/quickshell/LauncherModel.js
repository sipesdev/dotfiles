// Pure helpers for the app launcher: desktop-entry search and the calculator row. The search half is
// ported from basecamp/omarchy's shell/services/AppSearch.js (MIT), keeping its helper split and its
// score tiers so results rank the same way. `entry` is duck-typed { id, name, genericName, comment,
// keywords, noDisplay }: a DesktopEntry in QML, a plain object in tests. No QML references; tested by
// tests/quickshell/launchermodel.test.js.

function entryName(entry) {
    return String((entry && entry.name) || (entry && entry.id) || "");
}

function keywordText(entry) {
    try {
        // a QML list property is not always a real Array, so duck-type on join
        if (entry && entry.keywords && typeof entry.keywords.join === "function") return entry.keywords.join(" ");
    } catch (e) {
    }
    return "";
}

function entrySearchText(entry) {
    if (!entry) return "";
    return [entry.name, entry.genericName, entry.comment, keywordText(entry), entry.id].join(" ").toLowerCase();
}

function wordText(value) {
    return String(value || "")
        .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
        .replace(/[._:/\\-]+/g, " ")
        .toLowerCase();
}

function words(value) {
    var values = wordText(value).split(/[^a-z0-9]+/);
    var result = [];
    for (var i = 0; i < values.length; i++) {
        if (values[i]) result.push(values[i]);
    }
    return result;
}

function entryAcronym(entry) {
    var values = words([entry && entry.name, entry && entry.genericName, keywordText(entry), entry && entry.id].join(" "));
    var result = "";
    for (var i = 0; i < values.length; i++) result += values[i].charAt(0);
    return result;
}

function termMatches(entry, term) {
    if (!term) return true;
    var name = entryName(entry).toLowerCase();
    var id = String((entry && entry.id) || "").toLowerCase();
    if (name.indexOf(term) >= 0) return true;
    if (id.indexOf(term) >= 0) return true;
    if (entrySearchText(entry).indexOf(term) >= 0) return true;
    // long terms skip the acronym: "firefox" matching an acronym of "f..." would be noise
    return term.length <= 5 && entryAcronym(entry).indexOf(term) >= 0;
}

function allTermsMatch(entry, query) {
    var terms = String(query || "").toLowerCase().trim().split(/\s+/);
    for (var i = 0; i < terms.length; i++) {
        if (terms[i] && !termMatches(entry, terms[i])) return false;
    }
    return true;
}

// -1 = no match; higher is better. The tier bases keep every name hit above every id hit of the
// same kind, and the length/offset penalties order hits within a tier.
function fuzzyScore(entry, query) {
    var q = String(query || "").trim().toLowerCase();
    if (!q) return 0;
    if (!allTermsMatch(entry, q)) return -1;

    var name = entryName(entry).toLowerCase();
    var id = String((entry && entry.id) || "").toLowerCase();
    var directName = name.indexOf(q);
    var directId = id.indexOf(q);
    if (directName === 0) return 10000 - name.length;
    if (directId === 0) return 9500 - id.length;
    if (directName > 0) return 8000 - directName * 10 - name.length;
    if (directId > 0) return 7600 - directId * 10 - id.length;

    var hayIndex = entrySearchText(entry).indexOf(q);
    if (hayIndex >= 0) return 6000 - hayIndex;

    var acronym = entryAcronym(entry);
    var acronymIndex = acronym.indexOf(q);
    if (acronymIndex === 0) return 5000 - acronym.length;
    if (acronymIndex > 0) return 4600 - acronymIndex * 10 - acronym.length;

    return 4000 - name.length;
}

// Matching entries, best first. A leading "=" is the calculator's, so it lists no apps.
function sortedApps(entries, query) {
    var q = String(query || "").trim();
    if (q.charAt(0) === "=") return [];
    var rows = [];
    var input = entries || [];
    for (var i = 0; i < input.length; i++) {
        var entry = input[i];
        if (!entry || entry.noDisplay) continue;
        var name = entryName(entry);
        if (!name) continue;
        var score = fuzzyScore(entry, q);
        if (score < 0) continue;
        rows.push({ entry: entry, score: score, key: name.toLowerCase() });
    }
    rows.sort(function (a, b) {
        if (q && a.score !== b.score) return b.score - a.score;
        if (a.key < b.key) return -1;
        if (a.key > b.key) return 1;
        return 0;
    });
    var result = [];
    for (var n = 0; n < rows.length; n++) result.push(rows[n].entry);
    return result;
}

// The expression to hand qalc, or "" for no calc row. A bare query only counts when it looks like
// math (a digit plus an operator or " to "), so "steam 2" or a year does not spawn qalc; a leading
// "=" forces it for anything else.
function calcExpression(query) {
    var q = String(query || "").trim();
    if (q.charAt(0) === "=") return q.slice(1).trim();
    if (q.length < 3 || !/\d/.test(q)) return "";
    return /[-+*\/^%()!]/.test(q) || /\sto\s/i.test(q) ? q : "";
}

function normalizeMath(text) {
    return String(text).replace(/\s+/g, "").replace(/−/g, "-").replace(/×/g, "*").replace(/÷/g, "/");
}

// qalc prints the input back when it cannot evaluate it, so an output equal to the expression is
// "no answer" and the row stays hidden. Otherwise the answer is the last non-empty line.
function calcResult(expression, output) {
    var lines = String(output || "").split("\n");
    var last = "";
    for (var i = lines.length - 1; i >= 0; i--) {
        var line = lines[i].trim();
        if (line) { last = line; break; }
    }
    if (!last) return "";
    return normalizeMath(last) === normalizeMath(expression) ? "" : last;
}

if (typeof module !== "undefined") {
    module.exports = {
        entryName: entryName,
        entrySearchText: entrySearchText,
        entryAcronym: entryAcronym,
        fuzzyScore: fuzzyScore,
        sortedApps: sortedApps,
        calcExpression: calcExpression,
        calcResult: calcResult
    };
}
