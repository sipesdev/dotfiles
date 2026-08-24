const test = require("node:test");
const assert = require("node:assert/strict");
const B = require("../../quickshell/.config/quickshell/BtModel.js");

test("named hides empty and MAC-shaped names", () => {
    assert.equal(B.named("Sony WH-1000XM4", "AA:BB:CC:DD:EE:FF"), true);
    assert.equal(B.named("", "x"), false);
    assert.equal(B.named("AA:BB:CC:DD:EE:FF", "AA:BB:CC:DD:EE:FF"), false);
    assert.equal(B.named("AA-BB-CC-DD-EE-FF", "x"), false);
    assert.equal(B.named(null, "x"), false);
});

test("deviceRow snapshots primitives", () => {
    assert.deepEqual(B.deviceRow({ address: "A", name: "n", connected: true, battery: 0.85, batteryAvailable: true }),
        { address: "A", name: "n", icon: "", connected: true, paired: false, bonded: false,
          pairing: false, trusted: false, batteryAvailable: true, battery: 0.85 });
    assert.equal(B.deviceRow(null), null);
});

test("sortDeviceRows: connected, then paired, then name", () => {
    const rows = B.sortDeviceRows([
        { name: "b" }, { name: "Z", paired: true }, { name: "c", connected: true }, { name: "a", bonded: true },
    ]);
    assert.deepEqual(rows.map(r => r.name), ["c", "a", "Z", "b"]);
});

test("deviceSectionTitle", () => {
    const conn = { connected: true }, other = { connected: false };
    assert.equal(B.deviceSectionTitle([conn, conn, other], 0), "CONNECTED");
    assert.equal(B.deviceSectionTitle([conn, conn, other], 1), "");
    assert.equal(B.deviceSectionTitle([conn, conn, other], 2), "DEVICES");
    assert.equal(B.deviceSectionTitle([other], 0), "DEVICES");
    assert.equal(B.deviceSectionTitle([], 0), "");
});

test("deviceStatus", () => {
    assert.equal(B.deviceStatus({ connected: true, batteryAvailable: true, battery: 0.85 }), "85%");
    assert.equal(B.deviceStatus({ connected: true, batteryAvailable: true, battery: 85 }), "85%");
    assert.equal(B.deviceStatus({ connected: true }), "connected");
    assert.equal(B.deviceStatus({ pairing: true }), "pairing...");
    assert.equal(B.deviceStatus({ paired: true }), "paired");
    assert.equal(B.deviceStatus({}), "");
    assert.equal(B.deviceStatus(null), "");
});

test("deviceGlyphKind maps BlueZ icon names", () => {
    assert.equal(B.deviceGlyphKind("audio-headset"), "headset");
    assert.equal(B.deviceGlyphKind("input-mouse"), "mouse");
    assert.equal(B.deviceGlyphKind("phone"), "phone");
    assert.equal(B.deviceGlyphKind(""), "bluetooth");
    assert.equal(B.deviceGlyphKind(undefined), "bluetooth");
});
