// Pure formatting behind PowerPopout. No QML references; tested by tests/quickshell/powermodel.test.js.

function formatDuration(sec) {
    var s = Number(sec);
    if (!isFinite(s) || s <= 0) return "--";
    var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
    if (h <= 0) return m + "m";
    return h + "h " + (m < 10 ? "0" + m : m) + "m";
}
function formatWatts(w) {
    var v = Number(w);
    if (!isFinite(v) || v < 0) return "--";
    return v.toFixed(1) + " W";
}
function formatWh(wh) {
    var v = Number(wh);
    if (!isFinite(v) || v <= 0) return "--";
    return Math.round(v) + " Wh";
}
// S carries the UPowerDeviceState enum values from QML so this file stays Node-loadable.
// Wording matches the previous BatteryPopup (em dash / middle dot are fine; only emojis are banned).
function statusLine(state, pluggedIn, timeToFull, timeToEmpty, S) {
    var e = S || {};
    if (state === e.Charging) {
        var full = formatDuration(timeToFull);
        return full === "--" ? "Charging" : "Charging — " + full + " until full";
    }
    if (state === e.FullyCharged) return "Fully charged";
    if (pluggedIn) return "Plugged in · not charging";
    var left = formatDuration(timeToEmpty);
    return left === "--" ? "—" : left + " remaining";
}

if (typeof module !== "undefined") {
    module.exports = { formatDuration: formatDuration, formatWatts: formatWatts, formatWh: formatWh,
                       statusLine: statusLine };
}
