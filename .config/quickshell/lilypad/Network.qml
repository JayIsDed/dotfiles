// Network.qml — connectivity + tunnel posture in one chip: SSID wears the
// tailscale-state color (green home / blue away / amber off-or-lost), then
// a house-or-tunnel glyph with the homelab RTT beside it. The standalone TS
// badge kept colliding with the system-controls tile from across the bundle
// gap, so it folded in here (Jay, 08-13). nmcli/tailscale polled; click
// opens the connection editor.
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    onClicked: editor.running = true

    property string kind: "none"   // wifi | ethernet | none
    property string label: ""
    property string tsMode: ""     // home | away | lost | off
    property color tsColor: Theme.text2
    property string lat: ""

    Process {
        id: probe
        command: ["sh", "-c",
            "nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | grep -m1 -E '^(wifi|ethernet):connected:'; " +
            "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep -m1 '^yes:'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const parts = (lines[0] ?? "").split(":")
                if (parts.length >= 3 && parts[1] === "connected") {
                    root.kind = parts[0] === "wifi" ? "wifi" : "ethernet"
                    root.label = parts.slice(2).join(":")
                } else {
                    root.kind = "none"
                    root.label = "offline"
                }
                // the actual over-the-air SSID beats the profile name
                const ssidLine = lines.find(l => l.startsWith("yes:"))
                if (root.kind === "wifi" && ssidLine)
                    root.label = ssidLine.slice(4)
            }
        }
    }
    Timer {
        interval: 5000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    // tailscale posture + homelab RTT (the ping rides the tunnel when away)
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
                if (!running)      { root.tsMode = "off";  root.tsColor = Theme.warn }
                else if (home)     { root.tsMode = "home"; root.tsColor = Theme.ok }
                else if (vpn)      { root.tsMode = "away"; root.tsColor = Theme.info }
                else               { root.tsMode = "lost"; root.tsColor = Theme.warn }
                const m = t.match(/time=([0-9.]+)/)
                root.lat = m ? Math.round(Number(m[1])) + "ms" : ""
            }
        }
    }
    Timer {
        interval: 10000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: tsProbe.running = true
    }

    Process { id: editor; command: ["nm-connection-editor"] }

    RowLayout {
        id: row
        spacing: 5
        Text {
            text: root.kind === "wifi" ? "󰖩" : root.kind === "ethernet" ? "󰈀" : "󰖪"
            color: root.kind === "none" ? Theme.red : Theme.text2
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
        Text {
            text: root.label
            color: root.tsColor
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            visible: root.kind === "wifi"
        }
        Text {
            text: root.tsMode === "home" ? "󰋜" : "󰖂"
            color: root.tsColor
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            visible: root.tsMode !== ""
        }
        Text {
            text: root.lat
            color: root.tsColor
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            visible: root.lat !== ""
        }
    }
}
