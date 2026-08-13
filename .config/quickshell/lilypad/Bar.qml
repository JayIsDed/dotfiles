// Bar.qml — top bar, three zones: [workspaces · window] [clock] [stats · battery · tray · panel]
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { left: true; right: true; top: true }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 12

            Workspaces {}

            Text {
                Layout.fillWidth: true
                text: Hyprland.activeToplevel?.title ?? ""
                color: Theme.text2
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
            }

            Clock {}

            Item { Layout.fillWidth: true }

            SysStats {}
            Network {}
            Battery {}
            Tray {}

            // panel toggle — the lily pad itself
            Rectangle {
                width: 30; height: 24
                radius: 6
                color: panelLoader.active ? Theme.elevated : "transparent"
                border.color: panelLoader.active ? Theme.borderStrong : Theme.border
                Text {
                    anchors.centerIn: parent
                    text: "󱍢"
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 15
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: panelLoader.active = !panelLoader.active
                }
            }
        }
    }

    LazyLoader {
        id: panelLoader
        ControlPanel {
            barWindow: bar
            onDismissed: panelLoader.active = false
        }
    }
}
