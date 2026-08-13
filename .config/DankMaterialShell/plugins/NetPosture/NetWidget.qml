// NetWidget.qml — lilypad's network chip as a dms plugin: SSID wears the
// tailscale-posture color (green home / blue away / amber off-or-lost),
// house at home vs tunnel-lock away, homelab RTT beside. Fixed status hues
// on purpose — posture must read the same on every wallpaper.
import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string kind: "none"   // wifi | ethernet | none
    property string ssid: ""
    property string tsMode: ""     // home | away | lost | off
    property color tsColor: "#fbbf24"
    property string lat: ""
    property string localIp: ""
    property string tsIp: ""

    property var latHist: []
    property real rxRate: -1      // B/s
    property real txRate: -1
    property var rxHist: []
    property var txHist: []
    property int sigDbm: 0        // 0 = unknown
    property real prevRx: -1
    property real prevTx: -1
    property real prevStamp: 0

    function fmtRate(bps) {
        if (bps < 0) return "—"
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s"
        if (bps >= 1024) return (bps / 1024).toFixed(0) + " KB/s"
        return Math.round(bps) + " B/s"
    }

    function probeLink() {
        // --rescan no is LOAD-BEARING: default auto requests real scans,
        // each one polkit-gated → the fingerprint popup storm Jay hit at
        // work. Reading the ACTIVE ssid never needs a scan.
        // RXTX rides the default-route iface; /proc/net/wireless row 3 is
        // the signal level in dBm (kernel-maintained, no scan, no polkit).
        Proc.runCommand("netPosture.link",
            ["sh", "-c",
             "nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | grep -m1 -E '^(wifi|ethernet):connected:'; " +
             "nmcli -t -f active,ssid dev wifi list --rescan no 2>/dev/null | grep -m1 '^yes:'; " +
             "IF=$(ip route get 1.1.1.1 2>/dev/null | sed -n 's/.*dev \\([^ ]*\\).*/\\1/p' | head -1); " +
             "[ -n \"$IF\" ] && echo RXTX $(cat /sys/class/net/$IF/statistics/rx_bytes /sys/class/net/$IF/statistics/tx_bytes 2>/dev/null | tr '\\n' ' '); " +
             "awk 'NR>2 {gsub(/\\./,\"\",$4); print \"SIG\", $4; exit}' /proc/net/wireless 2>/dev/null"],
            (stdout, exitCode) => {
                const lines = stdout.trim().split("\n")
                const parts = (lines[0] ?? "").split(":")
                if (parts.length >= 3 && parts[1] === "connected") {
                    root.kind = parts[0] === "wifi" ? "wifi" : "ethernet"
                    root.ssid = parts.slice(2).join(":")
                } else {
                    root.kind = "none"
                    root.ssid = "offline"
                }
                const ssidLine = lines.find(l => l.startsWith("yes:"))
                if (root.kind === "wifi" && ssidLine)
                    root.ssid = ssidLine.slice(4)

                const rt = stdout.match(/RXTX (\d+) (\d+)/)
                const now = Date.now() / 1000
                if (rt) {
                    const rx = Number(rt[1]), tx = Number(rt[2])
                    const dt = now - root.prevStamp
                    // counters reset on iface flap — only positive deltas count
                    if (root.prevRx >= 0 && dt > 0 && rx >= root.prevRx && tx >= root.prevTx) {
                        root.rxRate = (rx - root.prevRx) / dt
                        root.txRate = (tx - root.prevTx) / dt
                        root.rxHist = root.rxHist.concat(root.rxRate).slice(-30)
                        root.txHist = root.txHist.concat(root.txRate).slice(-30)
                    }
                    root.prevRx = rx; root.prevTx = tx; root.prevStamp = now
                }
                const sg = stdout.match(/SIG (-?\d+)/)
                root.sigDbm = sg ? Number(sg[1]) : 0
            }, 0, 4000)
    }

    function probeTs() {
        Proc.runCommand("netPosture.ts",
            ["sh", "-c",
             "tailscale status --json 2>/dev/null | grep -m1 BackendState; " +
             "ip route show default 2>/dev/null | head -1; " +
             "test -e /sys/class/net/proton && echo PROTON; " +
             "ping -c1 -W1 192.168.8.111 2>/dev/null | grep -o 'time=[0-9.]*'; " +
             "echo LOCALIP $(ip route get 1.1.1.1 2>/dev/null | grep -o 'src [0-9.]*' | cut -d' ' -f2); " +
             "echo TSIP $(tailscale ip -4 2>/dev/null | head -1)"],
            (stdout, exitCode) => {
                const t = stdout
                const running = t.indexOf("\"Running\"") >= 0
                const home = t.indexOf("via 192.168.8.") >= 0
                const vpn = t.indexOf("PROTON") >= 0
                if (!running)      { root.tsMode = "off";  root.tsColor = "#fbbf24" }
                else if (home)     { root.tsMode = "home"; root.tsColor = "#4ade80" }
                else if (vpn)      { root.tsMode = "away"; root.tsColor = "#60a5fa" }
                else               { root.tsMode = "lost"; root.tsColor = "#fbbf24" }
                const m = t.match(/time=([0-9.]+)/)
                root.lat = m ? Math.round(Number(m[1])) + "ms" : ""
                if (m) root.latHist = root.latHist.concat(Number(m[1])).slice(-30)
                const li = t.match(/LOCALIP ([0-9.]+)/)
                root.localIp = li ? li[1] : ""
                const ti = t.match(/TSIP ([0-9.]+)/)
                root.tsIp = ti ? ti[1] : ""
            }, 0, 8000)
    }

    Timer {
        interval: 5000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: root.probeLink()
    }
    Timer {
        interval: 10000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: root.probeTs()
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: netRow.implicitWidth
            implicitHeight: netRow.implicitHeight

            Row {
                id: netRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: root.kind === "wifi" ? "wifi" : root.kind === "ethernet" ? "lan" : "wifi_off"
                    size: root.iconSize
                    color: root.kind === "none" ? Theme.tempDanger : Theme.widgetIconColor
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: root.ssid
                    color: root.tsColor
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.kind === "wifi"
                }
                DankIcon {
                    name: root.tsMode === "home" ? "home" : "vpn_lock"
                    size: root.iconSize - 2
                    color: root.tsColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.tsMode !== ""
                }
                StyledText {
                    text: root.lat
                    color: root.tsColor
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.lat !== ""
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "network"
            detailsText: root.kind + " · tailscale " + (root.tsMode || "?")
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingS

                Tile {
                    heading: "LINK"
                    headingColor: Theme.surfaceVariantText
                    StyledText { text: root.ssid; color: root.tsColor; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Bold }
                    StyledText {
                        text: root.tsMode === "home" ? "home · LAN direct" : root.tsMode === "away" ? "away · tunnel + vpn" : root.tsMode === "lost" ? "away? · no vpn seen" : "tailscale OFF"
                        color: root.tsColor
                        font.pixelSize: Theme.fontSizeMedium
                    }
                    StyledText {
                        visible: root.sigDbm < 0
                        text: "signal " + root.sigDbm + " dBm · " + (root.sigDbm >= -55 ? "strong" : root.sigDbm >= -67 ? "good" : root.sigDbm >= -75 ? "fair" : "weak")
                        color: root.sigDbm >= -67 ? Theme.surfaceText : "#fbbf24"
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
                Tile {
                    heading: "FLOW"
                    headingColor: Theme.surfaceVariantText
                    component FlowRow: Row {
                        property string label
                        property var hist: []
                        property real rate: -1
                        property color tone: Theme.primary
                        spacing: Theme.spacingS
                        width: parent.width
                        StyledText { text: label; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 30; anchors.verticalCenter: parent.verticalCenter }
                        Spark {
                            framed: true
                            values: hist
                            lineColor: tone
                            area: false
                            minValue: 0
                            implicitWidth: parent.width - 116
                            implicitHeight: 20
                            stroke: 1.2
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText { text: root.fmtRate(rate); color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; width: 70; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                    }
                    FlowRow { label: "rx"; hist: root.rxHist; rate: root.rxRate }
                    FlowRow { label: "tx"; hist: root.txHist; rate: root.txRate; tone: Theme.secondary }
                    StyledText { text: "default-route iface · 5s ticks"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                }
                Tile {
                    heading: "HOMELAB"
                    headingColor: Theme.surfaceVariantText
                    Row {
                        spacing: Theme.spacingS
                        width: parent.width
                        StyledText { text: "rtt"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 30; anchors.verticalCenter: parent.verticalCenter }
                        Spark {
                            framed: true
                            values: root.latHist
                            lineColor: root.tsColor
                            area: false
                            minValue: 0
                            // floor the ceiling at 50ms so one outlier can't
                            // turn a flat healthy line into a cliff face
                            maxValue: root.latHist.length ? Math.max(50, Math.max(...root.latHist) * 1.15) : 50
                            implicitWidth: parent.width - 86
                            implicitHeight: 28
                            stroke: 1.5
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText { text: root.lat || "—"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; width: 40; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                    }
                    StyledText { text: "ping 111 · 10s ticks"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                }
                Tile {
                    heading: "ADDRESSES"
                    headingColor: Theme.surfaceVariantText
                    StyledText { text: "local   " + (root.localIp || "—"); color: Theme.surfaceText; font.pixelSize: Theme.fontSizeMedium }
                    StyledText { text: "tailnet " + (root.tsIp || "—"); color: Theme.surfaceText; font.pixelSize: Theme.fontSizeMedium }
                }
            }
        }
    }
    popoutWidth: 320
    popoutHeight: 460

    // headless popout toggle: qs -c dms ipc call popout-net toggle
    IpcHandler {
        target: "popout-net"
        function toggle(): string { root.triggerPopout(); return "ok" }
    }
}
