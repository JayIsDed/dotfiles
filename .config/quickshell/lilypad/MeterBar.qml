// MeterBar.qml — token-fed linear meter, the bar-level workhorse (stacked
// thin bars glance better than rings — design brief v2). Pure primitive:
// no label, compose text around it. autoColor maps value through the board's
// warn/crit thresholds; set fillColor to pin a hue (e.g. Claude usage bars).
// marker draws a tick at a fraction (e.g. the 50% Fable ceiling on the 7d bar).
import QtQuick

Item {
    id: root
    property real value: 0            // 0-100
    property var fillColor: undefined // color override; undefined = threshold auto
    property int warnLevel: Theme.warnAt
    property int critLevel: Theme.critAt
    property real marker: -1          // 0-100; <0 hides

    readonly property color effFill: fillColor !== undefined
        ? fillColor : Theme.valueToColor(value, warnLevel, critLevel)
    readonly property real clamped: Math.min(100, Math.max(0, value))

    implicitWidth: Theme.meterWidth
    implicitHeight: Theme.meterHeight

    Rectangle {
        anchors.fill: parent
        radius: Theme.meterRadius
        color: Theme.track
    }
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.clamped <= 0 ? 0
             : Math.max(height, parent.width * root.clamped / 100)
        radius: Theme.meterRadius
        color: root.effFill
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 300 } }
    }
    Rectangle {
        visible: root.marker >= 0
        x: parent.width * root.marker / 100 - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: parent.height + 4
        radius: 1
        color: Theme.text3
    }
}
