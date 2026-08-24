import QtQuick
import QtQuick.Layouts
import "BtModel.js" as BtModel

// Bluetooth module: adapter toggle, then the named devices BlueZ reports (CONNECTED first,
// then DEVICES). Rows are primitive snapshots (BtModel.deviceRow); the live device is
// looked up by address at click time. Discovery runs only while the drawer is open.
BarDrawer {
    id: bt
    contentWidth: 320
    spacing: 4

    readonly property var adapter: Sys.btAdapter
    readonly property int maxListH: Math.round((Screen.height > 0 ? Screen.height : 1000) * 0.5)
    property var rows: []

    function deviceFor(address) {
        if (!adapter) return null;
        var ds = adapter.devices.values;
        for (var i = 0; i < ds.length; i++) if (ds[i] && ds[i].address === address) return ds[i];
        return null;
    }
    function syncRows() {
        var out = [];
        var ds = adapter ? adapter.devices.values : [];
        for (var i = 0; i < ds.length; i++) {
            var d = ds[i];
            if (d && BtModel.named(d.name, d.address)) out.push(BtModel.deviceRow(d));
        }
        out = BtModel.sortDeviceRows(out);
        if (JSON.stringify(out) !== JSON.stringify(rows)) rows = out;   // no churn, no reflow
    }
    function setDiscovering(on) { if (adapter && adapter.enabled) adapter.discovering = on; }
    onShownChanged: { setDiscovering(shown); if (shown) syncRows(); }
    Connections {
        target: bt.adapter
        function onEnabledChanged() { bt.setDiscovering(bt.shown && bt.adapter.enabled); bt.syncRows(); }
    }
    Connections {
        target: bt.adapter ? bt.adapter.devices : null
        function onValuesChanged() { bt.syncRows() }
    }
    Connections { target: Sys; function onBtConnectedChanged() { bt.syncRows() } }
    Timer { interval: 2000; repeat: true; running: bt.shown; onTriggered: bt.syncRows() }

    // Click: connected -> disconnect; paired -> trust + connect; else pair (bt-agent in
    // hypr autostart authorizes the bond; afterPair then trusts + connects).
    function tapDevice(row) {
        var d = deviceFor(row.address);
        if (!d) return;
        if (d.connected) { d.disconnect(); return; }
        if (d.paired || d.bonded) { d.trusted = true; d.connect(); }
        else d.pair();
    }
    // Pairing completes asynchronously. Once the bond lands, persist trust (PIN-less
    // devices won't auto-reconnect otherwise) and bring the connection up.
    function afterPair(d) {
        if (d && (d.paired || d.bonded) && !d.connected) { d.trusted = true; d.connect(); }
    }

    DrawerHero {
        glyph: Theme.btGlyph(Sys.btOn, Sys.btConnected)
        glyphColor: Sys.btOn ? Theme.accent : Theme.dim
        title: !bt.adapter ? "Bluetooth unavailable" : (Sys.btOn ? "Bluetooth" : "Bluetooth off")
        status: Sys.btOn && bt.adapter && bt.adapter.discovering ? "Searching..." : ""
        toggleVisible: bt.adapter !== null
        on: Sys.btOn
        onToggled: if (bt.adapter) bt.adapter.enabled = !bt.adapter.enabled
    }

    // ── Device list (named only, scrollable, capped) ─────────────────
    Flickable {
        id: flick
        Layout.fillWidth: true
        visible: Sys.btOn && bt.rows.length > 0
        implicitHeight: Math.min(listcol.implicitHeight, bt.maxListH)
        contentHeight: listcol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Behavior on implicitHeight { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: listcol
            width: flick.width
            spacing: 2

            Repeater {
                model: bt.rows
                delegate: ColumnLayout {
                    id: cell
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 2

                    SectionHeader {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: BtModel.deviceSectionTitle(bt.rows, cell.index)
                    }
                    ListRow {
                        glyph: Theme.btDeviceGlyph(BtModel.deviceGlyphKind(cell.modelData.icon))
                        glyphColor: cell.modelData.connected ? Theme.accent : Theme.text
                        label: cell.modelData.name
                        labelColor: cell.modelData.connected ? Theme.accent : Theme.text
                        detail: BtModel.deviceStatus(cell.modelData)
                        onClicked: bt.tapDevice(cell.modelData)
                        // Auto-trust + connect a device the moment it finishes pairing.
                        Connections {
                            target: bt.deviceFor(cell.modelData.address)
                            function onBondedChanged() { bt.afterPair(target) }
                            function onPairedChanged() { bt.afterPair(target) }
                        }
                    }
                }
            }
        }
    }
    Text {
        visible: Sys.btOn && bt.rows.length === 0
        text: "No devices found"
        color: Theme.dim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
    }
}
