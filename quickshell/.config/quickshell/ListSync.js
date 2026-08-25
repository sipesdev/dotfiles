// Bring a ListModel in line with an array of row objects WITHOUT recreating delegates. Rows are
// matched by `key`: stale rows are removed, new ones inserted, survivors updated in place (set)
// and moved into order. A Repeater fed a fresh JS array instead tears every delegate down, which
// drops the hovered row's hover (it flashes) and any in-flight animation. Every row must carry
// the same set of keys with primitive values: ListModel roles are fixed by the first insert.
// No QML references; tested by tests/quickshell/listsync.test.js against a fake model.

function sync(model, rows, key) {
    var want = [], seen = {};
    var input = Array.isArray(rows) ? rows : [];
    for (var i = 0; i < input.length; i++) {
        var k = String(input[i][key]);
        if (seen[k]) continue;                       // duplicate key: first occurrence wins
        seen[k] = true;
        want.push(input[i]);
    }
    for (var j = model.count - 1; j >= 0; j--) {
        if (!seen[String(model.get(j)[key])]) model.remove(j);
    }
    for (var n = 0; n < want.length; n++) {
        var row = want[n], at = -1;
        for (var m = n; m < model.count; m++) {
            if (model.get(m)[key] === row[key]) { at = m; break; }
        }
        if (at === -1) { model.insert(n, row); continue; }
        if (at !== n) model.move(at, n, 1);
        model.set(n, row);
    }
}

if (typeof module !== "undefined") module.exports = { sync: sync };
