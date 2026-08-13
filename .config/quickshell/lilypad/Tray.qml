// Tray.qml — SNI tray items.
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

RowLayout {
    spacing: 6

    Repeater {
        model: SystemTray.items
        delegate: Image {
            required property var modelData
            width: 18; height: 18
            sourceSize: Qt.size(18, 18)
            source: modelData.icon
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) modelData.activate()
                    else modelData.openMenu()
                }
            }
        }
    }
}
