const test = require("node:test");
const assert = require("node:assert/strict");
const M = require("../../quickshell/.config/quickshell/NetModel.js");

test("parseKeyValue splits tab lines, trims, skips junk", () => {
    assert.deepEqual(M.parseKeyValue("iface\teth0\nip\t192.168.4.105 \nnotab\n\nrx_bytes\t42\n"),
        { iface: "eth0", ip: "192.168.4.105", rx_bytes: "42" });
    assert.deepEqual(M.parseKeyValue(""), {});
    assert.deepEqual(M.parseKeyValue(null), {});
});

test("throughputState seeds on first sample and on iface change", () => {
    const s1 = M.throughputState({}, { iface: "eth0", rx_bytes: "1000", tx_bytes: "500" }, 100);
    assert.equal(s1.downloadRate, 0); assert.equal(s1.uploadRate, 0);
    assert.equal(s1.prevIface, "eth0"); assert.equal(s1.prevSampleTime, 100);
    const s2 = M.throughputState(s1, { iface: "wlp191s0", rx_bytes: "9", tx_bytes: "9" }, 101.5);
    assert.equal(s2.downloadRate, 0); assert.equal(s2.prevIface, "wlp191s0");
});

test("throughputState computes bytes per second from deltas", () => {
    const s1 = M.throughputState({}, { iface: "eth0", rx_bytes: "1000", tx_bytes: "500" }, 100);
    const s2 = M.throughputState(s1, { iface: "eth0", rx_bytes: "4000", tx_bytes: "800" }, 101.5);
    assert.equal(s2.downloadRate, 2000); assert.equal(s2.uploadRate, 200);
    // counter reset (interface re-plugged) never yields a negative rate
    const s3 = M.throughputState(s2, { iface: "eth0", rx_bytes: "10", tx_bytes: "10" }, 103);
    assert.equal(s3.downloadRate, 0); assert.equal(s3.uploadRate, 0);
});

test("pingState keeps rolling windows and counts timeouts as loss", () => {
    let s = M.pingState({}, { iface: "eth0", internet_ping_ms: "14" }, 3, 2);
    assert.equal(s.internetLatency, 14); assert.equal(s.packetLoss, 0);
    s = M.pingState(s, { iface: "eth0", internet_ping_ms: "" }, 3, 2);
    assert.deepEqual(s.internetSamples, [14, null]);
    assert.equal(s.internetLatency, 14);          // average ignores the timeout
    assert.equal(s.packetLoss, 50);
    s = M.pingState(s, { iface: "eth0", internet_ping_ms: "16" }, 3, 2);
    s = M.pingState(s, { iface: "eth0", internet_ping_ms: "18" }, 3, 2);
    assert.deepEqual(s.internetSamples, [null, 16, 18]);   // window of 3
    assert.equal(s.internetLatency, 17);                    // average of last 2
    assert.equal(s.packetLoss, 33);
});

test("pingState resets on iface change and on missing keys", () => {
    let s = M.pingState({}, { iface: "eth0", internet_ping_ms: "10" }, 5, 5);
    s = M.pingState(s, { iface: "wlp191s0", internet_ping_ms: "20" }, 5, 5);
    assert.deepEqual(s.internetSamples, [20]);
    s = M.pingState(s, { iface: "wlp191s0" }, 5, 5);
    assert.deepEqual(s.internetSamples, []); assert.equal(s.internetLatency, -1); assert.equal(s.packetLoss, 0);
    s = M.pingState(s, {}, 5, 5);
    assert.equal(s.pingIface, "");
});

test("formatBytes / formatRate / formatPing / formatPacketLoss", () => {
    assert.equal(M.formatBytes(512), "512 B");
    assert.equal(M.formatBytes(1536), "1.5 KB");
    assert.equal(M.formatBytes(2.3 * 1024 * 1024), "2.3 MB");
    assert.equal(M.formatBytes(1.2 * 1024 * 1024 * 1024), "1.20 GB");
    assert.equal(M.formatBytes(-5), "0 B"); assert.equal(M.formatBytes("x"), "0 B");
    assert.equal(M.formatRate(2000), "2.0 KB/s");
    assert.equal(M.formatPing(1.23, true), "1.2 ms");
    assert.equal(M.formatPing(14.6, true), "15 ms");
    assert.equal(M.formatPing(-1, true), "Timeout");
    assert.equal(M.formatPing(-1, false), "--");
    assert.equal(M.formatPacketLoss(0, true), "0%");
    assert.equal(M.formatPacketLoss(12, true), "12%");
    assert.equal(M.formatPacketLoss(12, false), "--");
});

test("wifiRow snapshots primitives and sortWifiRows orders connected, known, signal", () => {
    const row = M.wifiRow({ name: "Home", connected: false, known: true, signalStrength: 0.734, security: 4 });
    assert.deepEqual(row, { ssid: "Home", connected: false, known: true, signal: 73, security: 4 });
    assert.equal(M.wifiRow(null), null);
    const rows = M.sortWifiRows([
        { ssid: "c", connected: false, known: false, signal: 90 },
        { ssid: "b", connected: false, known: true,  signal: 40 },
        { ssid: "a", connected: true,  known: true,  signal: 10 },
        { ssid: "d", connected: false, known: false, signal: 95 },
    ]);
    assert.deepEqual(rows.map(r => r.ssid), ["a", "b", "d", "c"]);
});

test("wifiSectionTitle labels the first known and first other row", () => {
    const rows = [
        { ssid: "a", known: true }, { ssid: "b", known: true },
        { ssid: "c", known: false }, { ssid: "d", known: false },
    ];
    assert.equal(M.wifiSectionTitle(rows, 0), "KNOWN NETWORKS");
    assert.equal(M.wifiSectionTitle(rows, 1), "");
    assert.equal(M.wifiSectionTitle(rows, 2), "OTHER NETWORKS");
    assert.equal(M.wifiSectionTitle(rows, 3), "");
    assert.equal(M.wifiSectionTitle([{ ssid: "x", known: false }], 0), "OTHER NETWORKS");
    assert.equal(M.wifiSectionTitle(rows, 9), "");
});

test("requiresCredentials, canForget, failureText", () => {
    const OPEN = 10, OWE = 9;
    assert.equal(M.requiresCredentials(3, OPEN, OWE), true);
    assert.equal(M.requiresCredentials(OPEN, OPEN, OWE), false);
    assert.equal(M.requiresCredentials(OWE, OPEN, OWE), false);
    assert.equal(M.canForget({ known: true, connected: false }), true);
    assert.equal(M.canForget({ known: true, connected: true }), false);
    assert.equal(M.canForget(null), false);
    const R = { NoSecrets: 1, WifiClientDisconnected: 2, WifiClientFailed: 3, WifiAuthTimeout: 4, WifiNetworkLost: 5 };
    assert.equal(M.failureText(1, true, R), "Password rejected");
    assert.equal(M.failureText(4, true, R), "Wrong password");
    assert.equal(M.failureText(4, false, R), "Failed to connect");
    assert.equal(M.failureText(5, false, R), "Network lost");
    assert.equal(M.failureText(2, false, R), "Disconnected");
    assert.equal(M.failureText(3, false, R), "Connection failed");
    assert.equal(M.failureText(0, false, R), "Failed to connect");
});

test("shouldReprompt only for credential failures on credentialed networks", () => {
    const R = { NoSecrets: 1, WifiClientDisconnected: 2, WifiClientFailed: 3, WifiAuthTimeout: 4, WifiNetworkLost: 5 };
    assert.equal(M.shouldReprompt(1, true, R), true);
    assert.equal(M.shouldReprompt(4, true, R), true);
    assert.equal(M.shouldReprompt(4, false, R), false);
    assert.equal(M.shouldReprompt(5, true, R), false);
    assert.equal(M.shouldReprompt(0, true, R), false);
});

test("parseBandStatus, bandTitle", () => {
    assert.deepEqual(M.parseBandStatus("band\t5\navailable\t2.4 5\nselected\tauto\n"),
        { band: "5", selected: "auto", available: ["2.4", "5"] });
    assert.deepEqual(M.parseBandStatus(""), { band: "", selected: "auto", available: [] });
    assert.equal(M.bandTitle("auto", "5"), "WI-FI BAND: 5GHZ");
    assert.equal(M.bandTitle("auto", ""), "WI-FI BAND");
    assert.equal(M.bandTitle("5", "5"), "WI-FI BAND");
});

test("formatLinkSpeed", () => {
    assert.equal(M.formatLinkSpeed(1000), "1 Gbit");
    assert.equal(M.formatLinkSpeed(2500), "2.5 Gbit");
    assert.equal(M.formatLinkSpeed(100), "100 Mbit");
    assert.equal(M.formatLinkSpeed(0), "");
    assert.equal(M.formatLinkSpeed("abc"), "");
});
