//@ pragma UseQApplication
// QApplication mode is required for native SNI tray context menus (QsMenuAnchor).
import Quickshell
import QtQuick

ShellRoot {
    // The launcher is per-session, not per-screen: one window that moves to the focused monitor
    // each time it opens, so it sits beside the Variants rather than inside it.
    LauncherWindow {}

    // One bar per connected monitor (reactive add/remove).
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }
}
