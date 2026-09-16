const test = require("node:test");
const assert = require("node:assert/strict");
const N = require("../../quickshell/.config/quickshell/NotifModel.js");

test("localImage keeps local files and Quickshell image providers", () => {
    assert.equal(N.localImage("/usr/share/icons/x.png"), "/usr/share/icons/x.png");
    assert.equal(N.localImage("file:///home/u/pic.png"), "file:///home/u/pic.png");
    assert.equal(N.localImage("image://qsimage/12"), "image://qsimage/12");
    assert.equal(N.localImage("image://icon/dialog-information"), "image://icon/dialog-information");
});

test("localImage drops remote and exotic schemes", () => {
    assert.equal(N.localImage("http://evil.example/beacon.png"), "");
    assert.equal(N.localImage("https://evil.example/beacon.png"), "");
    assert.equal(N.localImage("ftp://evil.example/x"), "");
    assert.equal(N.localImage("data:image/png;base64,AAAA"), "");
    assert.equal(N.localImage("qrc:/x.png"), "");
    assert.equal(N.localImage(""), "");
    assert.equal(N.localImage(null), "");
    assert.equal(N.localImage(undefined), "");
});
