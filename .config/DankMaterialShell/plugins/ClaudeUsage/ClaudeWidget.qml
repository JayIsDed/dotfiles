// ClaudeWidget.qml — lilypad's claude 5h/7d meter as a dms plugin.
// Probe: claude-usage relay on 111 (3min, ssh BatchMode). Fable draws the
// shared weekly capped at 50% — the popout marks that ceiling.
// Pattern per DvmTile: pill Component is CONTENT inside BasePill; size by
// implicitWidth, no own chrome.
import QtQuick
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
                StyledText {
                    text: root.alive
                        ? Math.round(root.cu5) + "% " + Math.round(root.cu7) + "%"
                        : "…"
                    color: Theme.widgetTextColor
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
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
                spacing: Theme.spacingM

                StyledText {
                    text: "5h window   " + (root.alive ? Math.round(root.cu5) + "%" : "—")
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                }
                StyledText {
                    text: "7d window   " + (root.cu7 >= 0 ? Math.round(root.cu7) + "%" : "—")
                    color: root.cu7 >= 50 ? Theme.tempDanger : Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                }
                StyledText {
                    text: root.cu7 >= 50 ? "past the fable ceiling" : "under the fable ceiling"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }
    popoutWidth: 320
    popoutHeight: 200
}
