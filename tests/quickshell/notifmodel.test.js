const test = require("node:test");
const assert = require("node:assert/strict");
const N = require("../../quickshell/.config/quickshell/NotifModel.js");

test("localImage keeps local files and Quickshell image providers", () => {
    assert.equal(N.localImage("/usr/share/icons/x.png"), "/usr/share/icons/x.png");
    assert.equal(N.localImage("file:///home/u/pic.png"), "file:///home/u/pic.png");
    assert.equal(N.localImage("image://qsimage/12"), "image://qsimage/12");
    assert.equal(N.localImage("image://icon/dialog-information"), "image://icon/dialog-information");
    assert.equal(N.localImage("image://icon/dialog-information?path=/usr/share/icons"), "image://icon/dialog-information?path=/usr/share/icons");
});

test("localImage drops remote and exotic schemes", () => {
    assert.equal(N.localImage("http://evil.example/beacon.png"), "");
    assert.equal(N.localImage("https://evil.example/beacon.png"), "");
    assert.equal(N.localImage("ftp://evil.example/x"), "");
    assert.equal(N.localImage("data:image/png;base64,AAAA"), "");
    assert.equal(N.localImage("qrc:/x.png"), "");
    assert.equal(N.localImage("image://icon/http://evil.example/beacon.png"), "");
    assert.equal(N.localImage("image://icon/https://evil.example/x.png"), "");
    assert.equal(N.localImage("image://qsimage/http://evil.example/x.png"), "");
    assert.equal(N.localImage(""), "");
    assert.equal(N.localImage(null), "");
    assert.equal(N.localImage(undefined), "");
});

test("isScreenCast matches only the xdph portal stream", () => {
    assert.equal(N.isScreenCast("xdg-desktop-portal-hyprland", 10, 10), true);
    assert.equal(N.isScreenCast("xdg-desktop-portal-hyprland", 14, 10), true);
    assert.equal(N.isScreenCast("v4l2_input.pci-0000_c2_00.4-usb-0_1_1.0", 10, 10), false);
    assert.equal(N.isScreenCast("xdg-desktop-portal-hyprland", 9, 10), false);
    assert.equal(N.isScreenCast("xdg-desktop-portal-hyprland", 18, 10), false);
    assert.equal(N.isScreenCast("xdg-desktop-portal-hyprland", 10, 0), false);
    assert.equal(N.isScreenCast("xdg-desktop-portal-hyprland", undefined, 10), false);
    assert.equal(N.isScreenCast(null, 10, 10), false);
    assert.equal(N.isScreenCast(undefined, 10, 10), false);
    assert.equal(N.isScreenCast("", 10, 10), false);
});
