const test = require("node:test");
const assert = require("node:assert/strict");
const L = require("../../quickshell/.config/quickshell/ListSync.js");

// Minimal stand-in for QML's ListModel: count/get/set/insert/remove/move, plus an op log.
class FakeModel {
    constructor() { this.items = []; this.ops = []; }
    get count() { return this.items.length; }
    get(i) { return this.items[i]; }
    set(i, o) { this.items[i] = Object.assign({}, o); this.ops.push("set" + i); }
    insert(i, o) { this.items.splice(i, 0, Object.assign({}, o)); this.ops.push("insert" + i); }
    remove(i) { this.items.splice(i, 1); this.ops.push("remove" + i); }
    move(from, to, n) { const s = this.items.splice(from, n); this.items.splice(to, 0, ...s); this.ops.push("move" + from + ">" + to); }
}
const keys = (m) => m.items.map(r => r.id);

test("empty model: every row is inserted in order", () => {
    const m = new FakeModel();
    L.sync(m, [{ id: "a", v: 1 }, { id: "b", v: 2 }], "id");
    assert.deepEqual(keys(m), ["a", "b"]);
    assert.deepEqual(m.ops, ["insert0", "insert1"]);
});

test("same keys: rows are updated in place, never re-inserted", () => {
    const m = new FakeModel();
    L.sync(m, [{ id: "a", v: 1 }, { id: "b", v: 2 }], "id");
    m.ops = [];
    L.sync(m, [{ id: "a", v: 9 }, { id: "b", v: 2 }], "id");
    assert.deepEqual(m.ops, ["set0", "set1"]);
    assert.equal(m.get(0).v, 9);
});

test("removed keys are dropped, new keys inserted at their position", () => {
    const m = new FakeModel();
    L.sync(m, [{ id: "a" }, { id: "b" }, { id: "c" }], "id");
    m.ops = [];
    L.sync(m, [{ id: "a" }, { id: "x" }, { id: "c" }], "id");
    assert.deepEqual(keys(m), ["a", "x", "c"]);
    assert.deepEqual(m.ops, ["remove1", "set0", "insert1", "set2"]);
});

test("reordered keys move instead of being recreated", () => {
    const m = new FakeModel();
    L.sync(m, [{ id: "a" }, { id: "b" }, { id: "c" }], "id");
    m.ops = [];
    L.sync(m, [{ id: "c" }, { id: "a" }, { id: "b" }], "id");
    assert.deepEqual(keys(m), ["c", "a", "b"]);
    assert.ok(m.ops.includes("move2>0"));
    assert.ok(!m.ops.some(op => op.startsWith("insert") || op.startsWith("remove")));
});

test("duplicate keys keep the first occurrence; null clears", () => {
    const m = new FakeModel();
    L.sync(m, [{ id: "a", v: 1 }, { id: "a", v: 2 }, { id: "b" }], "id");
    assert.deepEqual(keys(m), ["a", "b"]);
    assert.equal(m.get(0).v, 1);
    L.sync(m, null, "id");
    assert.equal(m.count, 0);
});
