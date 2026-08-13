// SysWidget.qml — lilypad's MetricsCluster grammar (label | visual | number)
// as a dms plugin: cpu/ram/dsk stacked MeterBars + tmp/fan dual Spark.
// Probe is lilypad's sysProbe verbatim, local sh every 2s. MeterBar/Spark
// are the self-contained kit copies in this dir.
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property real cpu: 0
    property real mem: 0
    property int disk: -1
    property int temp: 0
    property int fan: 0
    property var tempHist: []
    property var fanHist: []
    property var lastIdle: 0
    property var lastTotal: 0

    function probe() {
        Proc.runCommand("sysMetrics.probe",
            ["sh", "-c",
             "echo C $(head -1 /proc/stat); " +
             "echo M $(awk '/MemTotal|MemAvailable/{printf \"%s \", $2}' /proc/meminfo); " +
             "echo T $(cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | sort -rn | head -1); " +
             "echo D $(df --output=pcent / 2>/dev/null | tail -1 | tr -d ' %'); " +
             "echo F $(cat /sys/class/hwmon/hwmon*/fan1_input 2>/dev/null | head -1)"],
            (stdout, exitCode) => {
                if (exitCode !== 0) return
                for (const line of stdout.trim().split("\n")) {
                    const p = line.trim().split(/\s+/)
                    if (p[0] === "C") {
                        const f = p.slice(2).map(Number)
                        const idle = f[3] + (f[4] || 0)
                        const total = f.reduce((a, b) => a + b, 0)
                        if (root.lastTotal > 0 && total > root.lastTotal)
                            root.cpu = 100 * (1 - (idle - root.lastIdle) / (total - root.lastTotal))
                        root.lastIdle = idle; root.lastTotal = total
                    } else if (p[0] === "M" && p.length >= 3) {
                        if (Number(p[1]) > 0) root.mem = 100 * (1 - Number(p[2]) / Number(p[1]))
                    } else if (p[0] === "T" && p.length >= 2) {
                        root.temp = Math.round(Number(p[1]) / 1000)
                        root.tempHist = root.tempHist.concat(root.temp).slice(-30)
                    } else if (p[0] === "D" && p.length >= 2) {
                        root.disk = Number(p[1])
                    } else if (p[0] === "F" && p.length >= 2) {
                        root.fan = Number(p[1])
                        root.fanHist = root.fanHist.concat(root.fan).slice(-30)
                    }
                }
            }, 0, 5000)
    }

    Timer {
        interval: 2000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: root.probe()
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: cluster.implicitWidth
            implicitHeight: cluster.implicitHeight

            Row {
                id: cluster
                anchors.centerIn: parent
                spacing: Theme.spacingM

                // ── cpu / ram / dsk — labels | bars | numbers
                Row {
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter
                    Column {
                        spacing: 1
                        anchors.verticalCenter: parent.verticalCenter
                        StyledText { text: "cpu"; color: Theme.surfaceVariantText; font.pixelSize: 8 }
                        StyledText { text: "ram"; color: Theme.surfaceVariantText; font.pixelSize: 8 }
                        StyledText { text: "dsk"; color: Theme.surfaceVariantText; font.pixelSize: 8; visible: root.disk >= 0 }
                    }
                    Column {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter
                        MeterBar { value: root.cpu; okColor: Theme.primary }
                        MeterBar { value: root.mem; okColor: Theme.primary }
                        MeterBar { value: root.disk; okColor: Theme.primary; visible: root.disk >= 0 }
                    }
                    Column {
                        spacing: 1
                        anchors.verticalCenter: parent.verticalCenter
                        StyledText { text: Math.round(root.cpu) + "%"; color: Theme.widgetTextColor; font.pixelSize: 8; horizontalAlignment: Text.AlignRight; width: 22 }
                        StyledText { text: Math.round(root.mem) + "%"; color: Theme.widgetTextColor; font.pixelSize: 8; horizontalAlignment: Text.AlignRight; width: 22 }
                        StyledText { text: root.disk + "%"; color: Theme.widgetTextColor; font.pixelSize: 8; horizontalAlignment: Text.AlignRight; width: 22; visible: root.disk >= 0 }
                    }
                }

                // ── tmp / fan — labels | sparks | numbers
                Row {
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter
                    Column {
                        spacing: 1
                        anchors.verticalCenter: parent.verticalCenter
                        StyledText { text: "tmp"; color: Theme.surfaceVariantText; font.pixelSize: 8 }
                        StyledText { text: "fan"; color: Theme.surfaceVariantText; font.pixelSize: 8 }
                    }
                    Column {
                        spacing: 2
                        anchors.verticalCenter: parent.verticalCenter
                        Spark {
                            values: root.tempHist
                            minValue: root.tempHist.length ? Math.min(...root.tempHist) - 2 : 30
                            maxValue: root.tempHist.length ? Math.max(...root.tempHist) + 2 : 95
                            lineColor: root.temp >= 85 ? "#ef4444" : root.temp >= 70 ? "#fbbf24" : Theme.primary
                        }
                        Spark {
                            values: root.fanHist
                            minValue: 0
                            maxValue: root.fanHist.length ? Math.max(...root.fanHist) + 500 : 5000
                            lineColor: Theme.secondary
                        }
                    }
                    Column {
                        spacing: 1
                        anchors.verticalCenter: parent.verticalCenter
                        StyledText { text: root.temp + "°"; color: root.temp >= 85 ? "#ef4444" : root.temp >= 70 ? "#fbbf24" : Theme.widgetTextColor; font.pixelSize: 8; horizontalAlignment: Text.AlignRight; width: 26 }
                        StyledText { text: root.fan > 0 ? String(root.fan) : "—"; color: Theme.widgetTextColor; font.pixelSize: 8; horizontalAlignment: Text.AlignRight; width: 26 }
                    }
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "system"
            detailsText: "local host vitals"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                StyledText { text: "cpu  " + Math.round(root.cpu) + "%"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeLarge }
                StyledText { text: "ram  " + Math.round(root.mem) + "%"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeLarge }
                StyledText { text: "disk " + root.disk + "%"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeLarge }
                StyledText { text: "temp " + root.temp + "°  ·  fan " + root.fan + " rpm"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeLarge }
            }
        }
    }
    popoutWidth: 320
    popoutHeight: 240
}
