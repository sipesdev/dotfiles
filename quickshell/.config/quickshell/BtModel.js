// Pure helpers behind BluetoothDrawer, ported from Omarchy's bluetooth Model.js. Rows are
// primitive snapshots of a BluetoothDevice: holding the live QObject in model data puts a wrapper
// in every delegate's var property, and BlueZ churn (discovery timeouts, unpair) can destroy it
// while a delegate is still incubating, which segfaults quickshell. Actions re-resolve the device
// by address. No QML references; tested by tests/quickshell/btmodel.test.js.

function toArray(values) {
    if (!values) return [];
    if (Array.isArray(values)) return values.slice();
    var length = Number(values.length || 0);
    if (!isFinite(length) || length <= 0) return [];
    var list = [];
    for (var i = 0; i < length; i++) list.push(values[i]);
    return list;
}

// BlueZ Alias (user-renameable) wins over the advertised name.
function deviceLabel(device) {
    if (!device) return "";
    return String(device.deviceName || device.name || "").trim();
}
function isUuidLike(value) {
    var text = String(value || "").trim();
    if (text === "") return false;
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(text)
        || /^[0-9a-f]{32}$/i.test(text)
        || /^0x[0-9a-f]{4,32}$/i.test(text);
}
function isAddressLike(value) {
    return /^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(String(value || "").trim());
}
// Anonymous beacons, phones advertising raw MACs and BLE junk never reach the list.
function hasHumanName(device) {
    var label = deviceLabel(device);
    return label !== "" && !isUuidLike(label) && !isAddressLike(label);
}
function normalizedAddress(value) {
    return String(value || "").toLowerCase().replace(/[^0-9a-f]/g, "");
}
function sortedByLabel(devices) {
    var list = toArray(devices);
    list.sort(function (a, b) { return deviceLabel(a).localeCompare(deviceLabel(b)); });
    return list;
}
// Three mutually exclusive buckets, first match wins, each alphabetical: a device can never
// render twice. A merely-trusted device counts as remembered.
function deviceLists(devices) {
    var values = toArray(devices), connected = [], known = [], discovered = [];
    for (var i = 0; i < values.length; i++) {
        var d = values[i];
        if (!d || !hasHumanName(d)) continue;
        if (d.connected) connected.push(d);
        else if (d.paired || d.bonded || d.trusted) known.push(d);
        else discovered.push(d);
    }
    return { connected: sortedByLabel(connected), known: sortedByLabel(known), discovered: sortedByLabel(discovered) };
}
function deviceRow(d, section) {
    if (!d) return null;
    return { address: d.address || "", label: deviceLabel(d) || "Device", section: section || "",
             connected: !!d.connected, state: d.state !== undefined ? d.state : -1,
             batteryAvailable: !!d.batteryAvailable, battery: d.battery !== undefined ? d.battery : 0,
             pairing: !!d.pairing };
}
// A row opens a section when it is the first of its kind in the flat list.
function scrollSectionTitle(rows, index) {
    var list = Array.isArray(rows) ? rows : [];
    if (index < 0 || index >= list.length) return "";
    if (index > 0 && list[index - 1].section === list[index].section) return "";
    return list[index].section === "known" ? "PAIRED" : "AVAILABLE";
}
// S carries BluetoothDeviceState values from QML ({ Disconnecting, Connecting }). Pairing reads
// as "Connecting…" too: one click on an AVAILABLE row pairs, trusts and connects.
function statusText(row, action, S) {
    var e = S || {};
    if (!row) return "";
    if (action === "forgetting") return "Forgetting…";
    if (action === "disconnecting" || row.state === e.Disconnecting) return "Disconnecting…";
    if (row.connected) {
        if (row.batteryAvailable) { var b = Number(row.battery || 0); return Math.round(b > 1 ? b : b * 100) + "%"; }
        return row.section === "connected" ? "" : "Connected";
    }
    if (action === "connecting" || action === "pairing"
        || row.state === e.Connecting || row.pairing) return "Connecting…";
    return "";
}
// Connected or in-flight rows read at full strength; idle rows are dimmed.
function statusStrong(row, action, S) {
    var e = S || {};
    if (!row) return false;
    if (row.connected) return true;
    return (action || "") !== "" || row.state === e.Connecting || !!row.pairing;
}
function cloneMap(map) { var next = {}; for (var k in (map || {})) next[k] = map[k]; return next; }
function pendingAction(actions, address) { return address && actions && actions[address] ? actions[address] : ""; }
// New object identity every time: a QML var binding only re-evaluates on assignment.
function withPendingAction(actions, address, action) {
    var next = cloneMap(actions);
    if (!address) return next;
    if (action) next[address] = action; else delete next[address];
    return next;
}
// The Pipewire sink of a device: match the address baked into bluez_output.AA_BB_... node names
// (every non-hex character stripped from both sides), else the human label.
function nodeText(node) {
    if (!node) return "";
    var p = node.ready && node.properties ? node.properties : {};
    return [node.name, node.description, node.nickname, p["node.name"], p["node.description"], p["node.nick"],
            p["device.name"], p["device.description"], p["device.product.name"], p["device.alias"],
            p["api.bluez5.address"], p["bluez5.address"]].join(" ").toLowerCase();
}
function bluetoothSinkMatchesDevice(node, device) {
    if (!node || !node.isSink || node.isStream || !device) return false;
    var address = normalizedAddress(device.address);
    var text = nodeText(node);
    if (address !== "" && normalizedAddress(text).indexOf(address) !== -1) return true;
    var label = String(device.label || deviceLabel(device) || "").toLowerCase();
    return label !== "" && text.indexOf(label) !== -1;
}

if (typeof module !== "undefined") {
    module.exports = { toArray: toArray, deviceLabel: deviceLabel, isUuidLike: isUuidLike, isAddressLike: isAddressLike,
                       hasHumanName: hasHumanName, normalizedAddress: normalizedAddress, sortedByLabel: sortedByLabel,
                       deviceLists: deviceLists, deviceRow: deviceRow, scrollSectionTitle: scrollSectionTitle,
                       statusText: statusText, statusStrong: statusStrong, cloneMap: cloneMap,
                       pendingAction: pendingAction, withPendingAction: withPendingAction, nodeText: nodeText,
                       bluetoothSinkMatchesDevice: bluetoothSinkMatchesDevice };
}
