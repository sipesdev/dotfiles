// Pure helpers behind AudioDrawer: which Pipewire nodes are pickable devices, how to label
// them, which glyph kind fits. No QML references; tested by tests/quickshell/audiomodel.test.js.

// PwNode.type is a flags value; QML passes PwNodeType.AudioSource as `flag`.
function isAudioSource(type, flag) {
    var t = Number(type), f = Number(flag);
    if (!isFinite(t) || !isFinite(f) || f === 0) return false;
    return (t & f) === f;
}
function friendlyDeviceLabel(text) {
    var label = String(text || "").trim();
    label = label.replace(/^sof-soundwire\s+/i, "");
    label = label.replace(/^built-?in audio\s+/i, "");
    label = label.replace(/\s+Output$/i, "");
    label = label.replace(/\s+Input$/i, "");
    label = label.replace(/\bMicrophones\b/g, "Microphone");
    return label;
}
// properties are only valid once the node is bound (ready); unbound nodes read as {}.
function nodeProps(node) { return node && node.ready && node.properties ? node.properties : {}; }
function nodeLabel(node) {
    if (!node) return "Unknown";
    var p = nodeProps(node);
    var nick = friendlyDeviceLabel(node.nickname || p["node.nick"] || p["device.profile.description"] || "");
    if (nick) return nick;
    return friendlyDeviceLabel(node.description || p["node.description"] || node.name || "Unknown");
}
function blob(node) {
    var p = nodeProps(node);
    return String([node.name, node.description, node.nickname,
                   p["device.icon-name"] || "", p["device.product.name"] || ""].join(" ")).toLowerCase();
}
function sinkKind(node) {
    if (!node) return "speaker";
    var b = blob(node);
    if (b.indexOf("headphone") !== -1 || b.indexOf("headset") !== -1 ||
        b.indexOf("earbud") !== -1 || b.indexOf("airpod") !== -1) return "headphones";
    if (b.indexOf("bluetooth") !== -1 || b.indexOf("bluez") !== -1) return "bluetooth";
    if (b.indexOf("hdmi") !== -1 || b.indexOf("displayport") !== -1) return "hdmi";
    return "speaker";
}
function sourceKind(node) {
    if (!node) return "microphone";
    var b = blob(node);
    if (b.indexOf("headset") !== -1) return "headset";
    if (b.indexOf("bluetooth") !== -1 || b.indexOf("bluez") !== -1) return "bluetooth";
    if (b.indexOf("webcam") !== -1 || b.indexOf("camera") !== -1) return "webcam";
    return "microphone";
}

if (typeof module !== "undefined") {
    module.exports = { isAudioSource: isAudioSource, friendlyDeviceLabel: friendlyDeviceLabel,
                       nodeLabel: nodeLabel, sinkKind: sinkKind, sourceKind: sourceKind };
}
