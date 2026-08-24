import QtQuick

// Caps caption introducing a drawer section ("OUTPUT", "KNOWN NETWORKS"), with an optional
// right-aligned detail ("72%") and room for trailing controls. Users set Layout.fillWidth.
Item {
    id: hdr
    property string text: ""
    property string detail: ""
    default property alias trailing: tail.data

    implicitHeight: Math.max(label.implicitHeight, tail.implicitHeight)

    Text {
        id: label
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: hdr.text
        color: Theme.dim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 3
        font.bold: true
        font.letterSpacing: 1.2
        // Nerd Font outlines run ~10% of the em past the ascent; at the top of a clipping
        // list the first header would otherwise render beheaded. Reserve the overshoot.
        topPadding: Math.ceil(font.pixelSize * 0.15)
    }
    Row {
        id: tail
        anchors.right: parent.right
        anchors.verticalCenter: label.verticalCenter
        spacing: Theme.gap
        Text {
            visible: hdr.detail !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: hdr.detail
            color: Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
    }
}
