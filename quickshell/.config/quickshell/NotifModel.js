// Pure functions behind the notification card. No QML or Quickshell references, so Node
// can run the tests in tests/quickshell/notifmodel.test.js.

// A notification's image hint is sender-chosen. Keep it to what the spec means by
// image-path -- a local file -- plus Quickshell's own image:// providers (inline
// image-data, theme icons). Anything else is dropped, so a toast can never make the bar
// fetch from the network or exercise a Qt URL scheme handler. Quickshell rewrites a
// non-path image-path hint into image://icon/<hint>, so a remote URL arrives as
// image://icon/http://...; a provider payload that carries a scheme of its own is dropped
// too.
function localImage(source) {
    if (typeof source !== "string" || source === "") return "";
    if (source.startsWith("/") || source.startsWith("file://")) return source;
    if ((source.startsWith("image://qsimage/") || source.startsWith("image://icon/")) && source.indexOf("://", 8) === -1) return source;
    return "";
}

// xdg-desktop-portal-hyprland creates one PipeWire stream per ScreenCast session with
// pw_stream_new(core, "xdph-streaming-...", {media.class=Video/Source}), and PipeWire names
// that node after the client's application.name, so node.name is the portal's own name.
// The node lives exactly as long as the session, which is what makes it the signal for
// "a screen is being shared". The name match is load-bearing: the webcam is also a
// Video/Source and is always present, so the type alone would mute everything. QML passes
// PwNodeType.VideoSource as `flag`; the mask test is AudioModel.isAudioSource's.
function isScreenCast(name, type, flag) {
    if (name !== "xdg-desktop-portal-hyprland") return false;
    var t = Number(type), f = Number(flag);
    if (!isFinite(t) || !isFinite(f) || f === 0) return false;
    return (t & f) === f;
}

if (typeof module !== "undefined") {
    module.exports = { localImage: localImage, isScreenCast: isScreenCast };
}
