// FleetWidget.qml — the server fleet behind ONE bar pill (Jay 08-13):
// the pill shows the RESIDENT host (pin a host tile in the popout, or
// right-click the pill to cycle). Popout = one tile per host, each
// self-contained so any of them can graduate to its own bar pill later.
// Hosts: dvm (docker-vm, ssh) · arch (taichi, ssh + nvidia-smi, WAKE
// relay when asleep) · 111 (claude-dev). 12s cadence.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property var hostOrder: ["dvm", "arch", "111"]

    // ── dvm
    property bool dvmAlive: false
    property real dvmCpu: 0
    property real dvmMem: 0
    property string dvmExtra: ""
    property var dvmHist: []
    property var dvmPrevI: 0
    property var dvmPrevT: 0

    // ── arch
    property bool archAlive: false
    property bool archWaking: false
    property real archCpu: 0
    property real archMem: 0
    property int gpuU: -1
    property int gpuT: -1
    property string archUp: ""
    property var archHist: []
    property var archPrevI: 0
    property var archPrevT: 0

    // ── 111
    property bool labAlive: false
    property real labCpu: 0
    property real labMem: 0
    property string labExtra: ""
    property var labHist: []
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
             "echo D $(docker ps -q | wc -l)/$(docker ps -aq | wc -l)"],
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
                    } else if (p[0] === "D" && p.length >= 2) {
                        root.dvmExtra = p[1]
                    }
                }
            }, 0, 8000)
    }

    function probeArch() {
        Proc.runCommand("fleetTile.arch",
            ["ssh", "-o", "ConnectTimeout=4", "-o", "BatchMode=yes", "archbox",
             "echo C $(head -1 /proc/stat); " +
             "echo M $(awk '/MemTotal|MemAvailable/{printf \"%s \", $2}' /proc/meminfo); " +
             "echo U $(cut -d. -f1 /proc/uptime); " +
             "echo G $(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')"],
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
                    } else if (p[0] === "M" && p.length >= 3 && Number(p[1]) > 0) {
                        root.archMem = 100 * (1 - Number(p[2]) / Number(p[1]))
                    } else if (p[0] === "U" && p.length >= 2) {
                        root.archUp = fmtUp(Number(p[1]))
                    } else if (p[0] === "G" && p.length >= 2) {
                        const g = p[1].split(",")
                        root.gpuU = g.length >= 2 ? Number(g[0]) : -1
                        root.gpuT = g.length >= 2 ? Number(g[1]) : -1
                    }
                }
            }, 0, 8000)
    }

    function probeLab() {
        Proc.runCommand("fleetTile.lab",
            ["ssh", "-o", "ConnectTimeout=4", "-o", "BatchMode=yes", "claude-dev",
             "echo C $(head -1 /proc/stat); " +
             "echo M $(awk '/MemTotal|MemAvailable/{printf \"%s \", $2}' /proc/meminfo); " +
             "echo L $(cut -d\" \" -f1 /proc/loadavg)"],
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
                    } else if (p[0] === "L" && p.length >= 2) {
                        root.labExtra = "load " + p[1]
                    }
                }
            }, 0, 8000)
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

    // ── popout: one tile per host, pin = resident
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
                    spacing: Theme.spacingS
                    width: parent.width
                    ResDot { key: parent.key }
                    StyledText { text: label; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { width: 7; height: 7; radius: 4; color: alive ? "#4ade80" : "#ef4444"; anchors.verticalCenter: parent.verticalCenter }
                }
                component LoadRow: Row {
                    property string label
                    property real val
                    property color tone: Theme.primary
                    spacing: Theme.spacingS
                    width: parent.width
                    StyledText { text: label; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 28; anchors.verticalCenter: parent.verticalCenter }
                    MeterBar { value: val; okColor: tone; implicitWidth: parent.width - 84; implicitHeight: 5; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: Math.round(val) + "%"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; width: 40; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                }

                Tile {
                    HostHeader { key: "dvm"; label: "docker-vm"; alive: root.dvmAlive }
                    LoadRow { label: "cpu"; val: root.dvmCpu }
                    LoadRow { label: "ram"; val: root.dvmMem; tone: Theme.secondary }
                    Spark { visible: root.dvmHist.length > 1; values: root.dvmHist; lineColor: Theme.primary; area: false; minValue: 0; maxValue: 100; implicitWidth: parent.width; implicitHeight: 14; stroke: 1 }
                    StyledText { text: root.dvmAlive ? root.dvmExtra + " containers" : "unreachable"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                }

                Tile {
                    HostHeader { key: "arch"; label: "archbox"; alive: root.archAlive }
                    LoadRow { visible: root.archAlive; label: "cpu"; val: root.archCpu }
                    LoadRow { visible: root.archAlive; label: "ram"; val: root.archMem; tone: Theme.secondary }
                    LoadRow { visible: root.archAlive && root.gpuU >= 0; label: "gpu"; val: root.gpuU }
                    Spark { visible: root.archAlive && root.archHist.length > 1; values: root.archHist; lineColor: Theme.primary; area: false; minValue: 0; maxValue: 100; implicitWidth: parent.width; implicitHeight: 14; stroke: 1 }
                    StyledText {
                        visible: root.archAlive
                        text: "3090 " + (root.gpuT >= 0 ? root.gpuT + "°" : "—") + " · up " + root.archUp
                        color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall
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

                Tile {
                    HostHeader { key: "111"; label: "claude-dev"; alive: root.labAlive }
                    LoadRow { label: "cpu"; val: root.labCpu }
                    LoadRow { label: "ram"; val: root.labMem; tone: Theme.secondary }
                    Spark { visible: root.labHist.length > 1; values: root.labHist; lineColor: Theme.primary; area: false; minValue: 0; maxValue: 100; implicitWidth: parent.width; implicitHeight: 14; stroke: 1 }
                    StyledText { text: root.labAlive ? root.labExtra : "unreachable"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                }

                StyledText {
                    text: "pin a host — it becomes the bar pill"
                    color: Theme.surfaceVariantText
                    font.pixelSize: 9
                }
            }
        }
    }
    popoutWidth: 330
    popoutHeight: 560

    // headless popout toggle: qs -c dms ipc call popout-fleet toggle
    IpcHandler {
        target: "popout-fleet"
        function toggle(): string { root.triggerPopout(); return "ok" }
    }
}
