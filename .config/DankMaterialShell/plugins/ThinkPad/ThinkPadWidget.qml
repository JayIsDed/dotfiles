// ThinkPadWidget.qml — the thinkpad_acpi corner: platform profile + fan RPM
// + TLP battery-care thresholds + kbd backlight. Read-only by design:
// profile writes need root (a udev rule can unlock cycling later).
// Keyed sysfs probe, 5s. Row grammar: fan is history → severity spark.
import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string profile: ""
    property var choices: []
    property int fanRpm: -1
    property string fanLevel: ""
    property int thStart: -1
    property int thEnd: -1
    property int kbd: -1
    property int kbdMax: -1
    property var fanHist: []

    readonly property bool alive: profile !== "" || fanRpm >= 0
    // X1C9 tops out ~7000 rpm flat-out; amber past sustained-load territory
    readonly property color fanTone: fanRpm > 6300 ? "#ef4444"
                                   : fanRpm > 5200 ? "#fbbf24" : "#4ade80"

    function profileIcon(p) {
        if (p === "performance") return "speed"
        if (p === "low-power") return "eco"
        return "balance"
    }

    function probe() {
        Proc.runCommand("thinkPad.probe",
            ["sh", "-c",
             "echo profile=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null); " +
             "echo choices=$(cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null); " +
             "echo fan=$(awk '/^speed:/{print $2}' /proc/acpi/ibm/fan 2>/dev/null); " +
             "echo level=$(awk '/^level:/{print $2}' /proc/acpi/ibm/fan 2>/dev/null); " +
             "echo ts=$(cat /sys/class/power_supply/BAT0/charge_control_start_threshold 2>/dev/null); " +
             "echo te=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null); " +
             "echo kbd=$(cat '/sys/class/leds/tpacpi::kbd_backlight/brightness' 2>/dev/null); " +
             "echo kbdmax=$(cat '/sys/class/leds/tpacpi::kbd_backlight/max_brightness' 2>/dev/null); true"],
            (stdout, exitCode) => {
                if (exitCode !== 0) { root.profile = ""; root.fanRpm = -1; return }
                const kv = {}
                for (const line of stdout.trim().split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0) kv[line.slice(0, i)] = line.slice(i + 1)
                }
                root.profile = kv.profile || ""
                root.choices = (kv.choices || "").split(" ").filter(c => c.length)
                root.fanRpm = kv.fan !== undefined && kv.fan !== "" ? Number(kv.fan) : -1
                root.fanLevel = kv.level || ""
                root.thStart = Number(kv.ts || -1)
                root.thEnd = Number(kv.te || -1)
                root.kbd = Number(kv.kbd !== undefined && kv.kbd !== "" ? kv.kbd : -1)
                root.kbdMax = Number(kv.kbdmax || -1)
                if (root.fanRpm >= 0)
                    root.fanHist = root.fanHist.concat(root.fanRpm).slice(-60)
            }, 0, 4000)
    }

    Timer {
        interval: 5000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: root.probe()
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: tpRow.implicitWidth
            implicitHeight: tpRow.implicitHeight

            Row {
                id: tpRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: root.profileIcon(root.profile)
                    size: root.iconSize
                    color: root.profile === "performance" ? Theme.primary : Theme.widgetIconColor
                    anchors.verticalCenter: parent.verticalCenter
                }
                DankIcon {
                    name: "mode_fan"
                    size: root.iconSize - 2
                    color: root.fanRpm > 0 ? root.fanTone : Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.fanRpm >= 0
                }
                StyledText {
                    text: root.fanRpm >= 0 ? root.fanRpm : "—"
                    color: Theme.widgetTextColor
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "thinkpad"
            detailsText: "X1 Carbon Gen 9 · thinkpad_acpi"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingS

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
                    heading: "FAN"
                    headingColor: Theme.surfaceVariantText
                    Row {
                        spacing: Theme.spacingS
                        StyledText {
                            text: root.fanRpm >= 0 ? root.fanRpm + " rpm" : "—"
                            color: root.fanTone
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Bold
                        }
                        StyledText {
                            text: root.fanLevel !== "" ? "level " + root.fanLevel : ""
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Spark {
                        values: root.fanHist
                        lineColor: root.fanTone
                        area: false
                        implicitWidth: parent.width
                        implicitHeight: 24
                        stroke: 1.5
                    }
                }
                Tile {
                    heading: "CARE"
                    headingColor: Theme.surfaceVariantText
                    Row {
                        spacing: Theme.spacingM
                        StyledText {
                            text: root.thStart > 0 ? "TLP holds " + root.thStart + "–" + root.thEnd : "TLP thresholds unknown"
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                        }
                        StyledText {
                            text: root.kbd >= 0 ? "kbd light " + root.kbd + "/" + root.kbdMax : ""
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
    popoutWidth: 320
    popoutHeight: 380

    // headless popout toggle: qs -c dms ipc call popout-tp toggle
    IpcHandler {
        target: "popout-tp"
        function toggle(): string { root.triggerPopout(); return "ok" }
    }
}
