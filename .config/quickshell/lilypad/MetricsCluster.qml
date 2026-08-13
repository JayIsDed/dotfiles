// MetricsCluster.qml — the always-on metrics run of the island (design brief
// v2: stacked meters, glanceable, never stale). Segments: cpu/ram meters +
// temp | brightness (wheel to adjust) | net rx/tx sparks + rates | tailscale
// mode badge | sys card | claude 5h/7d (SSH relay to 111 where the creds
// live; hides itself if the relay is unreachable). Three probes: 2s system,
// 10s tailscale, 180s claude.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    spacing: 13

    property real cpu: 0
    property real mem: 0
    property int temp: 0
    property var lastIdle: 0
    property var lastTotal: 0
    property int bright: -1
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
            "echo B $(cat /sys/class/backlight/*/brightness 2>/dev/null) $(cat /sys/class/backlight/*/max_brightness 2>/dev/null); " +
            "echo N $(awk 'NR>2 {sub(/^ +/,\"\"); split($0,a,/[: ]+/); if (a[1]!=\"lo\") {rx+=a[2]; tx+=a[10]}} END {print rx+0, tx+0}' /proc/net/dev); " +
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
                    } else if (p[0] === "B" && p.length >= 3) {
                        root.bright = Math.round(100 * Number(p[1]) / Number(p[2]))
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
            "test -e /sys/class/net/proton && echo PROTON"]
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

    Process { id: brightSet }

    // ════ segments ════

    // cpu / ram stacked + temp
    ColumnLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: 3
        MeterBar { value: root.cpu }
        MeterBar { value: root.mem }
    }
    Text {
        Layout.alignment: Qt.AlignVCenter
        text: root.temp + "°"
        color: root.temp >= 85 ? Theme.crit : root.temp >= 70 ? Theme.warn : Theme.text2
        font.family: Theme.font; font.pixelSize: Theme.fontSize
    }

    // brightness — wheel to adjust (Item wrapper so the MouseArea overlays
    // instead of becoming a layout cell)
    Item {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: brightRow.implicitWidth
        implicitHeight: 24
        visible: root.bright >= 0
        RowLayout {
            id: brightRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Text { text: "󰃟"; color: Theme.text3; font.family: Theme.font; font.pixelSize: Theme.fontSize }
            Text { text: root.bright + "%"; color: Theme.text2; font.family: Theme.font; font.pixelSize: Theme.fontSize }
        }
        MouseArea {
            anchors.fill: parent
            onWheel: (w) => {
                brightSet.command = ["brightnessctl", "set", w.angleDelta.y > 0 ? "+5%" : "5%-"]
                brightSet.running = true
                root.bright = Math.min(100, Math.max(1, root.bright + (w.angleDelta.y > 0 ? 5 : -5)))
            }
        }
    }

    // net sparks + rates
    ColumnLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: 2
        Spark { values: root.rxHist; implicitHeight: 9; minValue: 0 }
        Spark { values: root.txHist; implicitHeight: 9; minValue: 0; lineColor: Theme.purple }
    }
    ColumnLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: 0
        Text { text: "󰇚" + root.rxRate; color: Theme.text3; font.family: Theme.font; font.pixelSize: Theme.fontSizeS }
        Text { text: "󰕒" + root.txRate; color: Theme.text3; font.family: Theme.font; font.pixelSize: Theme.fontSizeS }
    }

    // tailscale badge
    Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: tsText.implicitWidth + 14
        implicitHeight: 22
        radius: Theme.chipRadius
        color: Theme.l2
        border.color: Theme.l2Border
        border.width: 1
        Text {
            id: tsText
            anchors.centerIn: parent
            text: root.tsLabel
            color: root.tsColor
            font.family: Theme.font; font.pixelSize: Theme.fontSizeS
        }
        visible: root.tsLabel !== ""
    }

    // sys card: host · kernel · uptime
    Text {
        Layout.alignment: Qt.AlignVCenter
        text: root.host + " · " + root.kernel.split("-")[0] + " · " + root.up
        color: Theme.text3
        font.family: Theme.font; font.pixelSize: Theme.fontSizeS
        visible: root.host !== ""
    }

    // claude 5h / 7d (marker = fable ceiling)
    RowLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: 4
        visible: root.cu5 >= 0
        ColumnLayout {
            spacing: 0
            Text { text: "5h"; color: Theme.text3; font.family: Theme.font; font.pixelSize: 9 }
            Text { text: "7d"; color: Theme.text3; font.family: Theme.font; font.pixelSize: 9 }
        }
        ColumnLayout {
            spacing: 3
            MeterBar { value: root.cu5 }
            MeterBar { value: root.cu7; marker: 50 }
        }
    }
}
