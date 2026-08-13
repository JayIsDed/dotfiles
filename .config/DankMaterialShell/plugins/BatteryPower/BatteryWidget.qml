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
    property real health: -1
    property int cycles: -1
    property real energyNow: -1   // µWh
    property real energyFull: -1
    property var wattsHist: []

    // hours to empty (discharging) or full (charging), from the live draw
    readonly property real hoursLeft: {
        if (watts <= 0.5) return -1
        if (charging && energyFull > 0 && energyNow >= 0)
            return (energyFull - energyNow) / 1000000 / watts
        if (!charging && energyNow > 0)
            return energyNow / 1000000 / watts
        return -1
    }
    function fmtH(h) {
        if (h < 0) return ""
        const hh = Math.floor(h), mm = Math.round((h - hh) * 60)
        return (hh > 0 ? hh + "h" : "") + mm + "m"
    }
    readonly property bool alive: pct >= 0
    readonly property bool charging: status === "Charging"
    readonly property color polColor: charging ? "#4ade80" : "#60a5fa"

    function probe() {
        // keyed lines so a missing sysfs node can't shift the parse
        Proc.runCommand("batteryPower.probe",
            ["sh", "-c",
             "cd /sys/class/power_supply/BAT0 2>/dev/null && " +
             "for f in capacity status power_now energy_now energy_full energy_full_design charge_full charge_full_design cycle_count; do " +
             "v=$(cat $f 2>/dev/null); [ -n \"$v\" ] && echo $f=$v; done; true"],
            (stdout, exitCode) => {
                if (exitCode !== 0) { root.pct = -1; return }
                const kv = {}
                for (const line of stdout.trim().split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0) kv[line.slice(0, i)] = line.slice(i + 1)
                }
                if (kv.capacity === undefined) { root.pct = -1; return }
                root.pct = Number(kv.capacity)
                root.status = kv.status || ""
                root.watts = Number(kv.power_now || 0) / 1000000
                const full = Number(kv.energy_full || kv.charge_full || 0)
                const design = Number(kv.energy_full_design || kv.charge_full_design || 0)
                root.health = design > 0 ? full / design * 100 : -1
                root.energyNow = Number(kv.energy_now || -1)
                root.energyFull = full > 0 ? full : -1
                root.cycles = Number(kv.cycle_count || -1)
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
                spacing: Theme.spacingS

                Tile {
                    heading: "CHARGE"
                    headingColor: Theme.surfaceVariantText
                    Row {
                        spacing: Theme.spacingS
                        width: parent.width
                        StyledText { text: root.pct + "%"; color: Theme.surfaceText; font.pixelSize: 22; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: root.status.toLowerCase(); color: root.polColor; font.pixelSize: Theme.fontSizeSmall; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            visible: root.hoursLeft > 0
                            text: "~" + root.fmtH(root.hoursLeft) + (root.charging ? " to full" : " left")
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MeterBar { value: root.pct; okColor: root.polColor; warnLevel: 101; implicitWidth: parent.width; implicitHeight: 5 }
                }
                Tile {
                    heading: "POWER"
                    headingColor: Theme.surfaceVariantText
                    Row {
                        spacing: Theme.spacingS
                        width: parent.width
                        StyledText { text: "now"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; width: 30; anchors.verticalCenter: parent.verticalCenter }
                        MeterBar { value: root.watts / 65 * 100; fillColor: root.polColor; implicitWidth: parent.width - 100; implicitHeight: 5; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: (root.charging ? "+" : "−") + root.watts.toFixed(1) + "W"; color: root.polColor; font.pixelSize: Theme.fontSizeSmall; width: 54; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Spark {
                        framed: true
                        values: root.wattsHist
                        lineColor: root.polColor
                        area: false
                        implicitWidth: parent.width
                        implicitHeight: 30
                        stroke: 1.5
                    }
                    StyledText { text: "±W · 5s ticks · bar scale 0–65 W (brick)"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                }
                Tile {
                    heading: "HEALTH"
                    headingColor: Theme.surfaceVariantText
                    Row {
                        spacing: Theme.spacingM
                        StyledText { text: root.health >= 0 ? root.health.toFixed(1) + "% of design" : "—"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeMedium }
                        StyledText { text: root.cycles >= 0 ? root.cycles + " cycles" : ""; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "TLP holds 75–80"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
    popoutWidth: 320
    popoutHeight: 420

    // headless popout toggle: qs -c dms ipc call popout-bat toggle
    IpcHandler {
        target: "popout-bat"
        function toggle(): string { root.triggerPopout(); return "ok" }
    }
}
