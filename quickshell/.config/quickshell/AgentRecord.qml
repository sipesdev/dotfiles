import QtQuick
import Quickshell.Io
import "AgentModel.js" as AgentModel

// One watched usage record (~/.local/state/agents/usage/<id>.json). Sys builds
// one per discovered id; `record` is the parsed JSON, or null while the file is
// missing or unparseable. FileView watches the file, but agent-usage-update
// replaces it via mktemp+mv, so Sys also calls reload() after every update run
// in case the inode watch misses the swap.
Item {
    id: root
    visible: false
    property string agentId: ""
    property string path: ""
    property var record: null

    function reload() { view.reload() }

    FileView {
        id: view
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: view.reload()
        onLoaded: root.record = AgentModel.parseRecord(view.text())
        onLoadFailed: root.record = null
    }
}
