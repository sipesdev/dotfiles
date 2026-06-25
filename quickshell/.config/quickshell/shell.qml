//@ pragma UseQApplication
// QApplication mode is required for native SNI tray context menus (QsMenuAnchor).
import Quickshell
import QtQuick

ShellRoot {
    // One bar per connected monitor (reactive add/remove).
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }
}
