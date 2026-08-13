// PowerDraw.qml — live battery power in watts (discharge or charge rate),
// beside the battery ring. EE catnip. Hides on hosts without a battery.
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

Text {
    id: root
    property real watts: -1

    visible: watts >= 0
    text: watts.toFixed(1) + "W"
    color: !UPower.onBattery ? Theme.ok : Theme.text2
    font.family: Theme.font
    font.pixelSize: Theme.fontSizeS

    Process {
        id: probe
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/power_now 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const uw = Number(text.trim())
                if (uw > 0) root.watts = uw / 1e6
            }
        }
    }
    Timer {
        interval: 3000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
