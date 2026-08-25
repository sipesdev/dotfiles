import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "BtModel.js" as BtModel
import "ListSync.js" as ListSync

// Bluetooth module, modelled on Omarchy's bluetooth panel: a hero with the radio switch and
// "Searching..." while the scan runs; CONNECTED rows above a capped, scrollable list of PAIRED
// then AVAILABLE devices (AVAILABLE only while BlueZ reports discovery); one-line rows with a
// live status (Connecting… / Disconnecting… / Forgetting… / battery %) and a forget button on
// hover for remembered devices; connecting an audio device makes it the default output once its
// Pipewire node appears. Rows are primitive snapshots (BtModel.deviceRow): BlueZ churn can destroy
// a device while a delegate is still incubating, so actions re-resolve it by address. Power and
// discovery are owned by Sys (rfkill soft block; one scan shared across monitors).
BarDrawer {
    id: bt
    contentWidth: 340
    spacing: Theme.pad

    readonly property var adapter: Sys.btAdapter
    readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property int maxListH: Math.round((Screen.height > 0 ? Screen.height : 1000) * 0.4)
    readonly property var states: ({ Disconnecting: BluetoothDeviceState.Disconnecting, Connecting: BluetoothDeviceState.Connecting })

    onShownChanged: Sys.btDrawersOpen += shown ? 1 : -1
    Component.onDestruction: if (shown) Sys.btDrawersOpen -= 1

    // ── Grouping. deviceLists reads every property it sorts on, so these re-evaluate on any
    //    connect / pair / rename; the rows also read state, battery and pairing. ──
    readonly property var groups: BtModel.deviceLists(devices)
    readonly property bool showDiscovered: adapter !== null && adapter.discovering
    readonly property var connectedRows: groups.connected.map(function (d) {
        var r = BtModel.deviceRow(d, "connected"); r.header = ""; r.divider = false; return r;
    })
    readonly property var scrollRows: {
        var rows = groups.known.map(function (d) { return BtModel.deviceRow(d, "known"); });
        if (showDiscovered) rows = rows.concat(groups.discovered.map(function (d) { return BtModel.deviceRow(d, "discovered"); }));
        for (var i = 0; i < rows.length; i++) {
            rows[i].header = BtModel.scrollSectionTitle(rows, i);
            rows[i].divider = i > 0 && rows[i].header !== "";
        }
        return rows;
    }
    // ListModels updated in place from the bindings above, so a hovered row survives a refresh.
    ListModel { id: connectedModel }
    ListModel { id: scrollModel }
    onConnectedRowsChanged: ListSync.sync(connectedModel, connectedRows, "address")
    onScrollRowsChanged: ListSync.sync(scrollModel, scrollRows, "address")
    Component.onCompleted: { ListSync.sync(connectedModel, connectedRows, "address"); ListSync.sync(scrollModel, scrollRows, "address"); }
    readonly property bool empty: connectedRows.length === 0 && scrollRows.length === 0
    function deviceFor(address) {
        for (var i = 0; i < devices.length; i++) if (devices[i] && devices[i].address === address) return devices[i];
        return null;
    }

    // ── Pending actions: address -> "powering" | "pairing" | "connecting" | "disconnecting" |
    //    "forgetting". Kept here, not on the row, so it survives a row moving between sections;
    //    cleared when BlueZ confirms, or wholesale by the 20 s bail-out (which outlasts BlueZ's
    //    own pairing and connect timeouts). ──
    property var pending: ({})
    function setPending(address, action) {
        pending = BtModel.withPendingAction(pending, address, action);
        if (action) pendingTimeout.restart();
    }
    Timer { id: pendingTimeout; interval: 20000; onTriggered: bt.pending = ({}) }
    onGroupsChanged: syncPending()
    Connections { target: bt.adapter; function onEnabledChanged() { bt.syncPending() } }

    // Advance each in-flight action against the live device -- Omarchy's sequencing:
    // powering -> (adapter up) -> pair or connect; pairing -> (bonded) -> trust + connect;
    // connecting -> connected; disconnecting -> disconnected; forgetting -> gone or unpaired.
    function syncPending() {
        var next = BtModel.cloneMap(pending), changed = false;
        for (var address in next) {
            var action = next[address], d = deviceFor(address), done = false;
            if (action === "powering" && Sys.btOn && d) {
                if (d.paired || d.bonded || d.trusted) { d.trusted = true; d.connect(); next[address] = "connecting"; }
                else { d.pair(); next[address] = "pairing"; }
                changed = true;
            } else if (action === "pairing" && d && (d.paired || d.bonded) && !d.pairing) {
                d.trusted = true; d.connect(); next[address] = "connecting"; changed = true;
            } else if ((action === "connecting" || action === "pairing") && d && d.connected) {
                scheduleAudioSwitch(d); done = true;
            } else if (action === "disconnecting" && d && !d.connected) {
                done = true;
            } else if (action === "forgetting" && (!d || !(d.paired || d.bonded || d.trusted))) {
                done = true;
            }
            if (done) { delete next[address]; changed = true; }
        }
        if (changed) pending = next;
    }
    function connectDevice(row) {
        var d = deviceFor(row.address);
        if (!d || d.connected) return;
        if (!Sys.btOn) { setPending(row.address, "powering"); Sys.setBluetoothPower(true); return; }   // connecting turns the radio on
        if (d.paired || d.bonded || d.trusted) { d.trusted = true; d.connect(); setPending(row.address, "connecting"); }
        else { d.pair(); setPending(row.address, "pairing"); }   // bt-agent (hypr autostart) authorizes the bond
    }
    function disconnectDevice(row) {
        var d = deviceFor(row.address);
        if (!d || !d.connected) return;
        d.disconnect();
        setPending(row.address, "disconnecting");
    }
    function forgetDevice(row) {
        var d = deviceFor(row.address);
        if (!d) return;
        d.forget();                                    // BlueZ RemoveDevice disconnects first
        setPending(row.address, "forgetting");
    }

    // ── The default output follows a freshly connected device: poll for its sink, up to ~4 s ──
    property var audioTarget: null
    property int audioAttempts: 0
    function scheduleAudioSwitch(d) {
        audioTarget = { address: d.address || "", label: BtModel.deviceLabel(d) };   // snapshot, never the object
        audioAttempts = 0;
        audioSwitch.restart();
    }
    Timer {
        id: audioSwitch
        interval: 500
        onTriggered: {
            if (!bt.audioTarget) return;
            var nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
            for (var i = 0; i < nodes.length; i++) {
                if (BtModel.bluetoothSinkMatchesDevice(nodes[i], bt.audioTarget)) {
                    Pipewire.preferredDefaultAudioSink = nodes[i];
                    bt.audioTarget = null;
                    return;
                }
            }
            bt.audioAttempts += 1;
            if (bt.audioAttempts < 8) audioSwitch.restart(); else bt.audioTarget = null;
        }
    }

    // ── Hero: glyph, "Bluetooth", scan status, the radio switch ──
    DrawerHero {
        glyph: Theme.btGlyph(Sys.btOn, Sys.btConnected)
        glyphColor: Sys.btOn ? Theme.accent : Theme.dim
        title: "Bluetooth"
        status: !bt.adapter ? "No adapter" : (!Sys.btOn ? "Turned off" : (bt.adapter.discovering ? "Searching..." : ""))
        toggleVisible: bt.adapter !== null
        on: Sys.btOn
        onToggled: Sys.setBluetoothPower(!Sys.btOn)
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.elevated }

    // ── CONNECTED: above the scroll area, never clipped ──
    ColumnLayout {
        Layout.fillWidth: true
        visible: bt.connectedRows.length > 0
        spacing: 2
        SectionHeader { Layout.fillWidth: true; text: "CONNECTED" }
        Repeater {
            model: connectedModel
            delegate: BtRow { required property var model; row: model }
        }
    }
    Rectangle {
        Layout.fillWidth: true; height: 1; color: Theme.elevated
        visible: bt.connectedRows.length > 0 && bt.scrollRows.length > 0
    }

    // ── PAIRED then AVAILABLE, scrollable and capped ──
    Flickable {
        id: flick
        Layout.fillWidth: true
        visible: bt.scrollRows.length > 0
        implicitHeight: Math.min(listcol.implicitHeight, bt.maxListH)
        contentHeight: listcol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        Behavior on implicitHeight { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: listcol
            width: flick.width
            spacing: 2
            Repeater {
                model: scrollModel
                delegate: ColumnLayout {
                    id: cell
                    required property var model
                    Layout.fillWidth: true
                    spacing: 2
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.elevated; visible: cell.model.divider }
                    SectionHeader { Layout.fillWidth: true; visible: cell.model.header !== ""; text: cell.model.header }
                    BtRow { row: cell.model }
                }
            }
        }
    }

    Text {
        visible: bt.empty
        text: !bt.adapter ? "No Bluetooth adapter" : (Sys.btOn ? "Scanning for devices…" : "Turn Bluetooth on to scan")
        color: Theme.dim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
    }

    // One device. Left click: connected -> disconnect, remembered -> connect, discovered -> pair.
    // Right click: connected -> disconnect, remembered -> forget, discovered -> nothing. The
    // forget button appears on hover for remembered rows only.
    component BtRow: Rectangle {
        id: brow
        required property var row
        readonly property string action: BtModel.pendingAction(bt.pending, row.address)
        readonly property string status: BtModel.statusText(row, action, bt.states)
        readonly property bool strong: BtModel.statusStrong(row, action, bt.states)
        readonly property bool remembered: row.section === "known" || row.section === "connected"

        Layout.fillWidth: true
        implicitHeight: 30
        radius: Theme.radius
        color: (rowMa.containsMouse || forgetMa.containsMouse) ? Theme.elevated : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 8
            spacing: 6
            Text {
                Layout.preferredWidth: 22
                horizontalAlignment: Text.AlignHCenter
                text: Theme.btGlyph(true, brow.row.connected)
                color: brow.row.connected ? Theme.accent : (brow.strong ? Theme.text : Theme.dim)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
            }
            Text {
                Layout.fillWidth: true
                text: brow.row.label
                elide: Text.ElideRight
                color: brow.row.connected ? Theme.accent : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
            Text {
                visible: brow.status !== ""
                text: brow.status
                color: brow.strong ? Theme.text : Theme.dim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
            Item {
                Layout.preferredWidth: 22
                Layout.fillHeight: true
                visible: brow.remembered && (rowMa.containsMouse || forgetMa.containsMouse)
                Text {
                    anchors.centerIn: parent
                    text: Theme.iForget
                    color: forgetMa.containsMouse ? Theme.danger : Theme.dim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
                MouseArea {
                    id: forgetMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bt.forgetDevice(brow.row)
                }
            }
        }
        MouseArea {
            id: rowMa
            anchors.fill: parent
            anchors.rightMargin: brow.remembered ? 30 : 0
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    if (brow.row.connected) bt.disconnectDevice(brow.row);
                    else if (brow.remembered) bt.forgetDevice(brow.row);
                    return;
                }
                if (brow.row.connected) bt.disconnectDevice(brow.row);
                else bt.connectDevice(brow.row);
            }
        }
    }
}
