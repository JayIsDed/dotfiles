// Tile.qml — popout section card: lettered heading + content column on a
// soft inset panel. Zero-import like the rest of the kit; consumer feeds
// theme colors. The glance grammar: find the section by its heading.
import QtQuick

Rectangle {
    id: root
    property string heading: ""
    property color headingColor: Qt.rgba(1, 1, 1, 0.45)
    default property alias content: col.data

    width: parent ? parent.width : 280
    implicitHeight: col.implicitHeight + (heading !== "" ? 34 : 24)
    radius: 10
    color: Qt.rgba(1, 1, 1, 0.05)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1

    Text {
        visible: root.heading !== ""
        text: root.heading
        color: root.headingColor
        font.pixelSize: 9
        font.letterSpacing: 1.4
        font.weight: Font.DemiBold
        x: 12; y: 9
    }
    Column {
        id: col
        x: 12
        y: root.heading !== "" ? 24 : 12
        width: parent.width - 24
        spacing: 7
    }
}
