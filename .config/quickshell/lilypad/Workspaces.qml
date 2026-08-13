// Workspaces.qml — pills; active glows pond-green. implicit sizes + explicit
// Layout hints so nested layouts can never collapse them. Always shows pills
// 1..max(3, highest) so a one-workspace session still reads as a pill row.
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    spacing: 5

    // Hyprland only reports existing workspaces; pad so the row reads as pills
    readonly property int shown: Math.max(3,
        Hyprland.workspaces.values.reduce((m, w) => Math.max(m, w.id), 0))

    Repeater {
        model: root.shown
        delegate: Rectangle {
            required property int index
            readonly property int wsId: index + 1
            readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
            readonly property bool focused: ws?.focused ?? false
            readonly property bool occupied: ws !== null

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 34
            implicitHeight: 26
            radius: 13
            color: focused ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                 : occupied ? Theme.elevated : "transparent"
            border.color: focused ? Theme.accent : occupied ? Theme.borderStrong : Theme.border
            border.width: focused ? 2 : 1

            Text {
                anchors.centerIn: parent
                text: wsId
                font.bold: focused
                color: focused ? Theme.accent : occupied ? Theme.text : Theme.text2
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }
            MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("workspace " + wsId)
            }
        }
    }
}
