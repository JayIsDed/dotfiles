// Gauge.qml — token-fed circular progress. Popup/deep-view furniture; the
// bar itself prefers stacked MeterBars. Canvas-drawn (no extra imports).
import QtQuick

Item {
    id: root
    property real value: 0            // 0-100
    property var fillColor: undefined // color override; undefined = threshold auto
    property int warnLevel: Theme.warnAt
    property int critLevel: Theme.critAt

    readonly property color effFill: fillColor !== undefined
        ? fillColor : Theme.valueToColor(value, warnLevel, critLevel)
    readonly property real clamped: Math.min(100, Math.max(0, value))

    implicitWidth: Theme.gaugeSize
    implicitHeight: Theme.gaugeSize

    onClampedChanged: canvas.requestPaint()
    onEffFillChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const cx = width / 2, cy = height / 2
            const r = Math.min(width, height) / 2 - Theme.gaugeStroke / 2
            ctx.lineWidth = Theme.gaugeStroke
            ctx.lineCap = "round"
            // track
            ctx.strokeStyle = Theme.track
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.stroke()
            // value arc, 12 o'clock clockwise
            if (root.clamped > 0) {
                ctx.strokeStyle = root.effFill
                ctx.beginPath()
                ctx.arc(cx, cy, r, -Math.PI / 2,
                        -Math.PI / 2 + 2 * Math.PI * root.clamped / 100)
                ctx.stroke()
            }
        }
    }
}
