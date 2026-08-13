// TaskSwitcher.qml — focused-workspace windows as click-to-focus chips.
// The activated chip doubles as the window title readout (replaced the old
// title tile). Chips share a width budget from Bar: when the row would
// overflow they split the budget evenly and elide, and once a chip drops
// below a title's worth it shows the wayland appId instead — short names
// beat clipped sentences. Prefers the wayland toplevel activate(); falls
// back to a hyprland focuswindow dispatch (Lua shorthand).
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    spacing: 6

    // px available for the whole chip row; <0 = unbounded
    property real budget: -1

    readonly property int shown:
        Hyprland.toplevels.values.filter(t => t.workspace?.focused ?? false).length
    readonly property bool any: shown > 0
    readonly property real chipCap:
        budget < 0 || shown === 0 ? -1
        : Math.max(38, (budget - spacing * (shown - 1)) / shown)
    readonly property bool compact: chipCap >= 0 && chipCap < 96

    Repeater {
        model: Hyprland.toplevels
        delegate: Rectangle {
            required property var modelData
            visible: modelData.workspace?.focused ?? false
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: root.chipCap >= 0
                ? Math.min(label.implicitWidth + 22, root.chipCap)
                : label.implicitWidth + 22
            implicitHeight: 30
            radius: Theme.chipRadius
            color: modelData.activated
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                : "transparent"
            border.color: modelData.activated ? Theme.accent : Theme.border
            border.width: 1

            Text {
                id: label
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 14)
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                text: {
                    const t = modelData.title ?? ""
                    if (root.compact)
                        return (modelData.wayland?.appId || t).split(".").pop()
                    return t.length > 18 ? t.slice(0, 17) + "…" : t
                }
                color: modelData.activated ? Theme.text : Theme.text2
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeS + 1
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (modelData.wayland)
                        modelData.wayland.activate()
                    else
                        Hyprland.dispatch('focuswindow("address:0x' + modelData.address + '")')
                }
            }
        }
    }
}
