const test = require("node:test");
const assert = require("node:assert/strict");
const M = require("../../quickshell/.config/quickshell/LauncherModel.js");

const names = rows => rows.map(e => e.name);

test("sortedApps hides noDisplay and nameless entries", () => {
    // as in Omarchy, entryName falls back to id, so only an entry with neither is dropped
    assert.deepEqual(names(M.sortedApps([
        { id: "a", name: "Alpha" },
        { id: "h", name: "Hidden", noDisplay: true },
        { id: "", name: "" },
    ], "")), ["Alpha"]);
});

test("sortedApps lists everything alphabetically for an empty query", () => {
    assert.deepEqual(names(M.sortedApps([
        { id: "b", name: "brave" },
        { id: "a", name: "Alacritty" },
        { id: "c", name: "calc" },
    ], "  ")), ["Alacritty", "brave", "calc"]);
});

test("name prefix outranks name substring", () => {
    assert.deepEqual(names(M.sortedApps([
        { id: "vscode", name: "VS Code" },
        { id: "code", name: "Code" },
    ], "code")), ["Code", "VS Code"]);
});

test("acronym matches short terms", () => {
    assert.deepEqual(names(M.sortedApps([
        { id: "org.gnome.Nautilus", name: "Files" },
        { id: "vs", name: "Visual Studio Code" },
    ], "vsc")), ["Visual Studio Code"]);
    assert.equal(M.entryAcronym({ id: "vs", name: "Visual Studio Code" }), "vscv");
});

test("every term must match", () => {
    assert.deepEqual(names(M.sortedApps([
        { id: "steam", name: "Steam" },
        { id: "link", name: "Steam Link" },
    ], "steam link")), ["Steam Link"]);
});

test("keywords and genericName are searched", () => {
    assert.deepEqual(names(M.sortedApps([
        { id: "org.gnome.Nautilus", name: "Files", keywords: ["folder", "explorer"] },
    ], "explorer")), ["Files"]);
    assert.deepEqual(names(M.sortedApps([
        { id: "brave-browser", name: "Brave", genericName: "Web Browser" },
    ], "web")), ["Brave"]);
});

test("keywords that are not an array are ignored", () => {
    assert.deepEqual(names(M.sortedApps([{ id: "x", name: "Xapp", keywords: null }], "xapp")), ["Xapp"]);
});

test("no match yields nothing", () => {
    assert.deepEqual(names(M.sortedApps([{ id: "a", name: "Alpha" }], "zzz")), []);
});

test("= prefix suppresses app rows", () => {
    assert.deepEqual(M.sortedApps([{ id: "c", name: "Calc" }], "=2"), []);
});

test("calcExpression accepts math-looking queries", () => {
    assert.equal(M.calcExpression("2+2"), "2+2");
    assert.equal(M.calcExpression("5 ft to m"), "5 ft to m");
    assert.equal(M.calcExpression("sqrt(2)*3"), "sqrt(2)*3");
    assert.equal(M.calcExpression("2^10"), "2^10");
    assert.equal(M.calcExpression("  2*3  "), "2*3");
});

test("calcExpression rejects non-math", () => {
    assert.equal(M.calcExpression("1990"), "");
    assert.equal(M.calcExpression("steam 2"), "");
    assert.equal(M.calcExpression("firefox"), "");
    assert.equal(M.calcExpression("1+"), "");           // under 3 chars
    assert.equal(M.calcExpression("10 kg in lb"), "");
    assert.equal(M.calcExpression("x+y"), "");          // no digit
});

test("= forces calc", () => {
    assert.equal(M.calcExpression("=sqrt 2"), "sqrt 2");
    assert.equal(M.calcExpression("= 1990"), "1990");
    assert.equal(M.calcExpression("="), "");
    assert.equal(M.calcExpression("=  "), "");
});

test("calcResult keeps a real answer", () => {
    assert.equal(M.calcResult("2-7", "-5\n"), "-5");
    assert.equal(M.calcResult("2+2", "\n4\n"), "4");    // last non-empty line
});

test("calcResult hides an echo or empty output", () => {
    assert.equal(M.calcResult("x+2", "x + 2\n"), "");
    assert.equal(M.calcResult("3 / 0", "3 / 0"), "");
    assert.equal(M.calcResult("2+2", ""), "");
    assert.equal(M.calcResult("2+2", null), "");
});
