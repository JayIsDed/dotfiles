// ControlPanel.qml — the slide-out. Game mode + lab controls; actions that
// need archbox hardware render disabled elsewhere. Host detection mirrors
// hypr/hosts.lua: /etc/hostname is the switch.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PopupWindow {
    id: panel
    required property var barWindow
    signal dismissed()

    anchor.window: barWindow
    anchor.rect.x: barWindow.width - width - 8
    anchor.rect.y: barWindow.height + 4
    implicitWidth: 300
    implicitHeight: content.implicitHeight + 24
    visible: true
    color: "transparent"

    property string host: "unknown"
    property bool isArchbox: host === "taichi"

    FileView {
        path: "/etc/hostname"
        onLoaded: panel.host = text().trim()
    }

    Process { id: gamemode }
    function runLab(script) {
        labProc.command = ["ssh", "claude-dev", script]
        labProc.running = true
    }
    Process { id: labProc }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: Theme.radius
        border.color: Theme.borderStrong
        border.width: 1

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                text: "lilypad"
                color: Theme.text3
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }

            // host · kernel · uptime — moved off the bar (Jay 08-13); the
            // component carries its own 30s probe, only alive while open
            SysCard {}

            component PadButton: Rectangle {
                property string label
                property string hint: ""
                property bool enabled_: true
                signal go()
                Layout.fillWidth: true
                implicitHeight: 40
                radius: 8
                color: mouse.pressed && enabled_ ? Theme.elevated : "transparent"
                border.color: enabled_ ? Theme.border : Qt.rgba(1, 1, 1, 0.03)
                opacity: enabled_ ? 1.0 : 0.4
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    Text { text: label; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                    Item { Layout.fillWidth: true }
                    Text { text: hint; color: Theme.text3; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                }
                MouseArea { id: mouse; anchors.fill: parent; onClicked: if (enabled_) go() }
            }

            PadButton {
                label: "󰊗  Game Mode"
                hint: "SUPER+ALT+G"
                onGo: {
                    gamemode.command = ["hyprctl", "dispatch", "gamemode_toggle()"]
                    gamemode.running = true
                    panel.dismissed()
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            Text {
                text: "the bench (via 111)"
                color: Theme.text3
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }

            PadButton { label: "󰐊  Shelf up"; hint: "lab-train-done"; enabled_: panel.isArchbox; onGo: panel.runLab("lab-train-done") }
            PadButton { label: "󰓛  Shelf down"; hint: "lab-train-prep"; enabled_: panel.isArchbox; onGo: panel.runLab("lab-train-prep") }
            PadButton { label: "󰢮  GPU status"; hint: "lab-gpu"; enabled_: panel.isArchbox; onGo: panel.runLab("lab-gpu") }
        }
    }
}
