import QtQuick
import Quickshell

// sakura: desktop clock, hung in the hazy sky right of the blossom cluster.
// Airy light-weight time on a soft plum pool, a thin pink hairline underneath
// with the theme's parametric blossom at its start. The blossom blooms open
// on boot (law 1); when the minute turns it lets exactly one petal go, which
// falls along a curved path, turning once, fading (law 2).
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // pushed by the loader: true while locked or covered by a fullscreen window
    property bool occluded: false

    readonly property color cream: pal.text
    readonly property color pink:  pal.neon
    readonly property color sky:   pal.cyan
    readonly property color plum:  pal.glass
    readonly property real ui: pal.uiScale
    readonly property string sans: "Noto Sans"
    function creamA(a) { return Qt.rgba(cream.r, cream.g, cream.b, a) }
    function pinkA(a)  { return Qt.rgba(pink.r, pink.g, pink.b, a) }
    function skyA(a)   { return Qt.rgba(sky.r, sky.g, sky.b, a) }
    function plumA(a)  { return Qt.rgba(plum.r, plum.g, plum.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // boot-in: the whole clock blooms into place
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1400; easing.type: Easing.OutSine }

    // minute flourish: one petal released from the blossom
    property int _lastMin: -1
    Connections {
        target: clock
        function onDateChanged() {
            const m = clock.date.getMinutes()
            if (root._lastMin >= 0 && m !== root._lastMin && root.bootT >= 1 && !root.occluded)
                petal.fall()
            root._lastMin = m
        }
    }

    // the five-petal blossom with notched tips — the theme's one glyph.
    // bloom 0 = closed bud, 1 = full open flower.
    function drawBlossom(ctx, r, bloom, fillCol, coreCol) {
        if (bloom < 0.1) {
            ctx.beginPath()
            ctx.arc(0, 0, Math.max(1, r * 0.30), 0, 2 * Math.PI)
            ctx.fillStyle = fillCol
            ctx.fill()
            return
        }
        const pr = r * (0.4 + 0.6 * bloom)
        const w = pr * 0.55 * (0.55 + 0.45 * bloom)
        for (let i = 0; i < 5; i++) {
            ctx.save()
            ctx.rotate(i * Math.PI * 2 / 5)
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.bezierCurveTo(-w, -pr * 0.35, -w * 0.9, -pr * 0.85, -pr * 0.16, -pr * 0.97)
            ctx.lineTo(0, -pr * 0.85)                       // the notch
            ctx.lineTo(pr * 0.16, -pr * 0.97)
            ctx.bezierCurveTo(w * 0.9, -pr * 0.85, w, -pr * 0.35, 0, 0)
            ctx.closePath()
            ctx.fillStyle = fillCol
            ctx.fill()
            ctx.restore()
        }
        ctx.beginPath()
        ctx.arc(0, 0, Math.max(0.8, r * 0.12), 0, 2 * Math.PI)
        ctx.fillStyle = coreCol
        ctx.fill()
    }

    Item {
        id: face
        x: Math.round(root.width * 0.685 - width / 2)
        y: Math.round(root.height * 0.60 - height / 2)
        width: Math.round(460 * root.ui)
        height: Math.round(260 * root.ui)
        opacity: root.bootT

        // soft plum pool so the cream reads over the bright sky
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.25
            height: parent.height * 1.15
            radius: height / 2
            color: "transparent"
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.plumA(0.0) }
                    GradientStop { position: 0.5; color: root.plumA(0.34) }
                    GradientStop { position: 1.0; color: root.plumA(0.0) }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: Math.round(10 * root.ui)

            Text {
                id: timeText
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.creamA(0.96)
                font.family: root.sans
                font.weight: Font.Light
                font.pixelSize: Math.round(104 * root.ui)
                font.letterSpacing: 6 * root.ui
                style: Text.Raised
                styleColor: root.plumA(0.5)
                // the time blooms up very slightly as it arrives
                scale: 0.96 + 0.04 * root.bootT
            }

            // hairline with the blossom at its start
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: timeText.width
                height: Math.round(26 * root.ui)

                Canvas {
                    id: blossom
                    width: Math.round(26 * root.ui)
                    height: width
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    property real bloom: root.bootT
                    onBloomChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.translate(width / 2, height / 2)
                        root.drawBlossom(ctx, width * 0.46, bloom,
                                         String(root.pinkA(0.92)), String(root.creamA(0.9)))
                    }
                    Connections {
                        target: root.pal
                        function onNeonChanged() { blossom.requestPaint() }
                        function onTextChanged() { blossom.requestPaint() }
                    }
                }

                Rectangle {
                    anchors.left: blossom.right
                    anchors.leftMargin: Math.round(10 * root.ui)
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 1
                    color: root.pinkA(0.42)
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(10 * root.ui)
                Text {
                    text: Qt.formatDateTime(clock.date, "dddd").toLowerCase()
                    color: root.skyA(0.92)
                    font.family: root.sans
                    font.pixelSize: Math.round(15 * root.ui)
                    font.letterSpacing: 4 * root.ui
                }
                Text {
                    text: "·"
                    color: root.pinkA(0.8)
                    font.family: root.sans
                    font.pixelSize: Math.round(15 * root.ui)
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "MMMM d").toLowerCase()
                    color: root.creamA(0.72)
                    font.family: root.sans
                    font.pixelSize: Math.round(15 * root.ui)
                    font.letterSpacing: 4 * root.ui
                }
            }
        }

        // the released petal — one per minute, a curved fall with a single turn
        Canvas {
            id: petal
            width: Math.round(14 * root.ui)
            height: width
            property real t: 0
            visible: t > 0 && t < 1
            function fall() { fallAnim.restart() }
            // curved drift: right and down, one slow turn, fade at the end
            readonly property real px: face.width / 2 - timeText.width / 2 + 40 * t * root.ui + 26 * Math.sin(t * 3.1) * root.ui
            readonly property real py: face.height / 2 + 36 * root.ui + 120 * t * t * root.ui
            onTChanged: { x = px; y = py; rotation = t * 200; opacity = t < 0.75 ? 0.9 : 0.9 * (1 - (t - 0.75) / 0.25) }
            NumberAnimation on t {
                id: fallAnim
                running: false
                from: 0.01; to: 1
                duration: 2600
                easing.type: Easing.InSine
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, pr = w * 0.48
                ctx.translate(w / 2, w / 2)
                ctx.beginPath()
                ctx.moveTo(0, pr * 0.5)
                ctx.bezierCurveTo(-pr * 0.8, 0, -pr * 0.6, -pr * 0.8, -pr * 0.14, -pr * 0.9)
                ctx.lineTo(0, -pr * 0.76)
                ctx.lineTo(pr * 0.14, -pr * 0.9)
                ctx.bezierCurveTo(pr * 0.6, -pr * 0.8, pr * 0.8, 0, 0, pr * 0.5)
                ctx.closePath()
                ctx.fillStyle = String(root.pinkA(0.9))
                ctx.fill()
            }
            Component.onCompleted: requestPaint()
            Connections {
                target: root.pal
                function onNeonChanged() { petal.requestPaint() }
            }
        }
    }
}
