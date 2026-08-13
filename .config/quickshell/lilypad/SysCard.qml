// SysCard.qml — host · kernel · uptime, persistent identity readout.
// Lives on the LEFT by the workspaces (Jay, design pass 3). Own slow probe:
// hostname/kernel are static, uptime ticks every 30s.
import Quickshell.Io
import QtQuick

Text {
    id: root
    property string host: ""
    property string kernel: ""
    property string up: ""

    text: host + " · " + kernel + " · " + up
    visible: host !== ""
    color: Theme.text3
    font.family: Theme.font
    font.pixelSize: Theme.fontSizeS

    function fmtUp(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600),
              m = Math.floor(s % 3600 / 60)
        return d > 0 ? d + "d" + h + "h" : h > 0 ? h + "h" + m + "m" : m + "m"
    }

    Process {
        id: probe
        command: ["sh", "-c",
            "echo $(cat /proc/sys/kernel/hostname) $(uname -r | cut -d- -f1) $(cut -d. -f1 /proc/uptime)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/)
                if (p.length >= 3) {
                    root.host = p[0]
                    root.kernel = p[1]
                    root.up = root.fmtUp(Number(p[2]))
                }
            }
        }
    }
    Timer {
        interval: 30000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
