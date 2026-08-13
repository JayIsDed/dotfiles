// Spark.qml — lilypad's sparkline, dms edition. Self-contained (see
// MeterBar.qml): lineColor fed by the consumer, fill derived from it.
// framed = "trend chip": the line sits in MeterBar's rounded track, so a
// standalone spark reads as the same family as the bars beside it. Sparks
// stacked UNDER a MeterBar (history shadows) stay naked.
import QtQuick

Item {
    id: root
    property var values: []
    property color lineColor: "#8b5cf6"
    property var minValue: undefined  // undefined = autoscale
    property var maxValue: undefined
    property bool area: true
    property real stroke: 1.5
    property bool framed: false
    property color trackColor: Qt.rgba(1, 1, 1, 0.12)

    implicitWidth: 56
    implicitHeight: 9

    onValuesChanged: canvas.requestPaint()
    onLineColorChanged: canvas.requestPaint()

    Rectangle {
        visible: root.framed
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
    }

    // proportional inset so small chips keep drawable width
    readonly property real padX: framed ? Math.max(3, Math.min(5, width * 0.1)) : 0

    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.leftMargin: root.padX
        anchors.rightMargin: root.padX
        anchors.topMargin: root.framed ? 2 : 0
        anchors.bottomMargin: root.framed ? 2 : 0
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const v = root.values
            if (!v || v.length < 2) return
            let lo = root.minValue !== undefined ? root.minValue : Math.min(...v)
            let hi = root.maxValue !== undefined ? root.maxValue : Math.max(...v)
            if (hi === lo) { hi = lo + 1 }
            const stepX = width / (v.length - 1)
            const pad = root.stroke
            const py = i => height - pad - (v[i] - lo) / (hi - lo) * (height - pad * 2)

            ctx.lineWidth = root.stroke
            ctx.lineJoin = "round"
            ctx.strokeStyle = root.lineColor
            ctx.beginPath()
            ctx.moveTo(0, py(0))
            for (let i = 1; i < v.length; i++) ctx.lineTo(i * stepX, py(i))
            ctx.stroke()

            if (root.area) {
                ctx.lineTo(width, height)
                ctx.lineTo(0, height)
                ctx.closePath()
                ctx.fillStyle = Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.15)
                ctx.fill()
            }
        }
    }
}
