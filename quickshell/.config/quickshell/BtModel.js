// Pure helpers behind BluetoothDrawer. Rows are primitive snapshots of a BluetoothDevice
// (a delegate must never hold the live object -- BlueZ can drop it mid-incubation).
// No QML references; tested by tests/quickshell/btmodel.test.js.

// Hide unnamed devices and MAC-shaped names (XX:XX:XX:XX:XX:XX).
function named(name, address) {
    var n = String(name || "");
    if (n.length === 0 || n === address) return false;
    return !/^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/.test(n);
}
function deviceRow(d) {
    if (!d) return null;
    return { address: d.address || "", name: d.name || "", icon: d.icon || "",
             connected: !!d.connected, paired: !!d.paired, bonded: !!d.bonded,
             pairing: !!d.pairing, trusted: !!d.trusted,
             batteryAvailable: !!d.batteryAvailable, battery: Number(d.battery || 0) };
}
function sortDeviceRows(rows) {
    var out = Array.isArray(rows) ? rows.slice() : [];
    out.sort(function (a, b) {
        if (!!a.connected !== !!b.connected) return a.connected ? -1 : 1;
        var ap = !!(a.paired || a.bonded), bp = !!(b.paired || b.bonded);
        if (ap !== bp) return ap ? -1 : 1;
        return String(a.name || "").toLowerCase().localeCompare(String(b.name || "").toLowerCase());
    });
    return out;
}
function deviceSectionTitle(rows, index) {
    var list = Array.isArray(rows) ? rows : [];
    if (index < 0 || index >= list.length) return "";
    if (list[index].connected) return index === 0 ? "CONNECTED" : "";
    if (index === 0 || list[index - 1].connected) return "DEVICES";
    return "";
}
function deviceStatus(row) {
    if (!row) return "";
    if (row.connected) {
        if (!row.batteryAvailable) return "connected";
        var b = Number(row.battery || 0);
        return Math.round(b > 1 ? b : b * 100) + "%";   // BlueZ reports 0..1; tolerate 0..100
    }
    if (row.pairing) return "pairing...";
    if (row.paired || row.bonded) return "paired";
    return "";
}
// BlueZ `Icon` names -> Theme.btDeviceGlyph kinds.
function deviceGlyphKind(icon) {
    var i = String(icon || "");
    if (i === "audio-headset" || i === "audio-headphones") return "headset";
    if (i === "input-mouse") return "mouse";
    if (i === "input-keyboard") return "keyboard";
    if (i === "phone") return "phone";
    if (i === "input-gaming") return "gamepad";
    if (i === "computer") return "laptop";
    if (i === "watch") return "watch";
    if (i === "audio-card" || i === "audio-speakers") return "speaker";
    return "bluetooth";
}

if (typeof module !== "undefined") {
    module.exports = { named: named, deviceRow: deviceRow, sortDeviceRows: sortDeviceRows,
                       deviceSectionTitle: deviceSectionTitle, deviceStatus: deviceStatus,
                       deviceGlyphKind: deviceGlyphKind };
}
