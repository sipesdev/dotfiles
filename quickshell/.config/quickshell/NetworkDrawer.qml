import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import "NetModel.js" as NetModel
import "ListSync.js" as ListSync

// Network module: connection hero + radio toggle, live stats from network-probe (Omarchy's
// eight: ping, packet loss, receiving, sending, downloaded, uploaded, IP, gateway), Wi-Fi band
// pinning via wifi-band, and the Wi-Fi list split into KNOWN / OTHER networks. Scanning,
// connecting, disconnecting and forgetting go through Quickshell's NetworkManager backend;
// only a secured, unknown network shells out to wifi-connect for its zenity password prompt.
BarDrawer {
    id: net
    contentWidth: 360
    spacing: Theme.pad

    readonly property string home: Quickshell.env("HOME")
    readonly property int maxListH: Math.round((Screen.height > 0 ? Screen.height : 1000) * 0.5)

    onShownChanged: {
        if (Sys.wifiDevice) Sys.wifiDevice.scannerEnabled = shown;   // scan only while open
        if (shown) syncRows();
        else { thru = {}; ping = {}; }                                // next open seeds afresh
    }

    // ── Route / interface stats (network-probe, 1.5 s while open) ────
    property var info: ({})
    property var thru: ({})
    property var ping: ({})
    readonly property bool hasTransferStats: info.rx_bytes !== undefined
    readonly property bool hasPing: (ping.internetSamples || []).length > 0
    Process {
        id: probe
        command: [net.home + "/.local/bin/network-probe"]
        stdout: StdioCollector { onStreamFinished: net.updateDetails(text) }
    }
    Timer {
        interval: 1500; repeat: true; triggeredOnStart: true
        running: net.shown
        onTriggered: if (!probe.running) probe.running = true
    }
    function updateDetails(raw) {
        var next = NetModel.parseKeyValue(raw);
        // Mid-reassociation (band pin) there is no route for a beat: keep the last sample
        // rather than blanking the grid.
        if (bandBusy && !next.iface) return;
        info = next;
        thru = NetModel.throughputState(thru, next, Date.now() / 1000);
        ping = NetModel.pingState(ping, next, 24, 5);
    }

    // ── Wi-Fi band (wifi-band, 4 s while open and connected) ─────────
    property string bandCurrent: ""
    property string bandSelected: "auto"
    property var bandAvailable: []
    property string pendingBand: ""
    readonly property bool bandBusy: pendingBand !== ""
    readonly property string bandEffective: bandBusy ? pendingBand : bandSelected
    readonly property bool bandPinned: bandEffective !== "auto"
    // Only on Wi-Fi, and only when the network answers on more than one band (or a pin is
    // in force): a single-band AP has nothing to toggle.
    readonly property bool canSelectBand: (Sys.wifiConnected || bandBusy) && (bandAvailable.length > 1 || bandPinned)
    readonly property bool bandPillsVisible: canSelectBand && bandPinned
    Process {
        id: bandRead
        command: [net.home + "/.local/bin/wifi-band"]
        stdout: StdioCollector { onStreamFinished: net.updateBand(text) }
    }
    Timer {
        interval: 4000; repeat: true; triggeredOnStart: true
        running: net.shown && Sys.wifiConnected
        onTriggered: if (!bandRead.running) bandRead.running = true
    }
    function updateBand(raw) {
        var s = NetModel.parseBandStatus(raw);
        if (bandBusy && s.available.length === 0) return;   // mid-reconnect: nothing to show yet
        bandCurrent = s.band; bandSelected = s.selected; bandAvailable = s.available;
    }
    Process {
        id: bandSet
        onExited: (code) => {
            if (code === 0) net.bandSelected = net.pendingBand;
            net.pendingBand = "";
            bandRead.running = true;
        }
    }
    function setBand(b) {
        if (!b || bandSet.running) return;
        pendingBand = b;
        bandSet.command = [net.home + "/.local/bin/wifi-band", b];
        bandSet.running = true;
    }
    function toggleBandAuto() {
        if (bandSelected !== "auto") setBand("auto");
        else if (bandCurrent !== "") setBand(bandCurrent);   // pin to the band in use
    }

    // ── Wi-Fi list ───────────────────────────────────────────────────
    ListModel { id: rowModel }   // updated in place by syncRows, so hovered rows survive a rescan
    function networkForSsid(ssid) {
        var nets = Sys.wifiDevice && Sys.wifiDevice.networks ? Sys.wifiDevice.networks.values : [];
        for (var i = 0; i < nets.length; i++) if (nets[i] && nets[i].name === ssid) return nets[i];
        return null;
    }
    function syncRows() {
        var out = [];
        var nets = Sys.wifiDevice && Sys.wifiDevice.networks ? Sys.wifiDevice.networks.values : [];
        for (var i = 0; i < nets.length; i++) {
            var n = nets[i];
            if (!n || !n.name) continue;
            checkActionCompletion(n);
            out.push(NetModel.wifiRow(n));
        }
        out = NetModel.sortWifiRows(out);
        for (var k = 0; k < out.length; k++) out[k].header = NetModel.wifiSectionTitle(out, k);
        ListSync.sync(rowModel, out, "ssid");
    }
    Connections {
        target: Sys.wifiDevice ? Sys.wifiDevice.networks : null
        function onValuesChanged() { net.syncRows() }
    }
    Timer { interval: 3000; repeat: true; running: net.shown; onTriggered: net.syncRows() }

    // One action at a time, with a safety-net timeout so a row can't stay "Connecting..."
    // forever (30 s outlasts NetworkManager's 25 s supplicant timeout).
    property string actionSsid: ""
    property string actionKind: ""
    property string failureSsid: ""
    property string failureReason: ""
    readonly property bool busy: actionKind !== ""
    readonly property var failReasons: ({
        NoSecrets: ConnectionFailReason.NoSecrets,
        WifiAuthTimeout: ConnectionFailReason.WifiAuthTimeout,
        WifiNetworkLost: ConnectionFailReason.WifiNetworkLost,
        WifiClientDisconnected: ConnectionFailReason.WifiClientDisconnected,
        WifiClientFailed: ConnectionFailReason.WifiClientFailed
    })
    function requiresCredentials(sec) {
        return NetModel.requiresCredentials(sec, WifiSecurityType.Open, WifiSecurityType.Owe);
    }
    Timer {
        id: actionTimeout
        interval: 30000
        onTriggered: {
            if (!net.actionKind) return;
            net.failureSsid = net.actionSsid; net.failureReason = "Timed out";
            net.actionSsid = ""; net.actionKind = "";
            net.syncRows();
        }
    }
    function runAction(kind, network, fn) {
        if (busy || !network) return;
        actionSsid = network.name; actionKind = kind;
        failureSsid = ""; failureReason = "";
        fn(network);
        actionTimeout.restart();
    }
    function clearAction() {
        actionTimeout.stop();
        actionSsid = ""; actionKind = ""; failureSsid = ""; failureReason = "";
        syncRows();
    }
    function failAction(network, reason) {
        if (!network || !actionKind || actionSsid !== network.name) return;
        actionTimeout.stop();
        failureSsid = actionSsid;
        failureReason = NetModel.failureText(reason, requiresCredentials(network.security), failReasons);
        actionSsid = ""; actionKind = "";
        syncRows();
    }
    function checkActionCompletion(n) {
        if (!n || !actionKind || actionSsid !== n.name) return;
        if (actionKind === "connect" && n.connected) clearAction();
        else if (actionKind === "disconnect" && !n.connected && !n.stateChanging) clearAction();
        else if (actionKind === "forget" && !n.known && !n.stateChanging) clearAction();
    }
    // Secured, unknown networks go through wifi-connect (zenity password prompt, then nmcli).
    // When the prompt is cancelled the script exits without connecting: drop the busy state.
    Process {
        id: connectScript
        onExited: {
            if (net.actionKind === "connect") {
                var n = net.networkForSsid(net.actionSsid);
                if (!n || !n.connected) net.clearAction();
            }
            net.syncRows();
        }
    }
    function tapRow(row) {
        if (busy) return;
        var n = networkForSsid(row.ssid);
        if (!n) return;
        if (row.connected) { runAction("disconnect", n, function (x) { x.disconnect(); }); return; }
        if (row.known || !requiresCredentials(row.security)) {
            runAction("connect", n, function (x) { x.connect(); });
            return;
        }
        runAction("connect", n, function (x) {
            connectScript.command = [net.home + "/.local/bin/wifi-connect", x.name, "1"];
            connectScript.running = true;
        });
    }
    function forgetRow(row) {
        var n = networkForSsid(row.ssid);
        if (n && NetModel.canForget(row)) runAction("forget", n, function (x) { x.forget(); });
    }

    // ── Hero ─────────────────────────────────────────────────────────
    DrawerHero {
        glyph: Sys.ethernetConnected ? Theme.iEthernet
             : Theme.wifiGlyph(Sys.wifiEnabled, Sys.wifiConnected, Sys.wifiStrength)
        glyphColor: (Sys.ethernetConnected || Sys.wifiConnected) ? Theme.accent : Theme.text
        title: Sys.ethernetConnected ? "Ethernet"
             : Sys.wifiConnected ? Sys.wifiSsid
             : Sys.wifiEnabled ? "Wi-Fi" : "Wi-Fi off"
        status: Sys.ethernetConnected ? (Sys.ethernetName
                    + (Sys.wiredDevice && Sys.wiredDevice.linkSpeed > 0
                       ? "  " + NetModel.formatLinkSpeed(Sys.wiredDevice.linkSpeed) : ""))
              : Sys.wifiConnected ? "Connected"
              : Sys.wifiEnabled ? "Not connected" : ""
        toggleVisible: Sys.wifiDevice !== null
        on: Sys.wifiEnabled
        onToggled: Sys.setWifiRadio(!Sys.wifiEnabled)
    }

    // ── Stats grid (hidden without a route; rows read "--" until the first sample) ──
    GridLayout {
        Layout.fillWidth: true
        visible: !!net.info.iface
        columns: 4
        columnSpacing: Theme.pad
        rowSpacing: 4

        StatLabel { text: "Ping" }
        StatValue {
            text: NetModel.formatPing(net.ping.internetLatency, net.hasPing)
            color: net.ping.packetLoss > 0 ? Theme.danger : Theme.text
        }
        StatLabel { text: "Packet loss" }
        StatValue {
            text: NetModel.formatPacketLoss(net.ping.packetLoss, net.hasPing)
            color: net.ping.packetLoss > 0 ? Theme.danger : Theme.text
        }
        StatLabel { text: "Receiving" }
        StatValue { text: net.hasTransferStats ? NetModel.formatRate(net.thru.downloadRate) : "--" }
        StatLabel { text: "Sending" }
        StatValue { text: net.hasTransferStats ? NetModel.formatRate(net.thru.uploadRate) : "--" }
        StatLabel { text: "Downloaded" }
        StatValue { text: net.hasTransferStats ? NetModel.formatBytes(parseFloat(net.info.rx_bytes || "0")) : "--" }
        StatLabel { text: "Uploaded" }
        StatValue { text: net.hasTransferStats ? NetModel.formatBytes(parseFloat(net.info.tx_bytes || "0")) : "--" }
        StatLabel { text: "IP address" }
        StatValue { text: net.info.ip || "--"; copyable: !!net.info.ip }
        StatLabel { text: "Gateway" }
        StatValue { text: net.info.gateway || "--"; copyable: !!net.info.gateway }
    }

    // ── Wi-Fi: band + network list ───────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        visible: Sys.wifiDevice !== null && Sys.wifiEnabled
        spacing: 4

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.elevated; visible: net.canSelectBand }
        SectionHeader {
            Layout.fillWidth: true
            visible: net.canSelectBand
            text: NetModel.bandTitle(net.bandEffective, net.bandCurrent)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "AUTOMATIC"
                color: Theme.dim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
                font.bold: true
                font.letterSpacing: 1.2
            }
            TogglePill {
                anchors.verticalCenter: parent.verticalCenter
                width: 34; height: 18
                on: !net.bandPinned
                enabled: !net.bandBusy
                onToggled: net.toggleBandAuto()
            }
        }
        // Collapsing pill row: animates its height so toggling Automatic slides the list
        // into place instead of snapping; `visible` only drops at a real zero.
        Item {
            Layout.fillWidth: true
            clip: true
            visible: height > 0
            implicitHeight: net.bandPillsVisible ? pillRow.implicitHeight : 0
            opacity: net.bandPillsVisible ? 1 : 0
            Behavior on implicitHeight { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
            RowLayout {
                id: pillRow
                width: parent.width
                spacing: Theme.gap
                Repeater {
                    model: net.bandAvailable
                    delegate: Pill {
                        required property var modelData
                        label: modelData + " GHz"
                        active: net.bandEffective === modelData
                        onClicked: net.setBand(modelData)
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.elevated }
        Flickable {
            id: flick
            Layout.fillWidth: true
            visible: rowModel.count > 0
            implicitHeight: Math.min(listcol.implicitHeight, net.maxListH)
            contentHeight: listcol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Behavior on implicitHeight { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: listcol
                width: flick.width
                spacing: 2
                Repeater {
                    model: rowModel
                    delegate: ColumnLayout {
                        id: cell
                        required property var model
                        Layout.fillWidth: true
                        spacing: 2
                        SectionHeader {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: cell.model.header
                        }
                        WifiRow { row: cell.model }
                    }
                }
            }
        }
        Text {
            visible: rowModel.count === 0
            text: "Searching..."
            color: Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
    }

    component StatLabel: Text {
        color: Theme.dim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
    }
    component StatValue: Text {
        property bool copyable: false
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        MouseArea {                   // click-to-copy for IP / gateway
            anchors.fill: parent
            enabled: parent.copyable
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: Quickshell.execDetached(["wl-copy", parent.text])
        }
    }

    // One network. Rows are primitive snapshots (NetModel.wifiRow); the live object is
    // resolved by SSID for signals and actions. Click: connected -> disconnect, known or open
    // -> connect, secured unknown -> wifi-connect prompt. Hover a known, idle row for the
    // forget "x" at the right edge (the lock glyph otherwise marks secured networks).
    component WifiRow: Rectangle {
        id: wrow
        required property var row
        readonly property var network: net.networkForSsid(row.ssid)
        readonly property bool secured: net.requiresCredentials(row.security)
        readonly property bool canForget: NetModel.canForget(row)
        readonly property bool isBusy: net.actionKind !== "" && net.actionSsid === row.ssid
        readonly property bool isFailed: net.failureReason !== "" && net.failureSsid === row.ssid
        readonly property string status: isBusy
              ? ({ connect: "Connecting...", disconnect: "Disconnecting...", forget: "Forgetting..." })[net.actionKind]
              : isFailed ? net.failureReason
              : row.connected ? "Connected" : ""

        Layout.fillWidth: true
        implicitHeight: 30
        radius: Theme.radius
        color: rowMa.containsMouse ? Theme.elevated : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Connections {
            target: wrow.network
            function onConnectionFailed(reason) { net.failAction(wrow.network, reason) }
            function onConnectedChanged() { net.checkActionCompletion(wrow.network) }
            function onKnownChanged() { net.checkActionCompletion(wrow.network) }
            function onStateChangingChanged() { net.checkActionCompletion(wrow.network) }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 8
            spacing: 6
            Text {
                Layout.preferredWidth: 22
                horizontalAlignment: Text.AlignHCenter
                text: Theme.wifiGlyph(true, true, wrow.row.signal)
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
            }
            Text {
                Layout.fillWidth: true
                text: wrow.row.ssid
                elide: Text.ElideRight
                color: wrow.row.connected ? Theme.accent : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
            Text {
                visible: wrow.status !== ""
                text: wrow.status
                color: wrow.isFailed ? Theme.danger : Theme.dim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
            Item {
                Layout.preferredWidth: 22
                Layout.fillHeight: true
                visible: wrow.secured || wrow.canForget
                Text {
                    anchors.centerIn: parent
                    visible: wrow.secured || rightMa.containsMouse
                    text: (wrow.canForget && rightMa.containsMouse) ? Theme.iForget : Theme.iLock
                    color: (wrow.canForget && rightMa.containsMouse) ? Theme.danger : Theme.dim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
                MouseArea {
                    id: rightMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: wrow.canForget && !net.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: net.forgetRow(wrow.row)
                }
            }
        }
        MouseArea {
            id: rowMa
            anchors.fill: parent
            anchors.rightMargin: 30
            hoverEnabled: true
            enabled: !net.busy
            cursorShape: Qt.PointingHandCursor
            onClicked: net.tapRow(wrow.row)
        }
    }
}
