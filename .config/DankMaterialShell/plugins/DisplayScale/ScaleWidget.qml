// ScaleWidget.qml — UI-scale chip for the focused monitor. The ladder is
// computed per panel: only scales whose logical size lands on whole pixels
// (hyprland silently nudges anything else — 1.75 on the X1C9 became 5/3).
// Apply path is `hyprctl eval hl.monitor{...}` — `keyword` is dead under
// the Lua config — then a settled reprobe shows what hyprland chose.
// Persistence: ~/.config/hypr/scale-<output>, read back by monitors.lua.
import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string monName: ""
    property int monW: 0
    property int monH: 0
    property real monScale: 0
    property string monMode: ""
    property string monPos: "0x0"
    property int monTransform: 0
    property bool applying: false

    readonly property bool alive: monName !== "" && monScale > 0

    // scales whose logical dims are integral for this panel
    readonly property var ladder: {
        const cand = [1.0, 1.2, 1.25, 4 / 3, 1.5, 1.6, 5 / 3, 1.875, 2.0]
        if (monW <= 0) return cand
        return cand.filter(s => {
            const w = monW / s, h = monH / s
            return Math.abs(w - Math.round(w)) < 0.002 && Math.abs(h - Math.round(h)) < 0.002
        })
    }

    function pctLabel(s) {
        const p = Math.round(s * 1000) / 10
        return (p === Math.round(p) ? Math.round(p) : p.toFixed(1)) + "%"
    }
    function isCurrent(s) { return Math.abs(s - monScale) < 0.005 }

    function probe() {
        Proc.runCommand("displayScale.probe", ["hyprctl", "-j", "monitors"],
            (stdout, exitCode) => {
                if (exitCode !== 0) { root.monName = ""; return }
                try {
                    const mons = JSON.parse(stdout)
                    const m = mons.find(x => x.focused) || mons[0]
                    if (!m) { root.monName = ""; return }
                    root.monName = m.name
                    root.monW = m.width
                    root.monH = m.height
                    root.monScale = m.scale
                    root.monMode = m.width + "x" + m.height + "@" + m.refreshRate.toFixed(3)
                    root.monPos = m.x + "x" + m.y
                    root.monTransform = m.transform || 0
                } catch (e) { root.monName = "" }
            }, 0, 4000)
    }

    function applyScale(s) {
        if (!root.alive || root.applying) return
        root.applying = true
        // preserve transform (archbox DP-5 portrait) or the re-apply drops it
        const lua = 'hl.monitor({ output = "' + monName + '", mode = "' + monMode
                  + '", position = "' + monPos + '", scale = ' + s
                  + (monTransform !== 0 ? ', transform = ' + monTransform : '') + ' })'
        Proc.runCommand("displayScale.apply",
            ["sh", "-c",
             "hyprctl eval '" + lua + "' && printf %s '" + s
             + "' > \"$HOME/.config/hypr/scale-" + monName + "\""],
            (stdout, exitCode) => { settle.restart() }, 0, 5000)
    }
    // back-to-back evals drop silently — let the compositor settle, then
    // reprobe so the chip shows the scale hyprland actually landed on
    Timer { id: settle; interval: 1200; onTriggered: { root.applying = false; root.probe() } }

    Timer {
        interval: 10000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: root.probe()
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: chipRow.implicitWidth
            implicitHeight: chipRow.implicitHeight

            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "display_settings"
                    size: root.iconSize
                    color: Theme.widgetIconColor
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: root.alive ? root.pctLabel(root.monScale) : "—"
                    color: root.applying ? Theme.surfaceVariantText : Theme.widgetTextColor
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "ui scale"
            detailsText: root.alive
                ? root.monName + " · " + Math.round(root.monW / root.monScale) + "x"
                  + Math.round(root.monH / root.monScale) + " logical"
                : "no monitor"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingS

                Tile {
                    heading: "SCALE"
                    headingColor: Theme.surfaceVariantText

                    Flow {
                        width: parent.width
                        spacing: Theme.spacingXS

                        Repeater {
                            model: root.ladder
                            delegate: Rectangle {
                                required property real modelData
                                readonly property bool current: root.isCurrent(modelData)
                                width: chipLabel.implicitWidth + 18
                                height: 30
                                radius: 8
                                color: current ? Qt.alpha(Theme.primary, 0.25) : Qt.rgba(1, 1, 1, 0.05)
                                border.color: current ? Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1

                                StyledText {
                                    id: chipLabel
                                    anchors.centerIn: parent
                                    text: root.pctLabel(parent.modelData)
                                    color: parent.current ? Theme.primary : Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !root.applying
                                    onClicked: root.applyScale(parent.modelData)
                                }
                            }
                        }
                    }
                    StyledText {
                        text: "whole-pixel divisors for " + root.monW + "x" + root.monH
                              + " · survives reboot via monitors.lua"
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }
        }
    }
    popoutWidth: 320
    popoutHeight: 240

    // headless popout toggle: qs -c dms ipc call popout-scale toggle
    IpcHandler {
        target: "popout-scale"
        function toggle(): string { root.triggerPopout(); return "ok" }
    }
}
