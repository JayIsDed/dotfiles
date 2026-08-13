// DockerTile.qml — docker-vm (VM 202) vitals on the bar: host cpu/ram plus
// running/total container count. One ssh probe every 10s (BatchMode, short
// timeout); hides itself entirely when the VM is unreachable (away with
// tailscale down, VM off). Replaces the old 45/45-only chip.
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    spacing: 8

    property real cpu: 0
    property real mem: 0
    property string containers: ""
    property var lastIdle: 0
    property var lastTotal: 0
    // parents must bind THIS, not .visible — reading a child's visible gives
    // effective visibility, which deadlocks once the parent hides
    readonly property bool alive: containers !== ""

    visible: alive

    component Lbl: Text {
        color: Theme.text3
        font.family: Theme.font
        font.pixelSize: 10
    }

    Process {
        id: probe
        command: ["ssh", "-o", "ConnectTimeout=4", "-o", "BatchMode=yes", "docker-services",
            "echo C $(head -1 /proc/stat); " +
            "echo M $(awk '/MemTotal|MemAvailable/{printf \"%s \", $2}' /proc/meminfo); " +
            "echo D $(docker ps -q | wc -l)/$(docker ps -aq | wc -l)"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "") { root.containers = ""; return }
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
                    } else if (p[0] === "D" && p.length >= 2) {
                        root.containers = p[1]
                    }
                }
            }
        }
    }
    Timer {
        interval: 10000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    ColumnLayout {
        spacing: 0
        Lbl { text: "cpu" }
        Lbl { text: "ram" }
    }
    ColumnLayout {
        spacing: Theme.meterGap
        MeterBar { value: root.cpu }
        MeterBar { value: root.mem }
    }
    ColumnLayout {
        spacing: 0
        Text {
            text: Math.round(root.cpu) + "%"
            color: Theme.text2; font.family: Theme.font; font.pixelSize: 11
            horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 34
        }
        Text {
            text: Math.round(root.mem) + "%"
            color: Theme.text2; font.family: Theme.font; font.pixelSize: 11
            horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 34
        }
    }
    ColumnLayout {
        spacing: 0
        Lbl { text: "dvm"; Layout.alignment: Qt.AlignHCenter }
        Text {
            text: root.containers
            color: Theme.text2
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeS
        }
    }
}
