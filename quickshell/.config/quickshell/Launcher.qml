pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "LauncherModel.js" as LauncherModel

// App launcher state: whether it is open, the query, the matching desktop entries and the
// calculator row. LauncherWindow draws it; the Arch button and `qs ipc call launcher toggle`
// (the Hyprland keybind) open it. Auto-resolved by filename (like Theme), so any component can
// read `Launcher.*`.
Singleton {
    id: launcher

    property bool opened: false
    property string query: ""

    function open() { query = ""; opened = true; }
    function close() { opened = false; }
    function toggle() { if (opened) close(); else open(); }

    readonly property var apps: LauncherModel.sortedApps(DesktopEntries.applications.values, query)
    readonly property string calcExpr: LauncherModel.calcExpression(query)
    // The result shown in the calc row; "" hides the row.
    property string calcText: ""

    // uwsm-app starts the entry as its own systemd scope, so the app outlives the shell and is
    // not charged to it; the id form resolves the .desktop file itself.
    function launch(entry) {
        Quickshell.execDetached(["uwsm-app", "--", entry.id + ".desktop"]);
        close();
    }

    function copyCalc() {
        Quickshell.execDetached(["wl-copy", "-n", "--", calcText]);
        close();
    }

    // ── Calculator: qalc, one run at a time, latest wins ─────────────
    // No debounce: a run is cheap, and when the expression moves on mid-run the finished result
    // is dropped and qalc runs again for the current one. The previous result stays up until
    // the current one lands, so the row does not flicker per keystroke.
    property string ranExpr: ""

    function runCalc() {
        if (calcExpr === "") return;
        ranExpr = calcExpr;
        qalc.running = true;
    }

    onCalcExprChanged: {
        if (calcExpr === "") calcText = "";
        else if (!qalc.running) runCalc();
        // busy: onExited sees ranExpr !== calcExpr and reruns
    }

    Process {
        id: qalc
        command: ["qalc", "-t", "-s", "unicode off", "--", launcher.ranExpr]
        stdout: StdioCollector { id: qalcOut }
        onExited: {
            if (launcher.ranExpr === launcher.calcExpr)
                launcher.calcText = LauncherModel.calcResult(launcher.ranExpr, qalcOut.text);
            else
                launcher.runCalc();
        }
    }

    // One throwaway run per shell start refreshes qalc's cached exchange rates, which is what
    // Elephant's calculator did at its own start, so the first currency query is not stale.
    Component.onCompleted: Quickshell.execDetached(["qalc", "-e", "1+1"])

    IpcHandler {
        target: "launcher"

        function toggle(): void { launcher.toggle(); }
        function open(): void { launcher.open(); }
        function close(): void { launcher.close(); }
    }
}
