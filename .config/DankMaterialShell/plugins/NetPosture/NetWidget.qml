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

    property var latHist: []

    function probeLink() {
        // --rescan no is LOAD-BEARING: default auto requests real scans,
        // each one polkit-gated → the fingerprint popup storm Jay hit at
        // work. Reading the ACTIVE ssid never needs a scan.
        Proc.runCommand("netPosture.link",
            ["sh", "-c",
             "nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | grep -m1 -E '^(wifi|ethernet):connected:'; " +
             "nmcli -t -f active,ssid dev wifi list --rescan no 2>/dev/null | grep -m1 '^yes:'"],
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
            }, 0, 4000)
    }

    function probeTs() {
        Proc.runCommand("netPosture.ts",
            ["sh", "-c",
             "tailscale status --json 2>/dev/null | grep -m1 BackendState; " +
             "ip route show default 2>/dev/null | head -1; " +
             "test -e /sys/class/net/proton && echo PROTON; " +
             "ping -c1 -W1 192.168.8.111 2>/dev/null | grep -o 'time=[0-9.]*'"],
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
                spacing: Theme.spacingM

                StyledText { text: "ssid  " + root.ssid; color: root.tsColor; font.pixelSize: Theme.fontSizeLarge }
                StyledText {
                    text: "posture  " + (root.tsMode === "home" ? "home (LAN direct)" : root.tsMode === "away" ? "away (tunnel + vpn)" : root.tsMode === "lost" ? "away? (no vpn seen)" : "tailscale OFF")
                    color: root.tsColor
                    font.pixelSize: Theme.fontSizeLarge
                }
                StyledText { text: "homelab rtt  " + (root.lat || "unreachable"); color: Theme.surfaceText; font.pixelSize: Theme.fontSizeLarge }
                Spark {
                    values: root.latHist
                    lineColor: root.tsColor
                    minValue: 0
                    implicitWidth: 260
                    implicitHeight: 30
                    stroke: 2
                }
                StyledText { text: "rtt history · 10s ticks · autoscale from 0"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
            }
        }
    }
    popoutWidth: 320
    popoutHeight: 280

    // headless popout toggle: qs -c dms ipc call popout-net toggle
    IpcHandler {
        target: "popout-net"
        function toggle(): string { root.triggerPopout(); return "ok" }
    }
}
