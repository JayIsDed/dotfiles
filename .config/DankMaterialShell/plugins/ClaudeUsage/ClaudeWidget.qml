// ClaudeWidget.qml — lilypad's claude 5h/7d meter as a dms plugin.
// Probe: claude-usage relay on 111 (3min, ssh BatchMode). Fable draws the
// shared weekly capped at 50% — the popout marks that ceiling.
// Pattern per DvmTile: pill Component is CONTENT inside BasePill; size by
// implicitWidth, no own chrome.
import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property real cu5: -1
    property real cu7: -1
    readonly property bool alive: cu5 >= 0

    function probe() {
        Proc.runCommand("claudeUsage.probe",
            ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", "claude-dev",
             "/home/jay/.local/bin/claude-usage"],
            (stdout, exitCode) => {
                if (exitCode !== 0) {
                    root.cu5 = -1
                    root.cu7 = -1
                    return
                }
                try {
                    const j = JSON.parse(stdout)
                    root.cu5 = j.five ? j.five.pct : -1
                    root.cu7 = j.seven ? j.seven.pct : -1
                } catch (e) {
                    root.cu5 = -1
                    root.cu7 = -1
                }
            }, 0, 15000)
    }

    Timer {
        interval: 180000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.probe()
    }

    // lilypad grammar: 5h/7d labels | bars (7d carries the 50% fable tick) | numbers
    horizontalBarPill: Component {
        Item {
            implicitWidth: cuRow.implicitWidth
            implicitHeight: cuRow.implicitHeight

            Row {
                id: cuRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "smart_toy"
                    size: root.iconSize
                    color: root.cu5 >= 80 ? Theme.tempDanger : root.cu5 >= 60 ? Theme.tempWarning : Theme.widgetIconColor
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    spacing: 1
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.alive
                    StyledText { text: "5h"; color: Theme.surfaceVariantText; font.pixelSize: 8 }
                    StyledText { text: "7d"; color: Theme.surfaceVariantText; font.pixelSize: 8 }
                }
                Column {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.alive
                    MeterBar {
                        value: root.cu5; implicitWidth: 44
                        fillColor: root.cu5 >= 85 ? "#ef4444" : root.cu5 >= 70 ? "#fbbf24" : Theme.primary
                    }
                    MeterBar {
                        value: root.cu7; marker: 50; implicitWidth: 44
                        fillColor: root.cu7 >= 85 ? "#ef4444" : root.cu7 >= 70 ? "#fbbf24" : Theme.secondary
                    }
                }
                Column {
                    spacing: 1
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.alive
                    StyledText { text: Math.round(root.cu5) + "%"; color: Theme.widgetTextColor; font.pixelSize: 8; horizontalAlignment: Text.AlignRight; width: 22 }
                    StyledText { text: Math.round(root.cu7) + "%"; color: Theme.widgetTextColor; font.pixelSize: 8; horizontalAlignment: Text.AlignRight; width: 22 }
                }
                StyledText {
                    visible: !root.alive
                    text: "…"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "claude usage"
            detailsText: "via 111 relay · fable ceiling = 50% of weekly"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingS

                Row {
                    spacing: Theme.spacingS
                    StyledText { text: "5h"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 34; anchors.verticalCenter: parent.verticalCenter }
                    MeterBar {
                        value: root.cu5; implicitWidth: 190; implicitHeight: 6
                        fillColor: root.cu5 >= 85 ? "#ef4444" : root.cu5 >= 70 ? "#fbbf24" : Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText { text: root.alive ? Math.round(root.cu5) + "%" : "—"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; width: 44; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    spacing: Theme.spacingS
                    StyledText { text: "7d"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 34; anchors.verticalCenter: parent.verticalCenter }
                    MeterBar {
                        value: root.cu7; marker: 50; implicitWidth: 190; implicitHeight: 6
                        fillColor: root.cu7 >= 85 ? "#ef4444" : root.cu7 >= 70 ? "#fbbf24" : Theme.secondary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText { text: root.cu7 >= 0 ? Math.round(root.cu7) + "%" : "—"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; width: 44; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                }
                StyledText {
                    text: (root.cu7 >= 50 ? "past" : "under") + " the fable ceiling (tick = 50%) · 3min relay"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }
    popoutWidth: 320
    popoutHeight: 200

    // headless popout toggle: qs -c dms ipc call popout-claude toggle
    IpcHandler {
        target: "popout-claude"
        function toggle(): string { root.triggerPopout(); return "ok" }
    }
}
