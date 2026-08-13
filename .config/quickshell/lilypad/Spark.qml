// Spark.qml — token-fed sparkline. Feed it a plain number array; it
// autoscales unless minValue/maxValue pin the range (pin them for rates
// so the scale doesn't breathe between repaints).
import QtQuick

Item {
    id: root
    property var values: []
    property var lineColor: undefined // undefined = accent
    property var minValue: undefined  // undefined = autoscale
    property var maxValue: undefined
    property bool area: true          // soft fill under the line

    readonly property color effLine: lineColor !== undefined ? lineColor : Theme.accent

    implicitWidth: Theme.meterWidth
    implicitHeight: 18

    onValuesChanged: canvas.requestPaint()
    onEffLineChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const v = root.values
            if (!v || v.length < 2) return
            let lo = root.minValue !== undefined ? root.minValue : Math.min(...v)
            let hi = root.maxValue !== undefined ? root.maxValue : Math.max(...v)
            if (hi === lo) { hi = lo + 1 }
            const stepX = width / (v.length - 1)
            const pad = root.lineWidthPad
            const py = i => height - pad - (v[i] - lo) / (hi - lo) * (height - pad * 2)

            ctx.lineWidth = Theme.sparkStroke
            ctx.lineJoin = "round"
            ctx.strokeStyle = root.effLine
            ctx.beginPath()
            ctx.moveTo(0, py(0))
            for (let i = 1; i < v.length; i++) ctx.lineTo(i * stepX, py(i))
            ctx.stroke()

            if (root.area) {
                ctx.lineTo(width, height)
                ctx.lineTo(0, height)
                ctx.closePath()
                ctx.fillStyle = Theme.sparkFill
                ctx.fill()
            }
        }
    }
    readonly property real lineWidthPad: Theme.sparkStroke
}
