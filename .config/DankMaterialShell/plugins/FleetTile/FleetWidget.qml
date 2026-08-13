// FleetWidget.qml — the server fleet behind ONE bar pill. v2 (Jay 08-13):
// the ARCHBOX tile gets the full instrument panel — all 32 threads with
// sparks + clocks, 3090 block (util/vram/power), the iCX3 sensor family
// off the card, wall power via the arch-glance HA relay, WAKE with live
// switch state. dvm + 111 dial down to aggregate lines. Colorized per
// metric family: util=accent, ram=secondary, gpu=purple, power=greens,
// die=amber, vram=pink, mem=rose, vrm=orange, fans=cyan.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property var hostOrder: ["dvm", "arch", "111"]

    // metric family hues (fixed — must read the same on every wallpaper)
    readonly property color cGpu: "#a78bfa"
    readonly property color cWall: "#4ade80"
    readonly property color cGpuPow: "#86efac"
    readonly property color cDie: "#fbbf24"
    readonly property color cVram: "#f472b6"
    readonly property color cMem: "#fda4af"
    readonly property color cVrm: "#fb923c"
    readonly property color cFan: "#22d3ee"

    // ── dvm (aggregate)
    property bool dvmAlive: false
    property real dvmCpu: 0
    property real dvmMem: 0
    property string dvmExtra: ""
    property real dvmMemUsedG: 0
    property real dvmMemTotalG: 0
    property int dvmDisk: -1
    property string dvmDiskUsed: ""
    property string dvmDiskSize: ""
    property var dvmHist: []
    property var dvmMemHist: []
    property var dvmPrevI: 0
    property var dvmPrevT: 0

    // ── arch (full panel)
    property bool archAlive: false
    property bool archWaking: false
    property real archCpu: 0
    property real archMem: 0
    property real archMemUsedG: 0
    property real archMemTotalG: 0
    property string archUp: ""
    property var archHist: []
    property var archPrevI: 0
    property var archPrevT: 0
    property var aCoreUtil: []
    property var aCoreFreq: []
    property var aCoreHist: []
    property var aCorePI: []
    property var aCorePT: []
    property int gpuU: -1
    property int gpuT: -1
    property real gpuPow: -1
    property int vramUsed: -1
    property int vramTotal: -1
    property var gpuUHist: []
    property var gpuTHist: []
    property var gpuPowHist: []
    property real icxGpu2: -1
    property real icxVram: -1
    property real icxMemAvg: -1
    property real icxPwrAvg: -1
    property var icxVramHist: []
    property var icxPwrHist: []
    property var fanRpm: []
    property var fanHist: []
    property real wallW: -1
    property real kwhToday: -1
    property string plugState: ""
    property var wallHist: []

    // ── 111 (aggregate)
    property bool labAlive: false
    property real labCpu: 0
    property real labMem: 0
    property string labExtra: ""
    property real labMemUsedG: 0
    property real labMemTotalG: 0
    property int labDisk: -1
    property string labDiskUsed: ""
    property string labDiskSize: ""
    property var labHist: []
    property var labMemHist: []
    property var labPrevI: 0
    property var labPrevT: 0

    // ── resident selection
    property string resident: "dvm"
    Component.onCompleted: {
        if (pluginData && pluginData.resident)
            resident = pluginData.resident
    }
    Timer {
        interval: 3000; running: true; repeat: false
        onTriggered: {
            const r = pluginId ? SettingsData.getPluginSetting(pluginId, "resident", "") : ""
            if (r !== "") root.resident = r
        }
    }
    function setResident(h) {
        resident = h
        if (pluginService && pluginId)
            pluginService.savePluginData(pluginId, "resident", h)
    }
    pillRightClickAction: () => {
        const i = hostOrder.indexOf(resident)
        setResident(hostOrder[(i + 1) % hostOrder.length])
    }

    readonly property bool resAlive: resident === "dvm" ? dvmAlive : resident === "arch" ? archAlive : labAlive
    readonly property real resCpu: resident === "dvm" ? dvmCpu : resident === "arch" ? archCpu : labCpu
    readonly property real resMem: resident === "dvm" ? dvmMem : resident === "arch" ? archMem : labMem
    readonly property string resExtra: resident === "dvm" ? dvmExtra
        : resident === "arch" ? (gpuU >= 0 ? gpuU + "% " + gpuT + "°" : "")
        : labExtra

    function fmtUp(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600),
              m = Math.floor(s % 3600 / 60)
        return d > 0 ? d + "d" + h + "h" : h > 0 ? h + "h" + m + "m" : m + "m"
    }

    function parseStat(p, prevI, prevT) {
        const f = p.slice(2).map(Number)
        const idle = f[3] + (f[4] || 0)
        const total = f.reduce((a, b) => a + b, 0)
        let cpu = -1
        if (prevT > 0 && total > prevT)
            cpu = 100 * (1 - (idle - prevI) / (total - prevT))
        return { idle: idle, total: total, cpu: cpu }
    }

    function probeDvm() {
        Proc.runCommand("fleetTile.dvm",
            ["ssh", "-o", "ConnectTimeout=4", "-o", "BatchMode=yes", "docker-services",
             "echo C $(head -1 /proc/stat); " +
             "echo M $(awk '/MemTotal|MemAvailable/{printf \"%s \", $2}' /proc/meminfo); " +
             "echo D $(docker ps -q | wc -l)/$(docker ps -aq | wc -l); " +
             "echo K $(df -BG --output=pcent,used,size / 2>/dev/null | tail -1 | tr -d '%G')"],
            (stdout, exitCode) => {
                if (exitCode !== 0 || stdout.trim() === "") { root.dvmAlive = false; return }
                root.dvmAlive = true
                for (const line of stdout.trim().split("\n")) {
                    const p = line.trim().split(/\s+/)
                    if (p[0] === "C") {
                        const r = parseStat(p, root.dvmPrevI, root.dvmPrevT)
                        if (r.cpu >= 0) {
                            root.dvmCpu = r.cpu
                            root.dvmHist = root.dvmHist.concat(r.cpu).slice(-30)
                        }
                        root.dvmPrevI = r.idle; root.dvmPrevT = r.total
                    } else if (p[0] === "M" && p.length >= 3 && Number(p[1]) > 0) {
                        root.dvmMem = 100 * (1 - Number(p[2]) / Number(p[1]))
                        root.dvmMemHist = root.dvmMemHist.concat(root.dvmMem).slice(-30)
                        root.dvmMemTotalG = Number(p[1]) / 1048576
                        root.dvmMemUsedG = (Number(p[1]) - Number(p[2])) / 1048576
                    } else if (p[0] === "D" && p.length >= 2) {
                        root.dvmExtra = p[1]
                    } else if (p[0] === "K" && p.length >= 4) {
                        root.dvmDisk = Number(p[1])
                        root.dvmDiskUsed = p[2]
                        root.dvmDiskSize = p[3]
                    }
                }
            }, 0, 8000)
    }

    function probeArch() {
        Proc.runCommand("fleetTile.arch",
            ["ssh", "-o", "ConnectTimeout=4", "-o", "BatchMode=yes", "archbox",
             "echo C $(head -1 /proc/stat); " +
             "echo P $(awk '/^cpu[0-9]/{print $1\":\"$5+$6\":\"$2+$3+$4+$5+$6+$7+$8+$9}' /proc/stat | tr '\\n' ' '); " +
             "echo Q $(for i in $(seq 0 $(( $(nproc) - 1 ))); do cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq 2>/dev/null || echo 0; done | tr '\\n' ' '); " +
             "echo M $(awk '/MemTotal|MemAvailable/{printf \"%s \", $2}' /proc/meminfo); " +
             "echo U $(cut -d. -f1 /proc/uptime); " +
             "echo G $(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,power.draw,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | tr -d ' '); " +
             "echo I $(grep icx3_temp /var/lib/archbox-sensors/icx.influx 2>/dev/null | sed 's/.*sensor=\\([a-z0-9]*\\) temp=\\([0-9.]*\\).*/\\1:\\2/' | tr '\\n' ' '); " +
             "echo J $(grep icx3_fan /var/lib/archbox-sensors/icx.influx 2>/dev/null | sed 's/.*rpm=\\([0-9]*\\)i.*/\\1/' | tr '\\n' ' '); true"],
            (stdout, exitCode) => {
                if (exitCode !== 0 || stdout.trim() === "") { root.archAlive = false; return }
                root.archAlive = true
                root.archWaking = false
                for (const line of stdout.trim().split("\n")) {
                    const p = line.trim().split(/\s+/)
                    if (p[0] === "C") {
                        const r = parseStat(p, root.archPrevI, root.archPrevT)
                        if (r.cpu >= 0) {
                            root.archCpu = r.cpu
                            root.archHist = root.archHist.concat(r.cpu).slice(-30)
                        }
                        root.archPrevI = r.idle; root.archPrevT = r.total
                    } else if (p[0] === "P") {
                        const cores = p.slice(1)
                        const utils = [], hists = root.aCoreHist.slice()
                        const pi = root.aCorePI.slice(), pt = root.aCorePT.slice()
                        for (let i = 0; i < cores.length; i++) {
                            const seg = cores[i].split(":")
                            const idle = Number(seg[1]), total = Number(seg[2])
                            let u = 0
                            if (pt[i] > 0 && total > pt[i])
                                u = 100 * (1 - (idle - pi[i]) / (total - pt[i]))
                            utils.push(u)
                            if (!hists[i]) hists[i] = []
                            hists[i] = hists[i].concat(u).slice(-20)
                            pi[i] = idle; pt[i] = total
                        }
                        root.aCoreUtil = utils
                        root.aCoreHist = hists
                        root.aCorePI = pi
                        root.aCorePT = pt
                    } else if (p[0] === "Q") {
                        root.aCoreFreq = p.slice(1).map(n => Number(n) / 1000000)
                    } else if (p[0] === "M" && p.length >= 3 && Number(p[1]) > 0) {
                        root.archMem = 100 * (1 - Number(p[2]) / Number(p[1]))
                        root.archMemTotalG = Number(p[1]) / 1048576
                        root.archMemUsedG = (Number(p[1]) - Number(p[2])) / 1048576
                    } else if (p[0] === "U" && p.length >= 2) {
                        root.archUp = fmtUp(Number(p[1]))
                    } else if (p[0] === "G" && p.length >= 2 && p[1].indexOf(",") > 0) {
                        const g = p[1].split(",")
                        root.gpuU = Number(g[0]); root.gpuT = Number(g[1])
                        root.gpuPow = Number(g[2])
                        root.vramUsed = Number(g[3]); root.vramTotal = Number(g[4])
                        root.gpuUHist = root.gpuUHist.concat(root.gpuU).slice(-30)
                        root.gpuTHist = root.gpuTHist.concat(root.gpuT).slice(-30)
                        root.gpuPowHist = root.gpuPowHist.concat(root.gpuPow).slice(-30)
                    } else if (p[0] === "I") {
                        const t = {}
                        for (const kv of p.slice(1)) {
                            const s = kv.split(":")
                            if (s.length === 2) t[s[0]] = Number(s[1])
                        }
                        if (t.gpu2 !== undefined) root.icxGpu2 = t.gpu2
                        if (t.vram !== undefined) {
                            root.icxVram = t.vram
                            root.icxVramHist = root.icxVramHist.concat(t.vram).slice(-30)
                        }
                        const mems = ["mem1", "mem2", "mem3"].map(k => t[k]).filter(v => v !== undefined)
                        if (mems.length) root.icxMemAvg = mems.reduce((a, b) => a + b, 0) / mems.length
                        const pwrs = ["pwr1", "pwr2", "pwr3", "pwr4"].map(k => t[k]).filter(v => v !== undefined)
                        if (pwrs.length) {
                            root.icxPwrAvg = pwrs.reduce((a, b) => a + b, 0) / pwrs.length
                            root.icxPwrHist = root.icxPwrHist.concat(root.icxPwrAvg).slice(-30)
                        }
                    } else if (p[0] === "J") {
                        root.fanRpm = p.slice(1).map(Number)
                        if (root.fanRpm.length)
                            root.fanHist = root.fanHist.concat(root.fanRpm[0]).slice(-30)
                    }
                }
            }, 0, 9000)
    }

    function probeLab() {
        Proc.runCommand("fleetTile.lab",
            ["ssh", "-o", "ConnectTimeout=4", "-o", "BatchMode=yes", "claude-dev",
             "echo C $(head -1 /proc/stat); " +
             "echo M $(awk '/MemTotal|MemAvailable/{printf \"%s \", $2}' /proc/meminfo); " +
             "echo L $(cut -d\" \" -f1 /proc/loadavg); " +
             "echo K $(df -BG --output=pcent,used,size / 2>/dev/null | tail -1 | tr -d '%G')"],
            (stdout, exitCode) => {
                if (exitCode !== 0 || stdout.trim() === "") { root.labAlive = false; return }
                root.labAlive = true
                for (const line of stdout.trim().split("\n")) {
                    const p = line.trim().split(/\s+/)
                    if (p[0] === "C") {
                        const r = parseStat(p, root.labPrevI, root.labPrevT)
                        if (r.cpu >= 0) {
                            root.labCpu = r.cpu
                            root.labHist = root.labHist.concat(r.cpu).slice(-30)
                        }
                        root.labPrevI = r.idle; root.labPrevT = r.total
                    } else if (p[0] === "M" && p.length >= 3 && Number(p[1]) > 0) {
                        root.labMem = 100 * (1 - Number(p[2]) / Number(p[1]))
                        root.labMemHist = root.labMemHist.concat(root.labMem).slice(-30)
                        root.labMemTotalG = Number(p[1]) / 1048576
                        root.labMemUsedG = (Number(p[1]) - Number(p[2])) / 1048576
                    } else if (p[0] === "L" && p.length >= 2) {
                        root.labExtra = "load " + p[1]
                    } else if (p[0] === "K" && p.length >= 4) {
                        root.labDisk = Number(p[1])
                        root.labDiskUsed = p[2]
                        root.labDiskSize = p[3]
                    }
                }
            }, 0, 8000)
    }

    function probePower() {
        Proc.runCommand("fleetTile.power",
            ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", "claude-dev",
             "/home/jay/.local/bin/arch-glance"],
            (stdout, exitCode) => {
                if (exitCode !== 0) return
                try {
                    const j = JSON.parse(stdout)
                    root.wallW = j.wall !== null ? j.wall : -1
                    root.kwhToday = j.kwh !== null ? j.kwh : -1
                    root.plugState = j.switch || ""
                    if (j.wall !== null)
                        root.wallHist = root.wallHist.concat(j.wall).slice(-30)
                } catch (e) {}
            }, 0, 12000)
    }

    function wakeArch() {
        root.archWaking = true
        Proc.runCommand("fleetTile.wake",
            ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", "claude-dev",
             "wakeonlan a8:a1:59:e8:29:19"],
            (stdout, exitCode) => {}, 0, 8000)
        wakeReset.restart()
    }
    Timer { id: wakeReset; interval: 90000; onTriggered: root.archWaking = false }

    Timer {
        interval: 12000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: { root.probeDvm(); root.probeArch(); root.probeLab() }
    }
    Timer {
        interval: 30000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: root.probePower()
    }

    // ── bar pill: the resident host
    horizontalBarPill: Component {
        Item {
            implicitWidth: fleetRow.implicitWidth
            implicitHeight: fleetRow.implicitHeight

            Row {
                id: fleetRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: root.resident === "arch" ? "desktop_windows" : "dns"
                    size: root.iconSize
                    color: root.resAlive ? Theme.widgetIconColor : Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: root.resident
                    color: Theme.primary
                    font.pixelSize: 8
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    spacing: 1
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.resAlive
                    StyledText { text: "cpu"; color: Theme.surfaceVariantText; font.pixelSize: 8 }
                    StyledText { text: "ram"; color: Theme.surfaceVariantText; font.pixelSize: 8 }
                }
                Column {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.resAlive
                    MeterBar { value: root.resCpu; okColor: Theme.primary; implicitWidth: 44 }
                    MeterBar { value: root.resMem; okColor: Theme.primary; implicitWidth: 44 }
                }
                Column {
                    spacing: 1
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.resAlive
                    StyledText { text: Math.round(root.resCpu) + "%"; color: Theme.widgetTextColor; font.pixelSize: 8; horizontalAlignment: Text.AlignRight; width: 22 }
                    StyledText { text: Math.round(root.resMem) + "%"; color: Theme.widgetTextColor; font.pixelSize: 8; horizontalAlignment: Text.AlignRight; width: 22 }
                }
                StyledText {
                    text: root.resAlive ? root.resExtra : "off"
                    color: root.resAlive ? Theme.widgetTextColor : Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // ── popout
    popoutContent: Component {
        PopoutComponent {
            headerText: "fleet"
            detailsText: "right-click the pill to flip resident"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingS

                component ResDot: Rectangle {
                    property string key
                    width: 10; height: 10; radius: 5
                    color: root.resident === key ? Theme.primary : "transparent"
                    border.color: root.resident === key ? Theme.primary : Theme.surfaceVariantText
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        onClicked: root.setResident(parent.key)
                    }
                }
                component HostHeader: Row {
                    property string key
                    property string label
                    property bool alive
                    property string tail: ""
                    spacing: Theme.spacingS
                    width: parent.width
                    ResDot { key: parent.key }
                    StyledText { text: label; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { width: 7; height: 7; radius: 4; color: alive ? "#4ade80" : "#ef4444"; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: tail; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; anchors.verticalCenter: parent.verticalCenter }
                }
                component VRow: Row {
                    property string label
                    property real val: -1
                    property var hist: []
                    property string valueText
                    property color tone: Theme.primary
                    property var sMin: 0
                    property var sMax: 100
                    spacing: Theme.spacingS
                    width: parent.width
                    StyledText { text: label; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 30; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        spacing: 2
                        anchors.verticalCenter: parent.verticalCenter
                        MeterBar { visible: val >= 0; value: val; okColor: tone; warnLevel: 101; implicitWidth: parent.parent.width - 128; implicitHeight: 4 }
                        Spark { visible: hist.length > 1; values: hist; lineColor: tone; area: false; minValue: sMin; maxValue: sMax; implicitWidth: parent.parent.width - 128; implicitHeight: 13; stroke: 1.2 }
                    }
                    StyledText { text: valueText; color: tone; font.pixelSize: Theme.fontSizeSmall; width: 82; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                }

                // ── docker-vm: aggregate
                Tile {
                    HostHeader { key: "dvm"; label: "docker-vm"; alive: root.dvmAlive; tail: root.dvmAlive ? root.dvmExtra + " containers" : "unreachable" }
                    VRow { label: "cpu"; val: root.dvmCpu; hist: root.dvmHist; valueText: Math.round(root.dvmCpu) + "%"; tone: Theme.primary; visible: root.dvmAlive }
                    VRow { label: "ram"; val: root.dvmMem; hist: root.dvmMemHist; valueText: root.dvmMemUsedG.toFixed(1) + "/" + root.dvmMemTotalG.toFixed(0) + "G"; tone: Theme.secondary; visible: root.dvmAlive }
                    VRow { label: "dsk"; val: root.dvmDisk; valueText: root.dvmDiskUsed + "/" + root.dvmDiskSize + "G"; tone: root.cFan; visible: root.dvmAlive && root.dvmDisk >= 0 }
                }

                // ── archbox: the instrument panel
                Tile {
                    HostHeader {
                        key: "arch"; label: "archbox"; alive: root.archAlive
                        tail: root.archAlive ? "up " + root.archUp + " · plug " + (root.plugState || "?") : "asleep · plug " + (root.plugState || "?")
                    }

                    Tile {
                        visible: root.archAlive
                        heading: "CPU"
                        headingColor: Theme.surfaceVariantText
                        bg: Qt.rgba(0, 0, 0, 0.18)
                        borderTint: Qt.rgba(1, 1, 1, 0.05)
                    VRow { label: "cpu"; val: root.archCpu; hist: root.archHist; valueText: Math.round(root.archCpu) + "%"; tone: Theme.primary }
                    VRow { label: "ram"; val: root.archMem; valueText: root.archMemUsedG.toFixed(1) + "/" + root.archMemTotalG.toFixed(0) + "G"; tone: Theme.secondary }

                    // cores — 32 threads, 4-col grid, spark + util + clock
                    Grid {
                        visible: root.archAlive && root.aCoreUtil.length > 0
                        columns: 4
                        columnSpacing: 8
                        rowSpacing: 3
                        width: parent.width
                        Repeater {
                            model: root.aCoreUtil.length
                            delegate: Row {
                                required property int index
                                spacing: 2
                                StyledText { text: "c" + index; color: Theme.surfaceVariantText; font.pixelSize: 8; width: 16; anchors.verticalCenter: parent.verticalCenter }
                                Spark {
                                    values: root.aCoreHist[index] || []
                                    lineColor: Theme.primary
                                    area: false
                                    minValue: 0; maxValue: 100
                                    implicitWidth: 20; implicitHeight: 10; stroke: 1
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: Math.round(root.aCoreUtil[index] || 0) + "%"
                                    color: Theme.surfaceText; font.pixelSize: 8; width: 22
                                    horizontalAlignment: Text.AlignRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: (root.aCoreFreq[index] || 0).toFixed(2)
                                    color: Theme.surfaceVariantText; font.pixelSize: 8; width: 26
                                    horizontalAlignment: Text.AlignRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    }

                    // 3090
                    Tile {
                        visible: root.archAlive
                        heading: "GPU · 3090 iCX3"
                        headingColor: Theme.surfaceVariantText
                        bg: Qt.rgba(0, 0, 0, 0.18)
                        borderTint: Qt.rgba(1, 1, 1, 0.05)
                    VRow { label: "gpu"; val: root.gpuU; hist: root.gpuUHist; valueText: root.gpuU + "%"; tone: root.cGpu; visible: root.gpuU >= 0 }
                    VRow {
                        label: "vram"; val: root.vramTotal > 0 ? root.vramUsed / root.vramTotal * 100 : -1
                        valueText: root.vramTotal > 0 ? (root.vramUsed / 1024).toFixed(1) + "/" + (root.vramTotal / 1024).toFixed(0) + "G" : "—"
                        tone: root.cVram; visible: root.vramTotal > 0
                    }
                    VRow {
                        label: "die"; hist: root.gpuTHist; valueText: root.gpuT + "° / " + (root.icxGpu2 >= 0 ? root.icxGpu2.toFixed(0) + "°" : "—")
                        tone: root.cDie; visible: root.gpuT >= 0
                        sMin: root.gpuTHist.length ? Math.min(...root.gpuTHist) - 2 : 20
                        sMax: root.gpuTHist.length ? Math.max(...root.gpuTHist) + 2 : 90
                    }
                    VRow {
                        label: "vrT"; hist: root.icxVramHist
                        valueText: (root.icxVram >= 0 ? root.icxVram.toFixed(0) : "—") + "°"
                        tone: root.cVram; visible: root.icxVram >= 0
                        sMin: root.icxVramHist.length ? Math.min(...root.icxVramHist) - 2 : 20
                        sMax: root.icxVramHist.length ? Math.max(...root.icxVramHist) + 2 : 90
                    }
                    Row {
                        spacing: Theme.spacingM
                        width: parent.width
                        StyledText { text: "mem̄ " + (root.icxMemAvg >= 0 ? root.icxMemAvg.toFixed(1) + "°" : "—"); color: root.cMem; font.pixelSize: Theme.fontSizeSmall }
                        StyledText { text: "vrm̄ " + (root.icxPwrAvg >= 0 ? root.icxPwrAvg.toFixed(1) + "°" : "—"); color: root.cVrm; font.pixelSize: Theme.fontSizeSmall }
                        StyledText {
                            text: "fans " + (root.fanRpm.length ? root.fanRpm.join(" / ") : "—")
                            color: root.cFan; font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    }

                    // power
                    Tile {
                        heading: "POWER"
                        headingColor: Theme.surfaceVariantText
                        bg: Qt.rgba(0, 0, 0, 0.18)
                        borderTint: Qt.rgba(1, 1, 1, 0.05)
                    VRow {
                        label: "wall"; hist: root.wallHist
                        valueText: (root.wallW >= 0 ? root.wallW.toFixed(0) : "—") + "W"
                        tone: root.cWall
                        sMin: 0
                        sMax: root.wallHist.length ? Math.max(...root.wallHist) + 50 : 700
                    }
                    VRow {
                        label: "gW"; hist: root.gpuPowHist
                        valueText: (root.gpuPow >= 0 ? root.gpuPow.toFixed(0) : "—") + "W"
                        tone: root.cGpuPow; visible: root.gpuPow >= 0
                        sMin: 0
                        sMax: root.gpuPowHist.length ? Math.max(...root.gpuPowHist) + 30 : 450
                    }
                    StyledText {
                        text: "today " + (root.kwhToday >= 0 ? root.kwhToday.toFixed(2) + " kWh" : "—")
                              + (root.archAlive && root.wallW >= 0 && root.gpuPow >= 0 ? " · non-gpu " + (root.wallW - root.gpuPow).toFixed(0) + "W" : "")
                        color: root.cWall; font.pixelSize: Theme.fontSizeSmall
                    }
                    }

                    Rectangle {
                        visible: !root.archAlive
                        width: parent.width; height: 34
                        radius: 8
                        color: root.archWaking ? Qt.rgba(0.98, 0.75, 0.14, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: root.archWaking ? "#fbbf24" : Theme.primary
                        border.width: 1
                        StyledText {
                            text: root.archWaking ? "waking…" : "WAKE"
                            color: root.archWaking ? "#fbbf24" : Theme.primary
                            font.pixelSize: 12; font.weight: Font.Bold
                            anchors.centerIn: parent
                        }
                        MouseArea { anchors.fill: parent; enabled: !root.archWaking; onClicked: root.wakeArch() }
                    }
                }

                // ── claude-dev: aggregate
                Tile {
                    HostHeader { key: "111"; label: "claude-dev"; alive: root.labAlive; tail: root.labAlive ? root.labExtra : "unreachable" }
                    VRow { label: "cpu"; val: root.labCpu; hist: root.labHist; valueText: Math.round(root.labCpu) + "%"; tone: Theme.primary; visible: root.labAlive }
                    VRow { label: "ram"; val: root.labMem; hist: root.labMemHist; valueText: root.labMemUsedG.toFixed(1) + "/" + root.labMemTotalG.toFixed(0) + "G"; tone: Theme.secondary; visible: root.labAlive }
                    VRow { label: "dsk"; val: root.labDisk; valueText: root.labDiskUsed + "/" + root.labDiskSize + "G"; tone: root.cFan; visible: root.labAlive && root.labDisk >= 0 }
                }

                StyledText {
                    text: "pin a host — it becomes the bar pill"
                    color: Theme.surfaceVariantText
                    font.pixelSize: 9
                }
            }
        }
    }
    popoutWidth: 480
    popoutHeight: 1040

    // headless popout toggle: qs -c dms ipc call popout-fleet toggle
    IpcHandler {
        target: "popout-fleet"
        function toggle(): string { root.triggerPopout(); return "ok" }
    }
}
