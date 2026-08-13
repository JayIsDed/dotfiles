// ShelfWidget.qml — the calibration shelf (and its shrimp) on the desktop.
// Data rides `ssh claude-dev shelf-glance` — HA token stays on 111, the
// laptop only ever sees JSON. 60s cadence: the shelf moves slowly and this
// is ambience. Heater dot: amber heating / green idle-at-target / gray off.
import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property var pluginService: null
    property string pluginId: ""
    property bool editMode: false
    property real widgetWidth: 320
    property real widgetHeight: 195
    property real minWidth: 240
    property real minHeight: 160

    property var tank: null
    property var substrate: null
    property var ambient: null
    property var bucket: null
    property string heaterAction: ""
    property var target: null
    property var heaterW: null
    property var tankHist: []
    readonly property bool alive: tank !== null

    function probe() {
        Proc.runCommand("shelfDeck.probe",
            ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", "claude-dev",
             "/home/jay/.local/bin/shelf-glance"],
            (stdout, exitCode) => {
                if (exitCode !== 0) { root.tank = null; return }
                try {
                    const j = JSON.parse(stdout)
                    root.tank = j.tank
                    root.substrate = j.substrate
                    root.ambient = j.ambient
                    root.bucket = j.bucket
                    root.heaterAction = j.heater_action || ""
                    root.target = j.target
                    root.heaterW = j.heater_w
                    if (j.tank !== null)
                        root.tankHist = root.tankHist.concat(j.tank).slice(-60)
                } catch (e) { root.tank = null }
            }, 0, 12000)
    }

    Timer {
        interval: 60000; running: true; repeat: true
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
                text: "shelf"
                color: Theme.surfaceText
                font.pixelSize: 13
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: 8; height: 8; radius: 4
                color: !root.alive ? "#ef4444"
                     : root.heaterAction === "heating" ? "#fbbf24"
                     : root.heaterAction === "idle" ? "#4ade80" : "#6b7280"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // tank — the star metric: big number + spark
        Row {
            spacing: 10
            StyledText {
                text: root.alive ? root.tank + "°" : "—"
                color: Theme.surfaceText
                font.pixelSize: 26
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter
                StyledText { text: "tank"; color: Theme.surfaceVariantText; font.pixelSize: 9 }
                Spark {
                    visible: tankHist.length > 1
                    values: root.tankHist
                    lineColor: Theme.primary
                    area: false
                    minValue: root.tankHist.length ? Math.min(...root.tankHist) - 0.5 : 70
                    maxValue: root.tankHist.length ? Math.max(...root.tankHist) + 0.5 : 80
                    implicitWidth: root.width - 130
                    implicitHeight: 18
                    stroke: 1.5
                }
            }
        }

        Row {
            spacing: 14
            StyledText { text: "substrate " + (root.substrate ?? "—") + "°"; color: Theme.surfaceVariantText; font.pixelSize: 10 }
            StyledText { text: "air " + (root.ambient ?? "—") + "°"; color: Theme.surfaceVariantText; font.pixelSize: 10 }
            StyledText { text: "bucket " + (root.bucket ?? "—") + "°"; color: Theme.surfaceVariantText; font.pixelSize: 10 }
        }

        StyledText {
            text: root.alive
                ? "heater " + root.heaterAction + " · " + (root.heaterW ?? 0) + "W · target " + (root.target ?? "—") + "°"
                : "relay unreachable"
            color: root.heaterAction === "heating" ? "#fbbf24" : Theme.surfaceVariantText
            font.pixelSize: 10
        }
    }
}
