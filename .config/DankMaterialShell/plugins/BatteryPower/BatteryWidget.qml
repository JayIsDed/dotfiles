// BatteryWidget.qml — battery % + lilypad's PowerDraw: signed wattage
// (+green charging / −blue discharging, fixed hues) over a 0-65W rate bar
// (X1C9 brick scale). BAT0 sysfs probe, 5s. Absorbed the thinkpad corner
// 08-14 (Jay's call): platform profile + live TLP thresholds + kbd light
// live in the popout; fan stays with sysMetrics. Battery icon tints
// primary when profile=performance — the battery-eater mode, at a glance.
// Profile writes need root (udev rule later) — read-only chips.
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
    property string profile: ""
    property var choices: []
    property int thStart: -1
    property int thEnd: -1
    property int kbd: -1
    property int kbdMax: -1

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
             "for f in capacity status power_now energy_now energy_full energy_full_design charge_full charge_full_design cycle_count charge_control_start_threshold charge_control_end_threshold; do " +
             "v=$(cat $f 2>/dev/null); [ -n \"$v\" ] && echo $f=$v; done; " +
             "echo profile=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null); " +
             "echo choices=$(cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null); " +
             "echo kbd=$(cat '/sys/class/leds/tpacpi::kbd_backlight/brightness' 2>/dev/null); " +
             "echo kbdmax=$(cat '/sys/class/leds/tpacpi::kbd_backlight/max_brightness' 2>/dev/null); true"],
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
                root.thStart = Number(kv.charge_control_start_threshold || -1)
                root.thEnd = Number(kv.charge_control_end_threshold || -1)
                root.profile = kv.profile || ""
                root.choices = (kv.choices || "").split(" ").filter(c => c.length)
                root.kbd = Number(kv.kbd !== undefined && kv.kbd !== "" ? kv.kbd : -1)
                root.kbdMax = Number(kv.kbdmax || -1)
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
                    color: root.alive && root.pct <= 20 && !root.charging ? Theme.tempDanger
                         : root.profile === "performance" ? Theme.primary : Theme.widgetIconColor
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
            detailsText: root.status + (root.profile !== "" ? " · " + root.profile : "")
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
                        StyledText { text: "now"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: (root.charging ? "+" : "−") + root.watts.toFixed(1) + "W"; color: root.polColor; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Spark {
                        values: root.wattsHist
                        lineColor: root.polColor
                        area: false
                        implicitWidth: parent.width
                        implicitHeight: 30
                        stroke: 1.5
                    }
                    StyledText { text: "±W · 5s ticks · brick is 65 W"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                }
                Tile {
                    heading: "PROFILE"
                    headingColor: Theme.surfaceVariantText
                    Row {
                        spacing: Theme.spacingXS
                        Repeater {
                            model: root.choices
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool current: modelData === root.profile
                                width: profLabel.implicitWidth + 18
                                height: 28
                                radius: 8
                                color: current ? Qt.alpha(Theme.primary, 0.25) : Qt.rgba(1, 1, 1, 0.05)
                                border.color: current ? Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1
                                StyledText {
                                    id: profLabel
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    color: parent.current ? Theme.primary : Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }
                        }
                    }
                    StyledText {
                        text: "cycling needs root — read-only for now"
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
                Tile {
                    heading: "HEALTH"
                    headingColor: Theme.surfaceVariantText
                    Row {
                        spacing: Theme.spacingM
                        StyledText { text: root.health >= 0 ? root.health.toFixed(1) + "% of design" : "—"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeMedium }
                        StyledText { text: root.cycles >= 0 ? root.cycles + " cycles" : ""; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        spacing: Theme.spacingM
                        StyledText {
                            text: root.thStart > 0 ? "TLP holds " + root.thStart + "–" + root.thEnd : "TLP thresholds unknown"
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        StyledText {
                            text: root.kbd >= 0 ? "kbd light " + root.kbd + "/" + root.kbdMax : ""
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
            }
        }
    }
    popoutWidth: 320
    popoutHeight: 520

    // headless popout toggle: qs -c dms ipc call popout-bat toggle
    IpcHandler {
        target: "popout-bat"
        function toggle(): string { root.triggerPopout(); return "ok" }
    }
}
