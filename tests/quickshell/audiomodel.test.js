const test = require("node:test");
const assert = require("node:assert/strict");
const A = require("../../quickshell/.config/quickshell/AudioModel.js");

test("isAudioSource masks the flag", () => {
    assert.equal(A.isAudioSource(7, 3), true);
    assert.equal(A.isAudioSource(4, 3), false);
    assert.equal(A.isAudioSource(undefined, 3), false);
    assert.equal(A.isAudioSource(7, 0), false);
});

test("friendlyDeviceLabel strips vendor noise", () => {
    assert.equal(A.friendlyDeviceLabel("sof-soundwire Headphones Output"), "Headphones");
    assert.equal(A.friendlyDeviceLabel("Built-in Audio Analog Stereo"), "Analog Stereo");
    assert.equal(A.friendlyDeviceLabel("Digital Microphones Input"), "Digital Microphone");
    assert.equal(A.friendlyDeviceLabel("  Speaker "), "Speaker");
    assert.equal(A.friendlyDeviceLabel(null), "");
});

test("nodeLabel prefers nickname, then bound properties, then description, then name", () => {
    assert.equal(A.nodeLabel({ nickname: "Thunderbolt Dock 96W Audio Device" }), "Thunderbolt Dock 96W Audio Device");
    assert.equal(A.nodeLabel({ description: "Ryzen HD Audio Controller Speaker" }), "Ryzen HD Audio Controller Speaker");
    assert.equal(A.nodeLabel({ name: "alsa_output.x" }), "alsa_output.x");
    assert.equal(A.nodeLabel(null), "Unknown");
    assert.equal(A.nodeLabel({ ready: true, properties: { "node.nick": "Dock" }, name: "n" }), "Dock");
    assert.equal(A.nodeLabel({ ready: false, properties: { "node.nick": "Dock" }, name: "n" }), "n");
});

test("sinkKind / sourceKind heuristics", () => {
    assert.equal(A.sinkKind({ description: "Ryzen HD Audio Controller Speaker" }), "speaker");
    assert.equal(A.sinkKind({ name: "bluez_output.2C_BE_EB" }), "bluetooth");
    assert.equal(A.sinkKind({ description: "HDMI / DisplayPort 1" }), "hdmi");
    assert.equal(A.sinkKind({ nickname: "WH-1000XM4", name: "bluez_output.x", description: "Headphones" }), "headphones");
    assert.equal(A.sinkKind(null), "speaker");
    assert.equal(A.sourceKind({ description: "USB Condenser Microphone Mono" }), "microphone");
    assert.equal(A.sourceKind({ description: "C920 Webcam Analog Stereo" }), "webcam");
    assert.equal(A.sourceKind({ name: "bluez_input.xx" }), "bluetooth");
    assert.equal(A.sourceKind({ description: "Headset Mono" }), "headset");
    assert.equal(A.sourceKind(null), "microphone");
});
