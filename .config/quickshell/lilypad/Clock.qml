// Clock.qml — 24h always (house rule).
import QtQuick

Text {
    id: clock
    color: Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.bold: true

    function tick() {
        clock.text = Qt.formatDateTime(new Date(), "HH:mm · ddd dd MMM")
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: clock.tick()
    }
    Component.onCompleted: tick()
}
