// MeterBar.qml — lilypad's linear meter, dms edition. Self-contained: no
// Theme singleton in plugin dirs, so every token is a property — consumers
// feed dms Theme colors (ok default gets overridden with Theme.primary so
// healthy bars ride the matugen accent; warn/crit stay fixed hues).
import QtQuick

Item {
    id: root
    property real value: 0            // 0-100
    property var fillColor: undefined // color override; undefined = threshold auto
    property color okColor: "#4ade80"
    property color warnColor: "#fbbf24"
    property color critColor: "#ef4444"
    property color trackColor: Qt.rgba(1, 1, 1, 0.12)
    property color markerColor: Qt.rgba(1, 1, 1, 0.55)
    property int warnLevel: 70
    property int critLevel: 85
    property real marker: -1          // 0-100; <0 hides

    readonly property color effFill: fillColor !== undefined ? fillColor
        : value >= critLevel ? critColor : value >= warnLevel ? warnColor : okColor
    readonly property real clamped: Math.min(100, Math.max(0, value))

    implicitWidth: 56
    implicitHeight: 3

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
    }
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.clamped <= 0 ? 0
             : Math.max(height, parent.width * root.clamped / 100)
        radius: height / 2
        color: root.effFill
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 300 } }
    }
    Rectangle {
        visible: root.marker >= 0
        x: parent.width * root.marker / 100 - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: parent.height + 3
        radius: 1
        color: root.markerColor
    }
}
