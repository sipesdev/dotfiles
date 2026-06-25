import QtQuick

// Minimal custom slider (value 0..1) — matte-black styled, no Controls dep.
Item {
    id: s
    property real value: 0
    property color fill: Theme.accent
    signal moved(real v)
    // Exposed so a parent can pause external value polling while the user drags.
    property alias pressed: ma.pressed

    implicitHeight: 18
    implicitWidth: 120
    opacity: enabled ? 1.0 : 0.4        // dim when disabled; Item.enabled also blocks input to children
    // Fade the dim when the slider is enabled/disabled (mute / auto-brightness).
    Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.InOutQuad } }

    readonly property real clamped: Math.max(0, Math.min(1, value))

    Rectangle {                       // track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.elevated

        Rectangle {                   // fill
            width: parent.width * s.clamped
            height: parent.height
            radius: 3
            color: s.fill
            // Glide on a click-to-set or an external change; instant only while
            // actively dragging (so the handle tracks the cursor 1:1, no lag).
            Behavior on width {
                enabled: !ma.dragging
                NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
            }
        }
    }

    Rectangle {                       // handle
        width: 14; height: 14; radius: 7
        color: Theme.bright
        anchors.verticalCenter: parent.verticalCenter
        x: (s.width - width) * s.clamped
        // Glide on a click-to-set or an external change; instant only while
        // actively dragging (so the handle tracks the cursor 1:1, no lag).
        Behavior on x {
            enabled: !ma.dragging
            NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // dragging flips true only once the pointer travels past a small threshold
        // while pressed — i.e. a real drag. A plain click (even with a few px of
        // touchpad jitter) leaves it false, so the press jump glides into place
        // instead of being snapped to the jitter position.
        property bool dragging: false
        property real pressX: 0
        readonly property int dragThreshold: 5
        function setAt(px) {
            // Don't write s.value here — that would clobber the parent's `value:`
            // binding and stop the slider from tracking the real source (brightness/
            // volume). Just emit moved(); the parent updates the source, which the
            // binding reflects back here.
            s.moved(Math.max(0, Math.min(1, px / s.width)));
        }
        onPressed: (m) => { dragging = false; pressX = m.x; setAt(m.x); }
        onPositionChanged: (m) => {
            if (!pressed) return;
            // Ignore sub-threshold jitter so a click still glides; past it, drag 1:1.
            if (!dragging && Math.abs(m.x - pressX) < dragThreshold) return;
            dragging = true;
            setAt(m.x);
        }
        onReleased: dragging = false
        onCanceled: dragging = false
    }
}
