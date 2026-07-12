import QtQuick
import QtQuick.Effects

// A drop shadow cast from a plain silhouette, so only the drawer's SHAPE casts a shadow --
// sourcing a drawer's own content would make its text cast a shadow too (glyph fringing that
// reads as squashed text). Place it as a sibling directly BEHIND the drawer, sized and
// cornered to match: the drawer covers the silhouette exactly, leaving only the blur that
// bleeds past the edges. The parent must not clip, and the drawer's window needs
// Theme.shadowPad of room for the blur to render into.
Item {
    id: root
    property real topLeftRadius:     Theme.radius
    property real topRightRadius:    Theme.radius
    property real bottomLeftRadius:  Theme.radius
    property real bottomRightRadius: Theme.radius
    // Match a card whose corners animate as it is pushed off / pulled up to the bar.
    Behavior on topLeftRadius  { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
    Behavior on topRightRadius { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

    Rectangle {
        id: sil
        anchors.fill: parent
        color: Theme.bar
        topLeftRadius:     root.topLeftRadius
        topRightRadius:    root.topRightRadius
        bottomLeftRadius:  root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        layer.enabled: true             // texture provider the shadow MultiEffect samples
    }
    MultiEffect {
        source: sil
        anchors.fill: sil
        autoPaddingEnabled: true        // let the blur bleed past the silhouette into the window pad
        shadowEnabled: true
        blurMax: 20
        shadowBlur: 1.0
        shadowColor: Theme.shadow
        shadowVerticalOffset: 3
    }
}
