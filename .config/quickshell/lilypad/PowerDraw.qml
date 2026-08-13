// PowerDraw.qml — live battery watts + rate bar, beside the battery ring.
// Polarity: +green charging (power in), −blue on battery (power out).
// The bar under the readout scales both directions against the X1C9's 65W
// USB-C brick — same scale either way so the eye compares like with like.
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 3
    property real watts: -1
    readonly property real maxW: 65
    readonly property bool charging: !UPower.onBattery

    visible: watts >= 0

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: (root.charging ? "+" : "−") + root.watts.toFixed(1) + "W"
        color: root.charging ? Theme.ok : Theme.info
        font.family: Theme.font
        font.pixelSize: Theme.fontSizeS
    }
    MeterBar {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 52
        value: 100 * root.watts / root.maxW
        fillColor: root.charging ? Theme.ok : Theme.info
    }

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
