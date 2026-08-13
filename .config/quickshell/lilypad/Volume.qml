// Volume.qml — wpctl-backed: click mutes, right-click pavucontrol, scroll adjusts.
import Quickshell.Io
import QtQuick

MouseArea {
    id: root
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true

    property real vol: 0
    property bool muted: false

    Process {
        id: probe
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "Volume: 0.65 [MUTED]"
                const m = text.match(/([\d.]+)(.*MUTED)?/)
                if (m) { root.vol = Number(m[1]) * 100; root.muted = !!m[2] }
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: probe.running = true }

    Process { id: act }
    function run(cmd) { act.command = ["sh", "-c", cmd]; act.running = true; refreshSoon.start() }
    Timer { id: refreshSoon; interval: 150; onTriggered: probe.running = true }

    onClicked: (mouse) => {
        if (mouse.button === Qt.LeftButton) run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
        else run("pavucontrol &")
    }
    onWheel: (wheel) => {
        run(wheel.angleDelta.y > 0
            ? "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
            : "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
    }

    Text {
        id: label
        text: (root.muted ? "󰝟 " : root.vol > 50 ? "󰕾 " : "󰖀 ") + Math.round(root.vol) + "%"
        color: root.muted ? Theme.text3 : root.containsMouse ? Theme.text : Theme.text2
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }
}
