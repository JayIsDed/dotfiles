// Battery.qml — ring gauge with the percentage inside (design brief v2).
// Battery semantics are low-is-bad, so state colors are manual, not the
// board's high-is-bad thresholds: charging green, <15 red, <30 amber,
// otherwise accent. Hides itself on hosts with no battery.
import Quickshell.Services.UPower
import QtQuick

Item {
    id: root
    visible: UPower.displayDevice?.isLaptopBattery ?? false

    readonly property real pct: (UPower.displayDevice?.percentage ?? 0) * 100
    readonly property bool charging: !UPower.onBattery
    readonly property color tone: charging ? Theme.ok
                                 : pct < 15 ? Theme.crit
                                 : pct < 30 ? Theme.warn
                                 : Theme.accent

    implicitWidth: 34
    implicitHeight: 34

    Gauge {
        anchors.fill: parent
        value: root.pct
        fillColor: root.tone
    }
    Text {
        anchors.centerIn: parent
        text: Math.round(root.pct)
        color: root.charging ? Theme.ok : Theme.text
        font.family: Theme.font
        font.pixelSize: 11
        font.bold: true
    }
}
