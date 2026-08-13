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
    property var cpuHist: []
    property var memHist: []
    property var lastIdle: 0
    property var lastTotal: 0
    property string host: ""
    property string kernel: ""
    property string up: ""

    function fmtUp(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600),
              m = Math.floor(s % 3600 / 60)
        return d > 0 ? d + "d" + h + "h" : h > 0 ? h + "h" + m + "m" : m + "m"
    }

    function probe() {
        Proc.runCommand("sysMetrics.probe",
            ["sh", "-c",
             "echo C $(head -1 /proc/stat); " +
             "echo M $(awk '/MemTotal|MemAvailable/{printf \"%s \", $2}' /proc/meminfo); " +
             "echo T $(cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | sort -rn | head -1); " +
             "echo D $(df --output=pcent / 2>/dev/null | tail -1 | tr -d ' %'); " +
             "echo F $(cat /sys/class/hwmon/hwmon*/fan1_input 2>/dev/null | head -1); " +
             "echo U $(cut -d. -f1 /proc/uptime) $(cat /proc/sys/kernel/hostname) $(uname -r | cut -d- -f1)"],
            (stdout, exitCode) => {
                if (exitCode !== 0) return
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
                        root.lastIdle = idle; root.lastTotal = total
                    } else if (p[0] === "M" && p.length >= 3) {
                        if (Number(p[1]) > 0) {
                            root.mem = 100 * (1 - Number(p[2]) / Number(p[1]))
                            root.memHist = root.memHist.concat(root.mem).slice(-30)
                        }
                    } else if (p[0] === "T" && p.length >= 2) {
                        root.temp = Math.round(Number(p[1]) / 1000)
                        root.tempHist = root.tempHist.concat(root.temp).slice(-30)
                    } else if (p[0] === "D" && p.length >= 2) {
                        root.disk = Number(p[1])
                    } else if (p[0] === "F" && p.length >= 2) {
                        root.fan = Number(p[1])
                        root.fanHist = root.fanHist.concat(root.fan).slice(-30)
                    } else if (p[0] === "U" && p.length >= 4) {
                        root.up = root.fmtUp(Number(p[1]))
                        root.host = p[2]
                        root.kernel = p[3]
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
                        // 0 rpm is a PARKED fan, not a broken sensor — show it
                        StyledText { text: String(root.fan); color: Theme.widgetTextColor; font.pixelSize: 8; horizontalAlignment: Text.AlignRight; width: 26 }
                    }
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "system"
            detailsText: root.host + " · " + root.kernel + " · up " + root.up
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingS

                component MetricRow: Row {
                    property string label
                    property real val
                    property var hist: []
                    spacing: Theme.spacingS
                    StyledText { text: label; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 34; anchors.verticalCenter: parent.verticalCenter }
                    MeterBar { value: val; okColor: Theme.primary; implicitWidth: 150; implicitHeight: 5; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: Math.round(val) + "%"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; width: 34; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                }

                MetricRow { label: "cpu"; val: root.cpu; }
                Spark { values: root.cpuHist; lineColor: Theme.primary; minValue: 0; maxValue: 100; implicitWidth: 260; implicitHeight: 26; stroke: 2 }
                MetricRow { label: "ram"; val: root.mem }
                Spark { values: root.memHist; lineColor: Theme.secondary; minValue: 0; maxValue: 100; implicitWidth: 260; implicitHeight: 26; stroke: 2 }
                MetricRow { label: "disk"; val: root.disk }

                Row {
                    spacing: Theme.spacingS
                    StyledText { text: "tmp"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 34; anchors.verticalCenter: parent.verticalCenter }
                    Spark {
                        values: root.tempHist
                        minValue: root.tempHist.length ? Math.min(...root.tempHist) - 2 : 30
                        maxValue: root.tempHist.length ? Math.max(...root.tempHist) + 2 : 95
                        lineColor: root.temp >= 85 ? "#ef4444" : root.temp >= 70 ? "#fbbf24" : Theme.primary
                        implicitWidth: 184; implicitHeight: 24; stroke: 2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText { text: root.temp + "°"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; width: 34; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    spacing: Theme.spacingS
                    StyledText { text: "fan"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 34; anchors.verticalCenter: parent.verticalCenter }
                    Spark {
                        values: root.fanHist
                        minValue: 0
                        maxValue: root.fanHist.length ? Math.max(...root.fanHist) + 500 : 5000
                        lineColor: Theme.secondary
                        implicitWidth: 184; implicitHeight: 24; stroke: 2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText { text: root.fan + " rpm"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
    popoutWidth: 320
    popoutHeight: 380
}
