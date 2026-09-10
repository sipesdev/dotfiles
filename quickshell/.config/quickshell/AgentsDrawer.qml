import QtQuick
import QtQuick.Layouts
import "AgentModel.js" as AgentModel

// Coding-agent usage: plan/tier, rate-limit meters with reset countdowns,
// tokens by day and by model. One section stack per provider; provider pills
// appear only when more than one agent reports ready. Sys owns the records and
// the poller -- this drawer renders Sys.agentRecords and asks for a limits
// refresh on open. Repeaters iterate fresh JS arrays: no interactive rows to
// protect, so ListSync is not needed here.
BarDrawer {
    id: agents
    contentWidth: 340

    readonly property var providers: AgentModel.readyProviders(Sys.agentRecords)
    property string selectedId: ""
    readonly property var provider: {
        for (var i = 0; i < providers.length; i++)
            if (providers[i].id === selectedId) return providers[i];
        return providers.length > 0 ? providers[0] : null;
    }

    // Clock behind the "Resets in ..." countdowns; ticks only while open. triggeredOnStart
    // refreshes it on every open: without it the first tick is 30 s in, and a shorter peek
    // renders the countdown against the previous tick (or quickshell's start time).
    property real nowMs: Date.now()
    Timer {
        interval: 30000; repeat: true; triggeredOnStart: true
        running: agents.shown
        onTriggered: agents.nowMs = Date.now()
    }

    onShownChanged: if (shown) Sys.refreshAgentLimits()

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        DrawerHero {
            glyph: Theme.iRobot
            glyphColor: AgentModel.anyLimitHot([agents.provider]) ? Theme.accent : Theme.text
            title: agents.provider ? (agents.provider.name || agents.provider.id) : "Agents"
            status: agents.provider ? AgentModel.heroStatus(agents.provider) : ""
        }
        // Force a full refresh (Sys no-ops while an update is already running).
        BarIcon {
            glyph: Theme.iRefresh
            glyphColor: Sys.agentUsageBusy ? Theme.dim : Theme.text
            onClicked: Sys.forceAgentRefresh()
        }
    }

    RowLayout {
        visible: agents.providers.length > 1
        Layout.fillWidth: true
        spacing: Theme.gap
        Repeater {
            model: agents.providers
            Pill {
                label: modelData.name || modelData.id
                active: agents.provider !== null && modelData.id === agents.provider.id
                onClicked: agents.selectedId = modelData.id
            }
        }
    }

    SectionHeader { visible: limitRep.count > 0; Layout.fillWidth: true; text: "LIMITS" }
    Repeater {
        id: limitRep
        model: agents.provider ? AgentModel.limitRows(agents.provider) : []
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: modelData.label
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
                Text {
                    text: modelData.percentText
                    color: modelData.hot ? Theme.accent : Theme.dim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 5
                radius: 2
                color: Theme.elevated
                Rectangle {
                    width: parent.width * modelData.percent
                    height: parent.height
                    radius: parent.radius
                    color: modelData.hot ? Theme.accent : Theme.text
                }
            }
            Text {
                visible: text !== ""
                text: AgentModel.resetText(modelData.resetsAt, agents.nowMs)
                color: Theme.dim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
            }
        }
    }

    SectionHeader {
        Layout.fillWidth: true
        text: "TOKENS - 7 DAYS"
        detail: agents.provider ? AgentModel.promptsToday(agents.provider) : ""
    }
    Repeater {
        model: agents.provider ? AgentModel.weekRows(agents.provider, "") : []
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            Text {
                Layout.preferredWidth: 44
                text: modelData.label
                color: modelData.isToday ? Theme.text : Theme.dim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
                font.bold: modelData.isToday
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 5
                radius: 2
                color: Theme.elevated
                Rectangle {
                    width: parent.width * modelData.ratio
                    height: parent.height
                    radius: parent.radius
                    color: modelData.isToday ? Theme.accent : Theme.text
                }
            }
            Text {
                Layout.preferredWidth: 52
                horizontalAlignment: Text.AlignRight
                text: AgentModel.formatTokenCount(modelData.tokens)
                color: Theme.dim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }

    SectionHeader { visible: modelRep.count > 0; Layout.fillWidth: true; text: "BY MODEL" }
    Repeater {
        id: modelRep
        model: agents.provider ? AgentModel.modelRows(agents.provider) : []
        ListRow {
            label: modelData.name
            trailing: AgentModel.formatTokenCount(modelData.total)
        }
    }

    // Auth problems / probe failures surface here, only when something is wrong.
    Text {
        visible: text !== ""
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: agents.provider ? AgentModel.statusLine(agents.provider) : ""
        color: Theme.dim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
    }
}
