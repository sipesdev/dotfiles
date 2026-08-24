const test = require("node:test");
const assert = require("node:assert/strict");
const P = require("../../quickshell/.config/quickshell/PowerModel.js");

test("formatDuration", () => {
    assert.equal(P.formatDuration(0), "--");
    assert.equal(P.formatDuration(-3), "--");
    assert.equal(P.formatDuration(45 * 60), "45m");
    assert.equal(P.formatDuration(3900), "1h 05m");
    assert.equal(P.formatDuration(7200), "2h 00m");
});

test("formatWatts / formatWh", () => {
    assert.equal(P.formatWatts(12.34), "12.3 W");
    assert.equal(P.formatWatts(0), "0.0 W");
    assert.equal(P.formatWatts(-1), "--");
    assert.equal(P.formatWatts(NaN), "--");
    assert.equal(P.formatWh(84.6), "85 Wh");
    assert.equal(P.formatWh(0), "--");
});

test("statusLine", () => {
    const S = { Charging: 1, Discharging: 2, FullyCharged: 4, PendingCharge: 5 };
    assert.equal(P.statusLine(1, true, 3900, 0, S), "Charging — 1h 05m until full");
    assert.equal(P.statusLine(1, true, 0, 0, S), "Charging");
    assert.equal(P.statusLine(4, true, 0, 0, S), "Fully charged");
    assert.equal(P.statusLine(5, true, 0, 0, S), "Plugged in · not charging");
    assert.equal(P.statusLine(2, false, 0, 7800, S), "2h 10m remaining");
    assert.equal(P.statusLine(2, false, 0, 0, S), "—");
});
