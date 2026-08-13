// BatteryWidget.qml — battery % + lilypad's PowerDraw: signed wattage
// (+green charging / −blue discharging, fixed hues) over a 0-65W rate bar
// (X1C9 brick scale). BAT0 sysfs probe, 5s.
import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property int pct: -1
    property string status: ""
    property real watts: 0
    property var wattsHist: []
    readonly property bool alive: pct >= 0
    readonly property bool charging: status === "Charging"
    readonly property color polColor: charging ? "#4ade80" : "#60a5fa"

    function probe() {
        Proc.runCommand("batteryPower.probe",
            ["sh", "-c",
             "cat /sys/class/power_supply/BAT0/capacity /sys/class/power_supply/BAT0/status /sys/class/power_supply/BAT0/power_now 2>/dev/null"],
            (stdout, exitCode) => {
                const p = stdout.trim().split("\n")
                if (exitCode !== 0 || p.length < 3) { root.pct = -1; return }
                root.pct = Number(p[0])
                root.status = p[1]
                root.watts = Number(p[2]) / 1000000
                // signed history: charge above zero, draw below
                root.wattsHist = root.wattsHist.concat(
                    root.charging ? root.watts : -root.watts).slice(-60)
            }, 0, 4000)
    }

    Timer {
        interval: 5000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: root.probe()
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: batRow.implicitWidth
            implicitHeight: batRow.implicitHeight

            Row {
                id: batRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: root.charging ? "battery_charging_full" : "battery_full"
                    size: root.iconSize
                    color: root.alive && root.pct <= 20 && !root.charging ? Theme.tempDanger : Theme.widgetIconColor
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: root.alive ? root.pct + "%" : "—"
                    color: Theme.widgetTextColor
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.alive
                    StyledText {
                        text: (root.charging ? "+" : "−") + root.watts.toFixed(1) + "W"
                        color: root.polColor
                        font.pixelSize: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    MeterBar {
                        value: root.watts / 65 * 100
                        fillColor: root.polColor
                        implicitWidth: 40
                    }
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "battery"
            detailsText: root.status + " · TLP thresholds 75/80"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                StyledText { text: "charge  " + root.pct + "%"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeLarge }
                Row {
                    spacing: Theme.spacingS
                    StyledText { text: root.charging ? "+W" : "−W"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 34; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        spacing: 3
                        anchors.verticalCenter: parent.verticalCenter
                        MeterBar {
                            value: root.watts / 65 * 100
                            fillColor: root.polColor
                            implicitWidth: 190
                            implicitHeight: 5
                        }
                        Spark {
                            values: root.wattsHist
                            lineColor: root.polColor
                            area: false
                            implicitWidth: 190
                            implicitHeight: 22
                            stroke: 1.5
                        }
                    }
                    StyledText { text: root.watts.toFixed(1); color: root.polColor; font.pixelSize: Theme.fontSizeSmall; width: 44; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                }
                StyledText { text: "±W history · 5s ticks · rate bar 0–65 W (brick)"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
            }
        }
    }
    popoutWidth: 300
    popoutHeight: 220

    // headless popout toggle: qs -c dms ipc call popout-bat toggle
    IpcHandler {
        target: "popout-bat"
        function toggle(): string { root.triggerPopout(); return "ok" }
    }
}
