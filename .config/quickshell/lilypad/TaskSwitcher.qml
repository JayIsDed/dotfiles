// TaskSwitcher.qml — focused-workspace windows as click-to-focus chips.
// The activated chip doubles as the window title readout (replaced the old
// title tile). Prefers the wayland toplevel activate(); falls back to a
// hyprland focuswindow dispatch (Lua shorthand).
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    spacing: 6

    readonly property bool any:
        Hyprland.toplevels.values.some(t => t.workspace?.focused ?? false)

    Repeater {
        model: Hyprland.toplevels
        delegate: Rectangle {
            required property var modelData
            visible: modelData.workspace?.focused ?? false
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: label.implicitWidth + 22
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
                text: {
                    const t = modelData.title ?? ""
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
