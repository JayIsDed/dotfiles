// DeckWidget.qml — the homelab living on the wallpaper layer. dvm vitals
// (ssh, 15s), homelab RTT + tailscale posture (15s). Glass card, gentle
// cadence — this is ambience, not a cockpit. Kit copies (MeterBar/Spark)
// ride along in this dir.
import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property var pluginService: null
    property string pluginId: ""
    property bool editMode: false
    property real widgetWidth: 320
    property real widgetHeight: 175
    property real minWidth: 240
    property real minHeight: 150

    // dvm
    property real cpu: 0
    property real mem: 0
    property string containers: ""
    property var cpuHist: []
    property var lastIdle: 0
    property var lastTotal: 0
    readonly property bool dvmAlive: containers !== ""

    // posture + rtt
    property string tsMode: ""
    property color tsColor: "#fbbf24"
    property string lat: ""
    property var latHist: []
    readonly property bool labAlive: lat !== ""

    function probeDvm() {
        Proc.runCommand("homelabDeck.dvm",
            ["ssh", "-o", "ConnectTimeout=4", "-o", "BatchMode=yes", "docker-services",
             "echo C $(head -1 /proc/stat); " +
             "echo M $(awk '/MemTotal|MemAvailable/{printf \"%s \", $2}' /proc/meminfo); " +
             "echo D $(docker ps -q | wc -l)/$(docker ps -aq | wc -l)"],
            (stdout, exitCode) => {
                if (exitCode !== 0 || stdout.trim() === "") {
                    root.containers = ""
                    return
                }
                for (const line of stdout.trim().split("\n")) {
                    const p = line.trim().split(/\s+/)
                    if (p[0] === "C") {
                        const f = p.slice(2).map(Number)
                        const idle = f[3] + (f[4] || 0)
                        const total = f.reduce((a, b) => a + b, 0)
                        if (root.lastTotal > 0 && total > root.lastTotal) {
                            root.cpu = 100 * (1 - (idle - root.lastIdle) / (total - root.lastTotal))
                            root.cpuHist = root.cpuHist.concat(root.cpu).slice(-40)
                        }
                        root.lastIdle = idle; root.lastTotal = total
                    } else if (p[0] === "M" && p.length >= 3) {
                        if (Number(p[1]) > 0) root.mem = 100 * (1 - Number(p[2]) / Number(p[1]))
                    } else if (p[0] === "D" && p.length >= 2) {
                        root.containers = p[1]
                    }
                }
            }, 0, 8000)
    }

    function probeNet() {
        Proc.runCommand("homelabDeck.net",
            ["sh", "-c",
             "tailscale status --json 2>/dev/null | grep -m1 BackendState; " +
             "ip route show default 2>/dev/null | head -1; " +
             "test -e /sys/class/net/proton && echo PROTON; " +
             "ping -c1 -W1 192.168.8.111 2>/dev/null | grep -o 'time=[0-9.]*'"],
            (stdout, exitCode) => {
                const t = stdout
                const running = t.indexOf("\"Running\"") >= 0
                const home = t.indexOf("via 192.168.8.") >= 0
                if (!running)      { root.tsMode = "off";  root.tsColor = "#fbbf24" }
                else if (home)     { root.tsMode = "home"; root.tsColor = "#4ade80" }
                else               { root.tsMode = "away"; root.tsColor = "#60a5fa" }
                const m = t.match(/time=([0-9.]+)/)
                root.lat = m ? Math.round(Number(m[1])) + "ms" : ""
                if (m) root.latHist = root.latHist.concat(Number(m[1])).slice(-40)
            }, 0, 8000)
    }

    Timer {
        interval: 15000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: { root.probeDvm(); root.probeNet() }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        opacity: 0.85
        border.color: root.editMode ? Theme.primary : "transparent"
        border.width: root.editMode ? 2 : 0
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        // header: name west, host dots east
        Item {
            width: parent.width
            height: 18
            StyledText {
                text: "homelab"
                color: Theme.surfaceText
                font.pixelSize: 13
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Rectangle { width: 8; height: 8; radius: 4; color: root.dvmAlive ? "#4ade80" : "#ef4444" }
                Rectangle { width: 8; height: 8; radius: 4; color: root.labAlive ? root.tsColor : "#ef4444" }
            }
        }

        // dvm cpu — bar + spark on the popout grid, scaled to card width
        Row {
            spacing: 6
            Text { text: "cpu"; color: Theme.surfaceVariantText; font.pixelSize: 10; width: 28; anchors.verticalCenter: parent.verticalCenter }
            Column {
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
                MeterBar { value: root.cpu; okColor: Theme.primary; implicitWidth: root.width - 110; implicitHeight: 4 }
                Spark { visible: cpuHist.length > 1; values: root.cpuHist; lineColor: Theme.primary; area: false; minValue: 0; maxValue: 100; implicitWidth: root.width - 110; implicitHeight: 14; stroke: 1.5 }
            }
            Text { text: Math.round(root.cpu) + "%"; color: Theme.surfaceText; font.pixelSize: 10; width: 32; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
        }
        Row {
            spacing: 6
            Text { text: "ram"; color: Theme.surfaceVariantText; font.pixelSize: 10; width: 28; anchors.verticalCenter: parent.verticalCenter }
            MeterBar { value: root.mem; okColor: Theme.secondary; implicitWidth: root.width - 110; implicitHeight: 4; anchors.verticalCenter: parent.verticalCenter }
            Text { text: Math.round(root.mem) + "%"; color: Theme.surfaceText; font.pixelSize: 10; width: 32; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
        }

        // homelab rtt spark, posture-tinted
        Row {
            spacing: 6
            Text { text: "rtt"; color: Theme.surfaceVariantText; font.pixelSize: 10; width: 28; anchors.verticalCenter: parent.verticalCenter }
            Spark { values: root.latHist; lineColor: root.tsColor; area: false; minValue: 0; implicitWidth: root.width - 110; implicitHeight: 18; stroke: 1.5; anchors.verticalCenter: parent.verticalCenter }
            Text { text: root.lat || "—"; color: root.tsColor; font.pixelSize: 10; width: 32; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
        }

        Text {
            text: (root.dvmAlive ? root.containers + " containers" : "dvm unreachable")
                  + " · " + (root.tsMode || "?")
            color: Theme.surfaceVariantText
            font.pixelSize: 10
        }
    }
}
