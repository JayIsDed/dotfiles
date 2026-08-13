// Network.qml — connectivity glance; click opens the connection editor.
// nmcli-polled v1; swap to Quickshell.Networking once its API is verified.
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

    Process {
        id: probe
        command: ["sh", "-c",
            "nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | grep -m1 ':connected:'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(":")
                if (parts.length >= 3 && parts[1] === "connected") {
                    root.kind = parts[0].includes("wireless") ? "wifi" : "ethernet"
                    root.label = parts.slice(2).join(":")
                } else {
                    root.kind = "none"
                    root.label = "offline"
                }
            }
        }
    }
    Timer {
        interval: 5000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Process { id: editor; command: ["nm-connection-editor"] }

    RowLayout {
        id: row
        spacing: 4
        Text {
            text: root.kind === "wifi" ? "󰖩" : root.kind === "ethernet" ? "󰈀" : "󰖪"
            color: root.kind === "none" ? Theme.red : Theme.text2
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
        Text {
            text: root.label
            color: Theme.text3
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            visible: root.kind === "wifi"
        }
    }
}
