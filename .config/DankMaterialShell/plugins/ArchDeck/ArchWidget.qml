// ArchWidget.qml — taichi (the archbox) on the desktop. Two states:
// awake = cpu/ram bars + 3090 gpu row + uptime; asleep = a WAKE button.
// Magic packets don't cross the tailnet, so the wake relays through 111
// (wakeonlan lives there). ssh probe 15s, self-detects sleep.
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
    property real minWidth: 240
    property real minHeight: 150

    property real cpu: 0
    property real mem: 0
    property int gpuUtil: -1
    property int gpuTemp: -1
    property string up: ""
    property var cpuHist: []
    property var lastIdle: 0
    property var lastTotal: 0
    property bool awake: false
    property bool waking: false

    function fmtUp(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600),
              m = Math.floor(s % 3600 / 60)
        return d > 0 ? d + "d" + h + "h" : h > 0 ? h + "h" + m + "m" : m + "m"
    }

    function probe() {
        Proc.runCommand("archDeck.probe",
            ["ssh", "-o", "ConnectTimeout=4", "-o", "BatchMode=yes", "archbox",
             "echo C $(head -1 /proc/stat); " +
             "echo M $(awk '/MemTotal|MemAvailable/{printf \"%s \", $2}' /proc/meminfo); " +
             "echo U $(cut -d. -f1 /proc/uptime); " +
             "echo G $(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')"],
            (stdout, exitCode) => {
                if (exitCode !== 0 || stdout.trim() === "") {
                    root.awake = false
                    return
                }
                root.awake = true
                root.waking = false
                for (const line of stdout.trim().split("\n")) {
                    const p = line.trim().split(/\s+/)
                    if (p[0] === "C") {
                        const f = p.slice(2).map(Number)
                        const idle = f[3] + (f[4] || 0)
                        const total = f.reduce((a, b) => a + b, 0)
                        if (root.lastTotal > 0 && total > root.lastTotal) {
                            root.cpu = 100 * (1 - (idle - root.lastIdle) / (total - root.lastTotal))
                            root.cpuHist = root.cpuHist.concat(root.cpu).slice(-40)
                        }
                        root.lastIdle = idle; root.lastTotal = total
                    } else if (p[0] === "M" && p.length >= 3) {
                        if (Number(p[1]) > 0) root.mem = 100 * (1 - Number(p[2]) / Number(p[1]))
                    } else if (p[0] === "U" && p.length >= 2) {
                        root.up = root.fmtUp(Number(p[1]))
                    } else if (p[0] === "G" && p.length >= 2) {
                        const g = p[1].split(",")
                        root.gpuUtil = g.length >= 2 ? Number(g[0]) : -1
                        root.gpuTemp = g.length >= 2 ? Number(g[1]) : -1
                    }
                }
            }, 0, 8000)
    }

    function wake() {
        root.waking = true
        Proc.runCommand("archDeck.wake",
            ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", "claude-dev",
             "wakeonlan a8:a1:59:e8:29:19"],
            (stdout, exitCode) => {}, 0, 8000)
        wakeReset.restart()
    }
    // if it hasn't answered in 90s, put the button back
    Timer { id: wakeReset; interval: 90000; onTriggered: root.waking = false }

    Timer {
        interval: 15000; running: true; repeat: true
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
        spacing: 8

        Item {
            width: parent.width
            height: 18
            StyledText {
                text: "archbox"
                color: Theme.surfaceText
                font.pixelSize: 13
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: 8; height: 8; radius: 4
                color: root.awake ? "#4ade80" : root.waking ? "#fbbf24" : "#6b7280"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── awake: metrics
        Column {
            spacing: 8
            visible: root.awake
            width: parent.width

            Row {
                spacing: 6
                Text { text: "cpu"; color: Theme.surfaceVariantText; font.pixelSize: 10; width: 28; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    spacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                    MeterBar { value: root.cpu; okColor: Theme.primary; implicitWidth: root.width - 110; implicitHeight: 4 }
                    Spark { visible: cpuHist.length > 1; values: root.cpuHist; lineColor: Theme.primary; area: false; minValue: 0; maxValue: 100; implicitWidth: root.width - 110; implicitHeight: 14; stroke: 1.5 }
                }
                Text { text: Math.round(root.cpu) + "%"; color: Theme.surfaceText; font.pixelSize: 10; width: 32; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                spacing: 6
                Text { text: "ram"; color: Theme.surfaceVariantText; font.pixelSize: 10; width: 28; anchors.verticalCenter: parent.verticalCenter }
                MeterBar { value: root.mem; okColor: Theme.secondary; implicitWidth: root.width - 110; implicitHeight: 4; anchors.verticalCenter: parent.verticalCenter }
                Text { text: Math.round(root.mem) + "%"; color: Theme.surfaceText; font.pixelSize: 10; width: 32; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                spacing: 6
                visible: root.gpuUtil >= 0
                Text { text: "gpu"; color: Theme.surfaceVariantText; font.pixelSize: 10; width: 28; anchors.verticalCenter: parent.verticalCenter }
                MeterBar { value: root.gpuUtil; okColor: Theme.primary; warnLevel: 101; implicitWidth: root.width - 110; implicitHeight: 4; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: root.gpuUtil + "% " + root.gpuTemp + "°"
                    color: root.gpuTemp >= 80 ? "#ef4444" : Theme.surfaceText
                    font.pixelSize: 10; width: 44; horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            StyledText {
                text: "3090 · up " + root.up
                color: Theme.surfaceVariantText
                font.pixelSize: 10
            }
        }

        // ── asleep: the wake button
        Column {
            spacing: 10
            visible: !root.awake
            width: parent.width

            Rectangle {
                width: parent.width
                height: 44
                radius: Theme.cornerRadius
                color: root.waking ? Qt.rgba(0.98, 0.75, 0.14, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                border.color: root.waking ? "#fbbf24" : Theme.primary
                border.width: 1

                StyledText {
                    text: root.waking ? "waking…" : "WAKE"
                    color: root.waking ? "#fbbf24" : Theme.primary
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    anchors.centerIn: parent
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !root.editMode && !root.waking
                    onClicked: root.wake()
                }
            }
            StyledText {
                text: "asleep · wol via 111 · boots ~40s"
                color: Theme.surfaceVariantText
                font.pixelSize: 10
            }
        }
    }
}
