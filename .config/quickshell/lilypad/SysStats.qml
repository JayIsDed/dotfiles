// SysStats.qml — CPU% / mem% / hottest core, portable across hosts.
// One shell probe every 2s; archbox later swaps in NVML/iCX3 widgets beside it.
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    spacing: 10

    property real cpu: 0
    property real mem: 0
    property int temp: 0
    property var lastIdle: 0
    property var lastTotal: 0

    Process {
        id: probe
        command: ["sh", "-c",
            "head -1 /proc/stat; " +
            "awk '/MemTotal|MemAvailable/{print $2}' /proc/meminfo; " +
            "cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | sort -rn | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                // cpu line: cpu user nice system idle iowait ...
                const f = lines[0].trim().split(/\s+/).slice(1).map(Number)
                const idle = f[3] + (f[4] || 0)
                const total = f.reduce((a, b) => a + b, 0)
                if (root.lastTotal > 0 && total > root.lastTotal) {
                    const dt = total - root.lastTotal
                    root.cpu = 100 * (1 - (idle - root.lastIdle) / dt)
                }
                root.lastIdle = idle
                root.lastTotal = total
                if (lines.length >= 3) {
                    const memTotal = Number(lines[1]), memAvail = Number(lines[2])
                    if (memTotal > 0) root.mem = 100 * (1 - memAvail / memTotal)
                }
                if (lines.length >= 4) root.temp = Math.round(Number(lines[3]) / 1000)
            }
        }
    }
    Timer {
        interval: 2000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    component Stat: RowLayout {
        spacing: 4
        property string icon
        property string value
        property color tone: Theme.text2
        Text { text: icon; color: tone; font.family: Theme.font; font.pixelSize: Theme.fontSize }
        Text { text: value; color: Theme.text2; font.family: Theme.font; font.pixelSize: Theme.fontSize }
    }

    Stat { icon: ""; value: Math.round(root.cpu) + "%"; tone: root.cpu > 85 ? Theme.red : Theme.blue }
    Stat { icon: ""; value: Math.round(root.mem) + "%"; tone: root.mem > 85 ? Theme.amber : Theme.purple }
    Stat { icon: ""; value: root.temp + "°"; tone: root.temp > 85 ? Theme.red : Theme.green }
}
