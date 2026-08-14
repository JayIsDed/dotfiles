// SysWidget.qml — the metrics cluster, value-dense edition (Jay 08-13):
// LOAD rows carry real numbers (ram used/total G, disk used/size G) with
// sparks bundled under their bars; CORES grid = per-thread util spark +
// freq; THERMALS as before. Every pinnable row has a pin dot — the pinned
// metric's live value rides the bar pill (persisted via plugin data).
import QtQuick
import Quickshell.Io
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
    property real memUsedG: 0
    property real memTotalG: 0
    property string diskUsed: ""
    property string diskSize: ""
    property real freqAvg: 0
    property var tempHist: []
    property var fanHist: []
    property var cpuHist: []
    property var memHist: []
    property var coreUtil: []
    property var coreFreq: []
    property var coreHist: []
    property var corePrevIdle: []
    property var corePrevTotal: []
    property var lastIdle: 0
    property var lastTotal: 0
    property string host: ""
    property string kernel: ""
    property string up: ""
    property real swapTotalG: 0
    property real swapUsedG: 0
    property string load1: ""
    property string load5: ""
    property string load15: ""

    // ── resident pin: which metric's value rides the bar pill
    property string pinned: ""
    Component.onCompleted: {
        if (pluginData && pluginData.pinned !== undefined)
            pinned = pluginData.pinned
    }
    // plugin_settings.json loads async (FileView) — one late re-read
    // catches the stored pin that onCompleted raced past
    Timer {
        interval: 3000; running: true; repeat: false
        onTriggered: {
            if (root.pinned === "" && pluginId)
                root.pinned = SettingsData.getPluginSetting(pluginId, "pinned", "")
        }
    }
    function setPinned(k) {
        pinned = (pinned === k) ? "" : k
        if (pluginService && pluginId)
            pluginService.savePluginData(pluginId, "pinned", pinned)
    }
    readonly property string pinnedValue: {
        switch (pinned) {
        case "cpu":  return Math.round(cpu) + "%"
        case "ram":  return memUsedG.toFixed(1) + "G"
        case "disk": return diskUsed + "G"
        case "tmp":  return temp + "°"
        case "fan":  return fan + ""
        case "swap": return swapUsedG.toFixed(1) + "G"
        case "freq": return freqAvg.toFixed(1) + "GHz"
        default:     return ""
        }
    }

    function fmtUp(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600),
              m = Math.floor(s % 3600 / 60)
        return d > 0 ? d + "d" + h + "h" : h > 0 ? h + "h" + m + "m" : m + "m"
    }

    function probe() {
        Proc.runCommand("sysMetrics.probe",
            ["sh", "-c",
             "echo C $(head -1 /proc/stat); " +
             "echo P $(awk '/^cpu[0-9]/{print $1\":\"$5+$6\":\"$2+$3+$4+$5+$6+$7+$8+$9}' /proc/stat | tr '\\n' ' '); " +
             "echo Q $(cat /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq 2>/dev/null | tr '\\n' ' '); " +
             "echo M $(awk '/^MemTotal|^MemAvailable|^SwapTotal|^SwapFree/{printf \"%s \", $2}' /proc/meminfo); " +
             "echo L $(cut -d' ' -f1-3 /proc/loadavg); " +
             "echo T $(cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | sort -rn | head -1); " +
             "echo D $(df --output=pcent / 2>/dev/null | tail -1 | tr -d ' %'); " +
             "echo E $(df -BG --output=used,size / 2>/dev/null | tail -1 | tr -d 'G'); " +
             "echo F $(cat /sys/class/hwmon/hwmon*/fan1_input 2>/dev/null | head -1); " +
             "echo U $(cut -d. -f1 /proc/uptime) $(cat /proc/sys/kernel/hostname) $(uname -r | cut -d- -f1); true"],
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
                    } else if (p[0] === "P") {
                        const cores = p.slice(1)
                        const utils = [], hists = root.coreHist.slice()
                        const pi = root.corePrevIdle.slice(), pt = root.corePrevTotal.slice()
                        for (let i = 0; i < cores.length; i++) {
                            const seg = cores[i].split(":")
                            const idle = Number(seg[1]), total = Number(seg[2])
                            let u = 0
                            if (pt[i] > 0 && total > pt[i])
                                u = 100 * (1 - (idle - pi[i]) / (total - pt[i]))
                            utils.push(u)
                            if (!hists[i]) hists[i] = []
                            hists[i] = hists[i].concat(u).slice(-30)
                            pi[i] = idle; pt[i] = total
                        }
                        root.coreUtil = utils
                        root.coreHist = hists
                        root.corePrevIdle = pi
                        root.corePrevTotal = pt
                    } else if (p[0] === "Q") {
                        const f = p.slice(1).map(n => Number(n) / 1000000)
                        root.coreFreq = f
                        root.freqAvg = f.length ? f.reduce((a, b) => a + b, 0) / f.length : 0
                    } else if (p[0] === "M" && p.length >= 3) {
                        const totalK = Number(p[1]), availK = Number(p[2])
                        if (totalK > 0) {
                            root.mem = 100 * (1 - availK / totalK)
                            root.memHist = root.memHist.concat(root.mem).slice(-30)
                            root.memTotalG = totalK / 1048576
                            root.memUsedG = (totalK - availK) / 1048576
                        }
                        // meminfo file order: MemTotal MemAvailable SwapTotal SwapFree
                        if (p.length >= 5) {
                            root.swapTotalG = Number(p[3]) / 1048576
                            root.swapUsedG = (Number(p[3]) - Number(p[4])) / 1048576
                        }
                    } else if (p[0] === "L" && p.length >= 4) {
                        root.load1 = p[1]; root.load5 = p[2]; root.load15 = p[3]
                    } else if (p[0] === "T" && p.length >= 2) {
                        root.temp = Math.round(Number(p[1]) / 1000)
                        root.tempHist = root.tempHist.concat(root.temp).slice(-30)
                    } else if (p[0] === "D" && p.length >= 2) {
                        root.disk = Number(p[1])
                    } else if (p[0] === "E" && p.length >= 3) {
                        root.diskUsed = p[1]
                        root.diskSize = p[2]
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
                spacing: Theme.spacingS

                // per-metric stack: icon + readable number over a bar — the
                // battery pill's wattage grammar (Jay's picks 08-14). Icons
                // follow dms's own monitor widgets (developer_board/memory/
                // device_thermostat) so identity reads at a glance; the bar
                // spans the stack. 8px label columns gone; tmp/fan sparks
                // retired to the popout.
                component MStack: Column {
                    id: stk
                    property string icon
                    property string txt
                    property real val: 0
                    property var fill: undefined
                    property color tone: Theme.widgetTextColor
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                    // icon+number ride as ONE centered group; the bar spans
                    // the group (floor 52) so wide values grow the stack
                    Row {
                        id: pair
                        spacing: 3
                        anchors.horizontalCenter: parent.horizontalCenter
                        DankIcon {
                            name: stk.icon
                            size: 13
                            color: Theme.widgetIconColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: stk.txt
                            color: stk.tone
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MeterBar {
                        value: stk.val
                        fillColor: stk.fill
                        okColor: Theme.primary
                        implicitWidth: Math.max(52, pair.implicitWidth)
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                // hairline divider between stacks — segmentation without
                // nesting a pill in a pill
                component Sep: Rectangle {
                    width: 1
                    height: 18
                    radius: 0.5
                    color: Qt.rgba(1, 1, 1, 0.14)
                    anchors.verticalCenter: parent.verticalCenter
                }

                MStack { icon: "developer_board"; txt: Math.round(root.cpu) + "%"; val: root.cpu }
                Sep {}
                MStack { icon: "memory"; txt: Math.round(root.mem) + "%"; val: root.mem }
                Sep {}
                MStack {
                    icon: "device_thermostat"
                    txt: root.temp + "°"
                    val: (root.temp - 30) / 65 * 100
                    tone: root.temp >= 85 ? "#ef4444" : root.temp >= 70 ? "#fbbf24" : Theme.widgetTextColor
                    fill: root.temp >= 85 ? "#ef4444" : root.temp >= 70 ? "#fbbf24" : Theme.primary
                }
                Sep { visible: root.fan >= 0 }
                MStack {
                    icon: "mode_fan"
                    visible: root.fan >= 0
                    txt: String(root.fan)
                    val: root.fan / 70
                    fill: Theme.secondary
                }

                // ── resident: the pinned metric's live value
                Column {
                    spacing: 0
                    visible: root.pinned !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    StyledText { text: root.pinned; color: Theme.primary; font.pixelSize: 8; anchors.horizontalCenter: parent.horizontalCenter }
                    StyledText { text: root.pinnedValue; color: Theme.widgetTextColor; font.pixelSize: 11; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
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

                // pin dot — filled = this metric rides the bar
                component PinDot: Rectangle {
                    property string key
                    width: 10; height: 10; radius: 5
                    color: root.pinned === key ? Theme.primary : "transparent"
                    border.color: root.pinned === key ? Theme.primary : Theme.surfaceVariantText
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        onClicked: root.setPinned(parent.key)
                    }
                }
                // one visual per row: history rows get a severity-colored
                // spark, bounded rows (no hist) keep the bar. Never both.
                component MetricRow: Row {
                    property string pinKey
                    property string label
                    property real val: -1
                    property var hist: []
                    property string valueText
                    property color tone: Theme.primary
                    readonly property color sev: val >= 85 ? "#ef4444" : val >= 70 ? "#fbbf24" : tone
                    spacing: Theme.spacingS
                    width: parent.width
                    PinDot { key: parent.pinKey }
                    StyledText { text: label; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 28; anchors.verticalCenter: parent.verticalCenter }
                    Item {
                        width: parent.width - 172
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        MeterBar { visible: hist.length <= 1 && val >= 0; value: val; okColor: tone; implicitWidth: parent.width; implicitHeight: 5; anchors.verticalCenter: parent.verticalCenter; width: parent.width }
                        Spark { visible: hist.length > 1; values: hist; lineColor: sev; area: false; minValue: 0; maxValue: 100; implicitWidth: parent.width; implicitHeight: 20; stroke: 1.5; width: parent.width; height: 20 }
                    }
                    StyledText { text: valueText; color: val >= 70 ? sev : Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; width: 108; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                }

                Tile {
                    heading: "LOAD"
                    headingColor: Theme.surfaceVariantText
                    MetricRow { pinKey: "cpu"; label: "cpu"; val: root.cpu; hist: root.cpuHist; valueText: Math.round(root.cpu) + "%" }
                    MetricRow { pinKey: "ram"; label: "ram"; val: root.mem; hist: root.memHist; tone: Theme.secondary; valueText: root.memUsedG.toFixed(1) + " / " + root.memTotalG.toFixed(1) + "G" }
                    MetricRow { pinKey: "disk"; label: "dsk"; val: root.disk; valueText: root.diskUsed + " / " + root.diskSize + "G" }
                    MetricRow {
                        pinKey: "swap"; label: "swp"
                        val: root.swapTotalG > 0 ? root.swapUsedG / root.swapTotalG * 100 : -1
                        tone: Theme.tertiary
                        valueText: root.swapTotalG > 0 ? root.swapUsedG.toFixed(1) + " / " + root.swapTotalG.toFixed(1) + "G" : "none"
                        visible: root.swapTotalG > 0
                    }
                    Row {
                        spacing: Theme.spacingS
                        width: parent.width
                        PinDot { key: "freq" }
                        StyledText { text: "freq"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 28; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: root.freqAvg.toFixed(2) + " GHz avg"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; anchors.verticalCenter: parent.verticalCenter }
                        Item { width: 8; height: 1 }
                        StyledText { text: "load"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: root.load1 + " · " + root.load5 + " · " + root.load15; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; anchors.verticalCenter: parent.verticalCenter; visible: root.load1 !== "" }
                    }
                }

                Tile {
                    heading: "CORES"
                    headingColor: Theme.surfaceVariantText
                    Grid {
                        columns: 2
                        columnSpacing: 14
                        rowSpacing: 5
                        width: parent.width
                        Repeater {
                            model: root.coreUtil.length
                            delegate: Row {
                                required property int index
                                spacing: 5
                                StyledText { text: "c" + index; color: Theme.surfaceVariantText; font.pixelSize: 9; width: 16; anchors.verticalCenter: parent.verticalCenter }
                                Spark {
                                    framed: true
                                    values: root.coreHist[index] || []
                                    lineColor: Theme.primary
                                    area: false
                                    minValue: 0; maxValue: 100
                                    implicitWidth: 40; implicitHeight: 14; stroke: 1
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: Math.round(root.coreUtil[index] || 0) + "%"
                                    color: Theme.surfaceText; font.pixelSize: 9; width: 28
                                    horizontalAlignment: Text.AlignRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: (root.coreFreq[index] || 0).toFixed(1) + "G"
                                    color: Theme.surfaceVariantText; font.pixelSize: 9; width: 28
                                    horizontalAlignment: Text.AlignRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }

                Tile {
                    heading: "THERMALS"
                    headingColor: Theme.surfaceVariantText
                    Row {
                        spacing: Theme.spacingS
                        width: parent.width
                        PinDot { key: "tmp" }
                        StyledText { text: "tmp"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 28; anchors.verticalCenter: parent.verticalCenter }
                        Spark {
                            framed: true
                            values: root.tempHist
                            lineColor: root.temp >= 85 ? "#ef4444" : root.temp >= 70 ? "#fbbf24" : Theme.primary
                            area: false
                            minValue: root.tempHist.length ? Math.min(...root.tempHist) - 2 : 30
                            maxValue: root.tempHist.length ? Math.max(...root.tempHist) + 2 : 95
                            implicitWidth: parent.width - 130; implicitHeight: 24; stroke: 1.5
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText { text: root.temp + "°"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; width: 60; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        spacing: Theme.spacingS
                        width: parent.width
                        PinDot { key: "fan" }
                        StyledText { text: "fan"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 28; anchors.verticalCenter: parent.verticalCenter }
                        Spark {
                            framed: true
                            values: root.fanHist
                            lineColor: Theme.secondary
                            area: false
                            minValue: 0
                            maxValue: root.fanHist.length ? Math.max(...root.fanHist) + 500 : 5000
                            implicitWidth: parent.width - 130; implicitHeight: 24; stroke: 1.5
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText { text: root.fan + " rpm"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; width: 60; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                StyledText {
                    text: "pin a metric — it rides the bar"
                    color: Theme.surfaceVariantText
                    font.pixelSize: 9
                }
            }
        }
    }
    popoutWidth: 340
    popoutHeight: 640

    // headless popout toggle: qs -c dms ipc call popout-sys toggle
    IpcHandler {
        target: "popout-sys"
        function toggle(): string { root.triggerPopout(); return "ok" }
    }
}
