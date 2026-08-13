// MetricsCluster.qml — the always-on metrics run of the island (design brief
// v2: stacked meters, glanceable, never stale). Segment order (Jay, 22:30):
// cpu/ram (icon + hue differentiated) | temp sparkline | claude 5h/7d
// (primary/tertiary hues, 50% fable tick) | net rx/tx sparks + rates |
// tailscale badge | sys card. Brightness moved out to BrightnessChip (lives
// by the battery). Metric hues pin per-metric and hand over to warn/crit
// at thresholds. Three probes: 2s system, 10s tailscale, 180s claude relay.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    spacing: 8

    // metric tile — full bar-height sibling of Bar's Tile, near-black glass
    component Seg: Rectangle {
        default property alias content: inner.data
        implicitWidth: inner.implicitWidth + 24
        implicitHeight: Theme.barHeight
        radius: Theme.islandRadius
        color: Theme.alpha(Theme.tileBase, Theme.islandAlpha)
        border.color: Theme.border
        border.width: 1
        RowLayout {
            id: inner
            anchors.centerIn: parent
            spacing: 8
        }
    }
    // right-aligned percent readout, width reserved so pills don't breathe
    component Pct: Text {
        color: Theme.text2
        font.family: Theme.font
        font.pixelSize: 11
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 34
    }
    // fixed centered box so stacked icons align regardless of glyph width
    // (nerd glyphs mix single- and double-cell advances)
    component MiniIcon: Text {
        color: Theme.text3
        font.family: Theme.font
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Layout.preferredWidth: 18
        Layout.maximumWidth: 18
        Layout.preferredHeight: 9
    }

    property real cpu: 0
    property real mem: 0
    property int disk: -1
    property int fan: 0
    property var fanHist: []
    property string lat: ""
    property int temp: 0
    property var tempHist: []
    property var lastIdle: 0
    property var lastTotal: 0
    property string host: ""
    property string kernel: ""
    property string up: ""
    property var rxHist: []
    property var txHist: []
    property string rxRate: ""
    property string txRate: ""
    property var lastRx: -1
    property var lastTx: -1
    property double lastNetMs: 0
    property string tsLabel: ""
    property color tsColor: Theme.text2
    property real cu5: -1
    property real cu7: -1

    function fmtRate(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + "M"
        return Math.round(bps / 1024) + "K"
    }
    function fmtUp(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600),
              m = Math.floor(s % 3600 / 60)
        return d > 0 ? d + "d" + h + "h" : h > 0 ? h + "h" + m + "m" : m + "m"
    }

    // ---- probe 1: system, every 2s. Prefix-tagged lines; order-independent.
    Process {
        id: sysProbe
        command: ["sh", "-c",
            "echo C $(head -1 /proc/stat); " +
            "echo M $(awk '/MemTotal|MemAvailable/{printf \"%s \", $2}' /proc/meminfo); " +
            "echo T $(cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | sort -rn | head -1); " +
            "echo N $(awk 'NR>2 {sub(/^ +/,\"\"); split($0,a,/[: ]+/); if (a[1]!=\"lo\") {rx+=a[2]; tx+=a[10]}} END {print rx+0, tx+0}' /proc/net/dev); " +
            "echo D $(df --output=pcent / 2>/dev/null | tail -1 | tr -d ' %'); " +
            "echo F $(cat /sys/class/hwmon/hwmon*/fan1_input 2>/dev/null | head -1); " +
            "echo U $(cut -d. -f1 /proc/uptime) $(cat /proc/sys/kernel/hostname) $(uname -r)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const now = Date.now()
                for (const line of text.trim().split("\n")) {
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
                    } else if (p[0] === "N" && p.length >= 3) {
                        const rx = Number(p[1]), tx = Number(p[2])
                        if (root.lastRx >= 0 && now > root.lastNetMs) {
                            const dt = (now - root.lastNetMs) / 1000
                            const rxB = Math.max(0, (rx - root.lastRx) / dt)
                            const txB = Math.max(0, (tx - root.lastTx) / dt)
                            root.rxRate = root.fmtRate(rxB)
                            root.txRate = root.fmtRate(txB)
                            root.rxHist = root.rxHist.concat(rxB).slice(-30)
                            root.txHist = root.txHist.concat(txB).slice(-30)
                        }
                        root.lastRx = rx; root.lastTx = tx; root.lastNetMs = now
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
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: sysProbe.running = true }

    // ---- probe 2: tailscale mode, every 10s
    Process {
        id: tsProbe
        command: ["sh", "-c",
            "tailscale status --json 2>/dev/null | grep -m1 BackendState; " +
            "ip route show default 2>/dev/null | head -1; " +
            "test -e /sys/class/net/proton && echo PROTON; " +
            "ping -c1 -W1 192.168.8.111 2>/dev/null | grep -o 'time=[0-9.]*'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text
                const running = t.indexOf("\"Running\"") >= 0
                const home = t.indexOf("via 192.168.8.") >= 0
                const vpn = t.indexOf("PROTON") >= 0
                if (!running)      { root.tsLabel = "󰖂 OFF";  root.tsColor = Theme.warn }
                else if (home)     { root.tsLabel = "󰖂 HOME"; root.tsColor = Theme.ok }
                else if (vpn)      { root.tsLabel = "󰖂 AWAY"; root.tsColor = Theme.info }
                else               { root.tsLabel = "󰖂 AWAY?"; root.tsColor = Theme.warn }
                // homelab RTT rides along (ping to 111 direct or via tunnel)
                const m = t.match(/time=([0-9.]+)/)
                root.lat = m ? Math.round(Number(m[1])) + "ms" : ""
            }
        }
    }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: tsProbe.running = true }

    // ---- probe 3: claude usage via 111 relay, every 3min
    Process {
        id: cuProbe
        command: ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes",
                  "claude-dev", "/home/jay/.local/bin/claude-usage"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    root.cu5 = j.five ? j.five.pct : -1
                    root.cu7 = j.seven ? j.seven.pct : -1
                } catch (e) { root.cu5 = -1; root.cu7 = -1 }
            }
        }
    }
    Timer { interval: 180000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: cuProbe.running = true }

    // ════ segments ════

    // cpu / ram — labeled like the claude pair, threshold colors (green->amber->red)
    Seg {
        Layout.alignment: Qt.AlignVCenter
        ColumnLayout {
            spacing: 0
            Text { text: "cpu"; color: Theme.text3; font.family: Theme.font; font.pixelSize: 10 }
            Text { text: "ram"; color: Theme.text3; font.family: Theme.font; font.pixelSize: 10 }
            Text { text: "dsk"; color: Theme.text3; font.family: Theme.font; font.pixelSize: 10; visible: root.disk >= 0 }
        }
        ColumnLayout {
            spacing: Theme.meterGap
            MeterBar { value: root.cpu }
            MeterBar { value: root.mem }
            MeterBar { value: root.disk; visible: root.disk >= 0 }
        }
        ColumnLayout {
            spacing: 0
            Pct { text: Math.round(root.cpu) + "%" }
            Pct { text: Math.round(root.mem) + "%" }
            Pct { text: root.disk + "%"; visible: root.disk >= 0 }
        }
    }

    // thermal — dual spark, icons | sparks | counts
    Seg {
        Layout.alignment: Qt.AlignVCenter
        ColumnLayout {
            spacing: 2
            MiniIcon { text: "󰔏" }
            MiniIcon { text: "󰈐" }
        }
        ColumnLayout {
            spacing: 2
            Spark {
                values: root.tempHist
                implicitHeight: 9
                // window hugs the observed range so a 3-degree drift still
                // draws a visible shape (a fixed 30-95 scale rendered it flat)
                minValue: root.tempHist.length ? Math.min(...root.tempHist) - 2 : 30
                maxValue: root.tempHist.length ? Math.max(...root.tempHist) + 2 : 95
                lineColor: root.temp >= 85 ? Theme.crit : root.temp >= 70 ? Theme.warn : Theme.ok
            }
            Spark {
                values: root.fanHist
                implicitHeight: 9
                minValue: 0
                maxValue: root.fanHist.length ? Math.max(...root.fanHist) + 500 : 5000
                lineColor: Theme.purple
            }
        }
        ColumnLayout {
            spacing: 0
            Pct {
                text: root.temp + "°"
                color: root.temp >= 85 ? Theme.crit : root.temp >= 70 ? Theme.warn : Theme.text2
            }
            Pct { text: root.fan; visible: root.fan > 0 }
        }
    }

    // claude 5h / 7d — blue/purple, marker = fable ceiling
    Seg {
        Layout.alignment: Qt.AlignVCenter
        visible: root.cu5 >= 0
        ColumnLayout {
            spacing: 0
            Text { text: "5h"; color: Theme.text3; font.family: Theme.font; font.pixelSize: 10 }
            Text { text: "7d"; color: Theme.text3; font.family: Theme.font; font.pixelSize: 10 }
        }
        ColumnLayout {
            spacing: Theme.meterGap
            MeterBar {
                value: root.cu5
                fillColor: root.cu5 >= Theme.warnAt ? Theme.valueToColor(root.cu5) : Theme.info
            }
            MeterBar {
                value: root.cu7; marker: 50
                fillColor: root.cu7 >= Theme.warnAt ? Theme.valueToColor(root.cu7) : Theme.purple
            }
        }
        ColumnLayout {
            spacing: 0
            Pct { text: Math.round(root.cu5) + "%" }
            Pct { text: Math.round(root.cu7) + "%" }
        }
    }

    // net — same arrangement: icons | sparks | counts
    Seg {
        Layout.alignment: Qt.AlignVCenter
        ColumnLayout {
            spacing: 2
            MiniIcon { text: "󰇚" }
            MiniIcon { text: "󰕒" }
        }
        ColumnLayout {
            spacing: 2
            Spark { values: root.rxHist; implicitHeight: 9; minValue: 0 }
            Spark { values: root.txHist; implicitHeight: 9; minValue: 0; lineColor: Theme.purple }
        }
        ColumnLayout {
            spacing: 0
            Pct { text: root.rxRate }
            Pct { text: root.txRate }
        }
    }

    // tailscale badge
    Seg {
        Layout.alignment: Qt.AlignVCenter
        visible: root.tsLabel !== ""
        Text {
            text: root.tsLabel + (root.lat !== "" ? " · " + root.lat : "")
            color: root.tsColor
            font.family: Theme.font; font.pixelSize: Theme.fontSizeS
        }
    }

}
