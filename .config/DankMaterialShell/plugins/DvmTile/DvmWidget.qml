// DvmWidget.qml — lilypad's DockerTile ported to a DMS plugin (trial seat).
// Same probe: one ssh to docker-services every 10s, cpu from successive
// /proc/stat samples, self-dims when the VM is unreachable.
import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property real cpu: 0
    property real mem: 0
    property string containers: ""
    property var cpuHist: []
    property var memHist: []
    property var lastIdle: 0
    property var lastTotal: 0
    property string up: ""
    property string loadavg: ""
    readonly property bool alive: containers !== ""

    function fmtUp(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600),
              m = Math.floor(s % 3600 / 60)
        return d > 0 ? d + "d" + h + "h" : h > 0 ? h + "h" + m + "m" : m + "m"
    }

    function probe() {
        Proc.runCommand("dvmTile.probe",
            ["ssh", "-o", "ConnectTimeout=4", "-o", "BatchMode=yes", "docker-services",
             "echo C $(head -1 /proc/stat); " +
             "echo M $(awk '/MemTotal|MemAvailable/{printf \"%s \", $2}' /proc/meminfo); " +
             "echo D $(docker ps -q | wc -l)/$(docker ps -aq | wc -l); " +
             "echo U $(cut -d. -f1 /proc/uptime) $(cut -d\" \" -f1-3 /proc/loadavg)"],
            (stdout, exitCode) => {
                if (exitCode !== 0 || stdout.trim() === "") {
                    root.containers = ""
                    return
                }
                for (const line of stdout.trim().split("\n")) {
                    const p = line.trim().split(/\s+/)
                    if (p[0] === "C") {
                        const f = p.slice(2).map(Number)
                        const idle = f[3] + (f[4] || 0)
                        const total = f.reduce((a, b) => a + b, 0)
                        if (root.lastTotal > 0 && total > root.lastTotal) {
                            root.cpu = 100 * (1 - (idle - root.lastIdle) / (total - root.lastTotal))
                            root.cpuHist = root.cpuHist.concat(root.cpu).slice(-30)
                        }
                        root.lastIdle = idle
                        root.lastTotal = total
                    } else if (p[0] === "M" && p.length >= 3) {
                        if (Number(p[1]) > 0) {
                            root.mem = 100 * (1 - Number(p[2]) / Number(p[1]))
                            root.memHist = root.memHist.concat(root.mem).slice(-30)
                        }
                    } else if (p[0] === "D" && p.length >= 2) {
                        root.containers = p[1]
                    } else if (p[0] === "U" && p.length >= 5) {
                        root.up = root.fmtUp(Number(p[1]))
                        root.loadavg = p[2] + " " + p[3] + " " + p[4]
                    }
                }
            }, 0, 8000)
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.probe()
    }

    // NOTE: the pill Component is CONTENT inside dms's BasePill (chrome,
    // padding, hover all come free) — size via implicitWidth like their
    // built-in widgets, never draw your own pill rect (double chrome +
    // zero-width allocation = the overlap Jay caught)
    // lilypad grammar: labels | stacked MeterBars | numbers, dvm count east
    horizontalBarPill: Component {
        Item {
            implicitWidth: dvmRow.implicitWidth
            implicitHeight: dvmRow.implicitHeight

            Row {
                id: dvmRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "dns"
                    size: root.iconSize
                    color: root.alive ? Theme.widgetIconColor : Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    spacing: 1
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.alive
                    StyledText { text: "cpu"; color: Theme.surfaceVariantText; font.pixelSize: 8 }
                    StyledText { text: "ram"; color: Theme.surfaceVariantText; font.pixelSize: 8 }
                }
                Column {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.alive
                    MeterBar { value: root.cpu; okColor: Theme.primary; implicitWidth: 44 }
                    MeterBar { value: root.mem; okColor: Theme.primary; implicitWidth: 44 }
                }
                Column {
                    spacing: 1
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.alive
                    StyledText { text: Math.round(root.cpu) + "%"; color: Theme.widgetTextColor; font.pixelSize: 8; horizontalAlignment: Text.AlignRight; width: 22 }
                    StyledText { text: Math.round(root.mem) + "%"; color: Theme.widgetTextColor; font.pixelSize: 8; horizontalAlignment: Text.AlignRight; width: 22 }
                }
                StyledText {
                    text: root.alive ? root.containers : "off"
                    color: root.alive ? Theme.widgetTextColor : Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "docker-vm"
            detailsText: "VM 202 · " + (root.alive ? root.containers + " containers running" : "unreachable")
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingS

                component BarRow: Row {
                    property string label
                    property real val
                    property color tone: Theme.primary
                    spacing: Theme.spacingS
                    width: parent.width
                    StyledText { text: label; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 30; anchors.verticalCenter: parent.verticalCenter }
                    MeterBar { value: val; okColor: tone; implicitWidth: parent.width - 86; implicitHeight: 5; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: Math.round(val) + "%"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; width: 40; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                }
                component SparkRow: Row {
                    property string label
                    property var hist: []
                    property string valueText
                    property color tone: Theme.primary
                    spacing: Theme.spacingS
                    width: parent.width
                    StyledText { text: label; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 30; anchors.verticalCenter: parent.verticalCenter }
                    Spark { values: hist; lineColor: tone; area: false; minValue: 0; maxValue: 100; implicitWidth: parent.width - 86; implicitHeight: 22; stroke: 1.5; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: valueText; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; width: 40; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                }

                Tile {
                    heading: "LOAD"
                    headingColor: Theme.surfaceVariantText
                    BarRow { label: "cpu"; val: root.cpu }
                    BarRow { label: "ram"; val: root.mem; tone: Theme.secondary }
                }
                Tile {
                    heading: "HISTORY"
                    headingColor: Theme.surfaceVariantText
                    SparkRow { label: "cpu"; hist: root.cpuHist; valueText: Math.round(root.cpu) + "%" }
                    SparkRow { label: "ram"; hist: root.memHist; valueText: Math.round(root.mem) + "%"; tone: Theme.secondary }
                }
                Tile {
                    heading: "HOST"
                    headingColor: Theme.surfaceVariantText
                    StyledText { text: "containers   " + root.containers; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeMedium }
                    StyledText { text: "load   " + root.loadavg; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                    StyledText { text: "up   " + root.up + "  ·  10s ssh probe"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                }
            }
        }
    }
    popoutWidth: 320
    popoutHeight: 440

    // headless popout toggle: qs -c dms ipc call popout-dvm toggle
    IpcHandler {
        target: "popout-dvm"
        function toggle(): string { root.triggerPopout(); return "ok" }
    }
}
