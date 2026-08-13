// DvmWidget.qml — lilypad's DockerTile ported to a DMS plugin (trial seat).
// Same probe: one ssh to docker-services every 10s, cpu from successive
// /proc/stat samples, self-dims when the VM is unreachable.
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property real cpu: 0
    property real mem: 0
    property string containers: ""
    property var lastIdle: 0
    property var lastTotal: 0
    readonly property bool alive: containers !== ""

    function probe() {
        Proc.runCommand("dvmTile.probe",
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
                        if (root.lastTotal > 0 && total > root.lastTotal)
                            root.cpu = 100 * (1 - (idle - root.lastIdle) / (total - root.lastTotal))
                        root.lastIdle = idle
                        root.lastTotal = total
                    } else if (p[0] === "M" && p.length >= 3) {
                        if (Number(p[1]) > 0)
                            root.mem = 100 * (1 - Number(p[2]) / Number(p[1]))
                    } else if (p[0] === "D" && p.length >= 2) {
                        root.containers = p[1]
                    }
                }
            }, 0, 8000)
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.probe()
    }

    // NOTE: the pill Component is CONTENT inside dms's BasePill (chrome,
    // padding, hover all come free) — size via implicitWidth like their
    // built-in widgets, never draw your own pill rect (double chrome +
    // zero-width allocation = the overlap Jay caught)
    horizontalBarPill: Component {
        Item {
            implicitWidth: dvmRow.implicitWidth
            implicitHeight: dvmRow.implicitHeight

            Row {
                id: dvmRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "dns"
                    size: root.iconSize
                    color: root.alive ? Theme.widgetIconColor : Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: root.alive
                        ? Math.round(root.cpu) + "% " + Math.round(root.mem) + "% " + root.containers
                        : "off"
                    color: Theme.widgetTextColor
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "docker-vm"
            detailsText: "VM 202 · " + (root.alive ? root.containers + " containers running" : "unreachable")
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                StyledText {
                    text: "cpu  " + Math.round(root.cpu) + "%"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                }
                StyledText {
                    text: "ram  " + Math.round(root.mem) + "%"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                }
                StyledText {
                    text: "containers  " + root.containers
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                }
            }
        }
    }
    popoutWidth: 320
    popoutHeight: 220
}
