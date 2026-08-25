// Pure functions behind NetworkPopout: parsing the network-probe script,
// rate and ping bookkeeping, formatting. No QML or Quickshell references, so Node can
// run the tests in tests/quickshell/netmodel.test.js.

function parseKeyValue(raw) {
    var next = {};
    var lines = String(raw || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (!line) continue;
        var idx = line.indexOf("\t");
        if (idx === -1) continue;
        next[line.substring(0, idx)] = line.substring(idx + 1).trim();
    }
    return next;
}

// Bytes per second from two cumulative sysfs counters. The first sample after open, or
// after the interface changes (dock in/out), seeds and reports 0 rather than a spike.
function throughputState(previous, sample, now) {
    var prev = previous || {}, s = sample || {};
    var iface = s.iface || "";
    var rx = parseFloat(s.rx_bytes || "0"), tx = parseFloat(s.tx_bytes || "0");
    var prevTime = Number(prev.prevSampleTime || 0);
    if (iface !== (prev.prevIface || "") || prevTime === 0) {
        return { prevIface: iface, prevRxBytes: rx, prevTxBytes: tx, prevSampleTime: now,
                 downloadRate: 0, uploadRate: 0 };
    }
    var down = Number(prev.downloadRate || 0), up = Number(prev.uploadRate || 0);
    var dt = now - prevTime;
    if (dt > 0) {
        down = Math.max(0, (rx - Number(prev.prevRxBytes || 0)) / dt);
        up   = Math.max(0, (tx - Number(prev.prevTxBytes || 0)) / dt);
    }
    return { prevIface: iface, prevRxBytes: rx, prevTxBytes: tx, prevSampleTime: now,
             downloadRate: down, uploadRate: up };
}

function pingValue(raw) {
    var v = parseFloat(raw);
    return (!isFinite(v) || v < 0) ? null : v;
}
function appendSample(samples, raw, limit) {
    var values = Array.isArray(samples) ? samples.slice() : [];
    values.push(pingValue(raw));
    while (values.length > limit) values.shift();
    return values;
}
function averageLatency(samples, limit) {
    var values = Array.isArray(samples) ? samples : [];
    var n = Math.max(1, parseInt(limit, 10) || values.length || 1);
    var total = 0, count = 0;
    for (var i = Math.max(0, values.length - n); i < values.length; i++) {
        var v = values[i];
        if (typeof v !== "number" || !isFinite(v) || v < 0) continue;
        total += v; count++;
    }
    return count > 0 ? total / count : -1;
}
function packetLossPercent(samples) {
    var values = Array.isArray(samples) ? samples : [];
    if (values.length === 0) return 0;
    var lost = 0;
    for (var i = 0; i < values.length; i++) if (values[i] === null) lost++;
    return Math.round((lost / values.length) * 100);
}

// Rolling window of 1.1.1.1 pings (history of `limit`, averaged over the last `averageLimit`).
// A timed-out probe is a null sample: it drags packet loss up but not the average.
function pingState(previous, sample, limit, averageLimit) {
    var prev = previous || {}, s = sample || {};
    var iface = s.iface || "";
    var window = Math.max(1, parseInt(limit, 10) || 5);
    var avgWindow = Math.max(1, parseInt(averageLimit, 10) || window);
    var reset = iface === "" || iface !== (prev.pingIface || "");
    var internet = reset ? [] : prev.internetSamples;
    internet = s.internet_ping_ms === undefined ? [] : appendSample(internet, s.internet_ping_ms, window);
    return { pingIface: iface, internetSamples: internet,
             internetLatency: averageLatency(internet, avgWindow),
             packetLoss: packetLossPercent(internet) };
}

function formatBytes(bytes) {
    var n = Number(bytes);
    if (!isFinite(n) || n < 0) n = 0;
    if (n < 1024) return Math.round(n) + " B";
    if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KB";
    if (n < 1024 * 1024 * 1024) return (n / (1024 * 1024)).toFixed(1) + " MB";
    return (n / (1024 * 1024 * 1024)).toFixed(2) + " GB";
}
function formatRate(bytesPerSec) { return formatBytes(bytesPerSec) + "/s"; }

// hasSamples false = no probe has returned yet (rows read "--" and hold their place);
// a probe that returned but timed out reads "Timeout".
function formatPing(ms, hasSamples) {
    if (hasSamples === false) return "--";
    var v = parseFloat(ms);
    if (!isFinite(v) || v < 0) return "Timeout";
    return v.toFixed(v > 0 && v < 10 ? 1 : 0) + " ms";
}
function formatPacketLoss(percent, hasSamples) {
    if (hasSamples === false) return "--";
    var v = parseInt(percent, 10);
    if (!v || v < 0) return "0%";
    return v + "%";
}

// Primitives only: rows become list-model data, and holding a live WifiNetwork object in a
// delegate's var property lets NetworkManager churn (scans, AP removals) destroy it while the
// delegate is still incubating, which segfaults quickshell on the dangling wrapper. Callers
// that need the object look it up again by SSID at action time.
function wifiRow(network) {
    if (!network) return null;
    return { ssid: network.name || "", connected: !!network.connected, known: !!network.known,
             signal: Math.round((network.signalStrength || 0) * 100), security: network.security };
}
function sortWifiRows(rows) {
    var nets = Array.isArray(rows) ? rows.slice() : [];
    nets.sort(function (a, b) {
        if (a.connected !== b.connected) return a.connected ? -1 : 1;
        if (a.known !== b.known) return a.known ? -1 : 1;
        return b.signal - a.signal;
    });
    return nets;
}
function wifiSectionTitle(rows, index) {
    var nets = Array.isArray(rows) ? rows : [];
    if (index < 0 || index >= nets.length) return "";
    var net = nets[index];
    if (!net) return "";
    if (net.known && index === 0) return "KNOWN NETWORKS";
    if (!net.known && (index === 0 || (nets[index - 1] && nets[index - 1].known))) return "OTHER NETWORKS";
    return "";
}

// OWE (Enhanced Open) encrypts without credentials, so it gets no lock and no prompt.
// Unknown security stays credentialed as the conservative fallback.
function requiresCredentials(security, openValue, oweValue) {
    return security !== openValue && security !== oweValue;
}
function canForget(row) { return !!(row && row.known); }   // forgetting a connected network disconnects it too
function failureText(reason, needsCredentials, R) {
    var r = R || {};
    // The supplicant reports a timed-out 4-way handshake exactly like a wrong key, and NM then
    // surfaces either as no-secrets / auth-timeout: neither proves the key is wrong.
    if (needsCredentials && (reason === r.NoSecrets || reason === r.WifiAuthTimeout)) return "Couldn't authenticate";
    if (reason === r.WifiNetworkLost) return "Network lost";
    if (reason === r.WifiClientDisconnected) return "Disconnected";
    if (reason === r.WifiClientFailed) return "Connection failed";
    return "Failed to connect";
}

// A failed connect reopens the passphrase prompt when the key is the likely cause: NoSecrets
// (how NetworkManager surfaces a psk mismatch with no secret agent) or an auth timeout.
// connectWithPsk then replaces the stored key.
function shouldReprompt(reason, needsCredentials, R) {
    var r = R || {};
    if (!needsCredentials) return false;
    return reason === r.NoSecrets || reason === r.WifiAuthTimeout;
}

function formatLinkSpeed(mbps) {
    var v = parseInt(mbps, 10);
    if (!v || v < 0) return "";
    if (v >= 1000) return (v / 1000).toFixed(v % 1000 === 0 ? 0 : 1) + " Gbit";
    return v + " Mbit";
}

if (typeof module !== "undefined") {
    module.exports = {
        parseKeyValue: parseKeyValue, throughputState: throughputState, pingState: pingState,
        formatBytes: formatBytes, formatRate: formatRate, formatPing: formatPing,
        formatPacketLoss: formatPacketLoss, wifiRow: wifiRow, sortWifiRows: sortWifiRows,
        wifiSectionTitle: wifiSectionTitle, requiresCredentials: requiresCredentials,
        canForget: canForget, failureText: failureText, shouldReprompt: shouldReprompt,
        formatLinkSpeed: formatLinkSpeed
    };
}
