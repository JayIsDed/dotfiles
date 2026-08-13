// BrightnessChip.qml — backlight readout + wheel adjust, lives by the
// battery. Hides itself on hosts with no backlight (archbox). Item wrapper
// so the MouseArea overlays instead of becoming a layout cell.
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property int bright: -1

    implicitWidth: row.implicitWidth
    implicitHeight: 24
    visible: bright >= 0

    Process {
        id: probe
        command: ["sh", "-c",
            "cat /sys/class/backlight/*/brightness /sys/class/backlight/*/max_brightness 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/).map(Number)
                if (p.length >= 2 && p[1] > 0)
                    root.bright = Math.round(100 * p[0] / p[1])
            }
        }
    }
    Timer {
        interval: 3000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
    Process { id: setter }

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Text { text: "󰃟"; color: Theme.text3; font.family: Theme.font; font.pixelSize: Theme.fontSize }
        Text { text: root.bright + "%"; color: Theme.text2; font.family: Theme.font; font.pixelSize: Theme.fontSize }
    }
    MouseArea {
        anchors.fill: parent
        onWheel: (w) => {
            setter.command = ["brightnessctl", "set", w.angleDelta.y > 0 ? "+5%" : "5%-"]
            setter.running = true
            root.bright = Math.min(100, Math.max(1, root.bright + (w.angleDelta.y > 0 ? 5 : -5)))
        }
    }
}
