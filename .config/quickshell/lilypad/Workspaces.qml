// Workspaces.qml — pills; active glows pond-green.
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

RowLayout {
    spacing: 4

    Repeater {
        model: Hyprland.workspaces
        delegate: Rectangle {
            required property var modelData
            width: 26; height: 22
            radius: 6
            color: modelData.focused ? Theme.elevated : "transparent"
            border.color: modelData.focused ? Theme.accent : Theme.border
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: modelData.name
                color: modelData.focused ? Theme.accent
                     : modelData.active ? Theme.text : Theme.text3
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }
            MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("workspace " + modelData.id)
            }
        }
    }
}
