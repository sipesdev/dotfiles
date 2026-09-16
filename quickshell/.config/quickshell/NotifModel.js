// Pure functions behind the notification card. No QML or Quickshell references, so Node
// can run the tests in tests/quickshell/notifmodel.test.js.

// A notification's image hint is sender-chosen. Keep it to what the spec means by
// image-path -- a local file -- plus Quickshell's own image:// providers (inline
// image-data, theme icons). Anything else is dropped, so a toast can never make the bar
// fetch from the network or exercise a Qt URL scheme handler.
function localImage(source) {
    if (typeof source !== "string" || source === "") return "";
    if (source.startsWith("/") || source.startsWith("file://")) return source;
    if (source.startsWith("image://qsimage/") || source.startsWith("image://icon/")) return source;
    return "";
}

if (typeof module !== "undefined") {
    module.exports = { localImage: localImage };
}
