import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// SNI system tray — the "applet" area (Discord, Steam, etc.)
Row {
    id: root
    spacing: Theme.gap

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayDel
            required property var modelData
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 22
            implicitHeight: 22

            IconImage {
                anchors.centerIn: parent
                implicitSize: 18
                source: trayDel.modelData.icon
            }

            // Context menu (SNI). Positioned under the icon at click time.
            QsMenuAnchor {
                id: trayMenu
                menu: trayDel.modelData.menu
                anchor.window: trayDel.QsWindow.window
            }
            function openMenu() {
                if (!trayDel.modelData.hasMenu) return;
                var p = trayDel.mapToItem(null, 0, trayDel.height);
                trayMenu.anchor.rect.x = p.x;
                trayMenu.anchor.rect.y = p.y;
                trayMenu.open();
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        trayDel.openMenu();                          // right-click → menu
                    } else if (mouse.button === Qt.MiddleButton) {
                        trayDel.modelData.secondaryActivate();       // middle → app's secondary action
                    } else if (trayDel.modelData.onlyMenu) {
                        trayDel.openMenu();                          // menu-only apps → open on left-click
                    } else {
                        trayDel.modelData.activate();                // left → primary action
                    }
                }
            }
        }
    }
}
