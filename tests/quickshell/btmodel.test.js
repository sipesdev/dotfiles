const test = require("node:test");
const assert = require("node:assert/strict");
const B = require("../../quickshell/.config/quickshell/BtModel.js");

test("deviceLabel prefers the alias and trims", () => {
    assert.equal(B.deviceLabel({ deviceName: " Sony WH-1000XM4 ", name: "WH-1000XM4" }), "Sony WH-1000XM4");
    assert.equal(B.deviceLabel({ name: "Mouse" }), "Mouse");
    assert.equal(B.deviceLabel(null), "");
});

test("hasHumanName rejects empty, UUID-like and address-like labels", () => {
    assert.equal(B.hasHumanName({ name: "Speaker" }), true);
    assert.equal(B.hasHumanName({ name: "" }), false);
    assert.equal(B.hasHumanName({ name: "AA:BB:CC:DD:EE:FF" }), false);
    assert.equal(B.hasHumanName({ name: "aa-bb-cc-dd-ee-ff" }), false);
    assert.equal(B.hasHumanName({ name: "0000110b-0000-1000-8000-00805f9b34fb" }), false);
    assert.equal(B.hasHumanName({ name: "0x1234" }), false);
    assert.equal(B.hasHumanName({ name: "deadbeefdeadbeefdeadbeefdeadbeef" }), false);
});

test("toArray copies arrays and array-likes", () => {
    assert.deepEqual(B.toArray([1, 2]), [1, 2]);
    assert.deepEqual(B.toArray({ length: 2, 0: "a", 1: "b" }), ["a", "b"]);
    assert.deepEqual(B.toArray(null), []);
});

test("deviceLists groups connected / known / discovered, alphabetical, no duplicates", () => {
    const lists = B.deviceLists([
        { name: "Speaker", paired: true }, { name: "Mouse", trusted: true },
        { name: "Buds", connected: true, paired: true }, { name: "Beacon" },
        { name: "AA:BB:CC:DD:EE:FF" }, null,
    ]);
    assert.deepEqual(lists.connected.map(B.deviceLabel), ["Buds"]);
    assert.deepEqual(lists.known.map(B.deviceLabel), ["Mouse", "Speaker"]);
    assert.deepEqual(lists.discovered.map(B.deviceLabel), ["Beacon"]);
});

test("deviceRow projects primitives only", () => {
    assert.deepEqual(B.deviceRow({ address: "A", name: "n", connected: true, battery: 0.85, batteryAvailable: true, state: 1 }, "connected"),
        { address: "A", label: "n", section: "connected", connected: true, state: 1, batteryAvailable: true, battery: 0.85, pairing: false });
    assert.equal(B.deviceRow({ address: "B" }, "known").label, "Device");
    assert.equal(B.deviceRow(null, "known"), null);
});

test("scrollSectionTitle opens PAIRED and AVAILABLE once each", () => {
    const rows = [{ section: "known" }, { section: "known" }, { section: "discovered" }, { section: "discovered" }];
    assert.deepEqual([0, 1, 2, 3].map(i => B.scrollSectionTitle(rows, i)), ["PAIRED", "", "AVAILABLE", ""]);
    assert.equal(B.scrollSectionTitle([{ section: "discovered" }], 0), "AVAILABLE");
    assert.equal(B.scrollSectionTitle(rows, 9), "");
});

test("statusText precedence", () => {
    const S = { Disconnecting: 2, Connecting: 3 };
    assert.equal(B.statusText({ connected: true, section: "connected" }, "forgetting", S), "Forgetting…");
    assert.equal(B.statusText({ connected: true, section: "connected" }, "disconnecting", S), "Disconnecting…");
    assert.equal(B.statusText({ connected: true, section: "connected", state: 2 }, "", S), "Disconnecting…");
    assert.equal(B.statusText({ connected: true, section: "connected", batteryAvailable: true, battery: 0.87 }, "", S), "87%");
    assert.equal(B.statusText({ connected: true, section: "connected", batteryAvailable: true, battery: 87 }, "", S), "87%");
    assert.equal(B.statusText({ connected: true, section: "connected" }, "", S), "");
    assert.equal(B.statusText({ connected: true, section: "known" }, "", S), "Connected");
    assert.equal(B.statusText({ connected: false, section: "known" }, "connecting", S), "Connecting…");
    assert.equal(B.statusText({ connected: false, section: "discovered" }, "pairing", S), "Connecting…");
    assert.equal(B.statusText({ connected: false, section: "known", state: 3 }, "", S), "Connecting…");
    assert.equal(B.statusText({ connected: false, section: "discovered", pairing: true }, "", S), "Connecting…");
    assert.equal(B.statusText({ connected: false, section: "known" }, "", S), "");
    assert.equal(B.statusText(null, "", S), "");
});

test("statusStrong", () => {
    const S = { Disconnecting: 2, Connecting: 3 };
    assert.equal(B.statusStrong({ connected: true }, "", S), true);
    assert.equal(B.statusStrong({ connected: false }, "connecting", S), true);
    assert.equal(B.statusStrong({ connected: false, state: 3 }, "", S), true);
    assert.equal(B.statusStrong({ connected: false }, "", S), false);
});

test("pending action map is immutable", () => {
    const a = B.withPendingAction({}, "A", "connecting");
    assert.deepEqual(a, { A: "connecting" });
    const b = B.withPendingAction(a, "B", "forgetting");
    assert.deepEqual(a, { A: "connecting" });
    assert.deepEqual(b, { A: "connecting", B: "forgetting" });
    assert.deepEqual(B.withPendingAction(b, "A", ""), { B: "forgetting" });
    assert.equal(B.pendingAction(b, "A"), "connecting");
    assert.equal(B.pendingAction(b, "Z"), "");
    assert.deepEqual(B.withPendingAction(b, "", "x"), b);
});

test("bluetoothSinkMatchesDevice by address then label; rejects non-sinks", () => {
    const dev = { address: "2C:BE:EB:12:34:56", label: "Buds" };
    assert.equal(B.bluetoothSinkMatchesDevice({ isSink: true, isStream: false, name: "bluez_output.2C_BE_EB_12_34_56.1" }, dev), true);
    assert.equal(B.bluetoothSinkMatchesDevice({ isSink: true, isStream: false, name: "alsa_output.x", description: "Buds" }, dev), true);
    assert.equal(B.bluetoothSinkMatchesDevice({ isSink: true, isStream: false, name: "alsa_output.x", description: "Speakers" }, dev), false);
    assert.equal(B.bluetoothSinkMatchesDevice({ isSink: false, name: "bluez_input.2C_BE_EB_12_34_56" }, dev), false);
    assert.equal(B.bluetoothSinkMatchesDevice({ isSink: true, isStream: true, name: "bluez_output.2C_BE_EB_12_34_56.1" }, dev), false);
});
