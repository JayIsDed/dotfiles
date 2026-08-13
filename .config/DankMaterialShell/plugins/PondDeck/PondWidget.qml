// PondWidget.qml — the printer fleet on the desktop. One row per active
// printer: state dot, name, then job+progress when printing / quiet state
// text otherwise. Data rides `ssh claude-dev pond-glance` (Bambuddy key
// stays on 111). 30s cadence.
import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property var pluginService: null
    property string pluginId: ""
    property bool editMode: false
    property real widgetWidth: 320
    property real widgetHeight: 190
    property real minWidth: 260
    property real minHeight: 150

    property var fleet: []
    readonly property bool alive: fleet.length > 0
    readonly property bool anyPrinting: fleet.some(p => p.state === "RUNNING" || p.state === "PREPARE")
    readonly property bool anyOffline: fleet.some(p => !p.connected)

    function fmtRemain(m) {
        if (m <= 0) return ""
        const h = Math.floor(m / 60)
        return h > 0 ? h + "h" + (m % 60) + "m" : m + "m"
    }

    function probe() {
        Proc.runCommand("pondDeck.probe",
            ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", "claude-dev",
             "/home/jay/.local/bin/pond-glance"],
            (stdout, exitCode) => {
                if (exitCode !== 0) { root.fleet = []; return }
                try { root.fleet = JSON.parse(stdout) } catch (e) { root.fleet = [] }
            }, 0, 12000)
    }

    Timer {
        interval: 30000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: root.probe()
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        opacity: 0.85
        border.color: root.editMode ? Theme.primary : "transparent"
        border.width: root.editMode ? 2 : 0
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 7

        Item {
            width: parent.width
            height: 18
            StyledText {
                text: "pond"
                color: Theme.surfaceText
                font.pixelSize: 13
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: 8; height: 8; radius: 4
                color: !root.alive ? "#ef4444"
                     : root.anyOffline ? "#ef4444"
                     : root.anyPrinting ? "#fbbf24" : "#4ade80"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Repeater {
            model: root.fleet
            delegate: Row {
                required property var modelData
                readonly property bool printing: modelData.state === "RUNNING" || modelData.state === "PREPARE"
                spacing: 8

                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: !modelData.connected ? "#ef4444"
                         : printing ? "#fbbf24"
                         : modelData.state === "FINISH" ? "#4ade80" : "#6b7280"
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: modelData.name
                    color: Theme.surfaceText
                    font.pixelSize: 11
                    width: 44
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                    visible: printing
                    StyledText {
                        text: (modelData.job || "").length > 22 ? modelData.job.slice(0, 21) + "…" : modelData.job
                        color: Theme.surfaceVariantText
                        font.pixelSize: 9
                    }
                    MeterBar {
                        value: modelData.progress
                        okColor: Theme.primary
                        warnLevel: 101
                        implicitWidth: root.width - 190
                        implicitHeight: 4
                    }
                }
                StyledText {
                    visible: printing
                    text: Math.round(modelData.progress) + "% " + root.fmtRemain(modelData.remaining)
                    color: Theme.surfaceText
                    font.pixelSize: 10
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    visible: !printing
                    text: !modelData.connected ? "offline"
                        : modelData.state === "FINISH" ? "done · " + (modelData.job || "")
                        : modelData.state.toLowerCase()
                    color: !modelData.connected ? "#ef4444" : Theme.surfaceVariantText
                    font.pixelSize: 10
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        StyledText {
            visible: !root.alive
            text: "relay unreachable"
            color: "#ef4444"
            font.pixelSize: 10
        }
    }
}
