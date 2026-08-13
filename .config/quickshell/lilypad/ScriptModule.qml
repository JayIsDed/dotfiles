// ScriptModule.qml — runs one of the original waybar scripts and renders its
// waybar-JSON ({text, tooltip, class}) or plain text. The 2025 shell fleet
// (docker-status, updates, bluetooth, ...) ports through this unchanged.
// Empty text hides the module, same convention waybar used.
// Click actions are command arrays (leftCmd/rightCmd) run via Process —
// the module refreshes itself right after, so toggles feel instant.
import Quickshell
import Quickshell.Io
import QtQuick

MouseArea {
    id: root
    property string script            // filename under lilypad/scripts/
    property int interval: 30000
    property var leftCmd: []
    property var rightCmd: []
    property color tone: Theme.text2

    property string text_: ""
    property string tooltip: ""
    property string klass: ""

    visible: text_ !== ""
    implicitWidth: visible ? label.implicitWidth : 0
    implicitHeight: label.implicitHeight
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true

    onClicked: (mouse) => {
        const cmd = mouse.button === Qt.LeftButton ? leftCmd : rightCmd
        if (cmd.length > 0) { act.command = cmd; act.running = true }
    }

    Process {
        id: proc
        command: ["bash", Quickshell.shellDir + "/scripts/" + root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim()
                if (out === "") { root.text_ = ""; return }
                try {
                    const j = JSON.parse(out.split("\n").pop())
                    root.text_ = j.text ?? ""
                    root.tooltip = j.tooltip ?? ""
                    root.klass = j.class ?? ""
                } catch (e) {
                    root.text_ = out.split("\n").pop()
                }
            }
        }
    }
    Process {
        id: act
        onExited: refreshSoon.start()
    }
    Timer { id: refreshSoon; interval: 200; onTriggered: proc.running = true }
    Timer {
        interval: root.interval; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }

    Text {
        id: label
        text: root.text_
        color: root.klass === "critical" || root.klass === "urgent" ? Theme.red
             : root.klass === "warning" || root.klass === "disconnected" ? Theme.amber
             : root.containsMouse ? Theme.text : root.tone
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }
}
