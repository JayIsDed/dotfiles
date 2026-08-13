// Battery.qml — laptop-only by nature: hides itself on hosts with no battery.
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

RowLayout {
    spacing: 4
    visible: UPower.displayDevice?.isLaptopBattery ?? false

    readonly property real pct: (UPower.displayDevice?.percentage ?? 0) * 100
    readonly property bool charging: !UPower.onBattery

    Text {
        text: charging ? "󰂄" : pct > 60 ? "󰁹" : pct > 30 ? "󰁽" : "󰁺"
        color: charging ? Theme.green : pct < 20 ? Theme.red : Theme.text2
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }
    Text {
        text: Math.round(pct) + "%"
        color: Theme.text2
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }
}
