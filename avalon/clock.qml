import QtQuick
import Quickshell

// avalon: desktop clock, bottom-right over the mossbank. Serif cream time
// over a buttercup hairline; a small blossom sits at the line's start and
// lets one petal go when the minute turns.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color ivory: pal.text
    readonly property color leaf:  pal.neon
    readonly property color gold:  pal.cyan
    readonly property color moss:  pal.glass
    readonly property real ui: pal.uiScale
    function ivoryA(a) { return Qt.rgba(ivory.r, ivory.g, ivory.b, a) }
    function goldA(a)  { return Qt.rgba(gold.r, gold.g, gold.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1200; easing.type: Easing.OutCubic }

    // minute flourish: one petal drifts off the blossom, a glint crosses the line
    property int _lastMin: -1
    Connections {
        target: clock
        function onDateChanged() {
            const m = clock.date.getMinutes()
            if (root._lastMin >= 0 && m !== root._lastMin && root.bootT >= 1) {
                petalFall.restart()
                glintAnim.restart()
            }
            root._lastMin = m
        }
    }

    // soft moss shadow so the ivory reads over sunlit fabric
    Canvas {
        id: scrim
        x: block.x + block.width / 2 - width / 2
        y: block.y + block.height / 2 - height / 2
        width: block.width * 2.1
        height: block.height * 2.4
        opacity: root.bootT
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const g = ctx.createRadialGradient(width / 2, height / 2, 0,
                                               width / 2, height / 2, Math.min(width, height) / 2)
            g.addColorStop(0, Qt.rgba(root.moss.r, root.moss.g, root.moss.b, 0.55))
            g.addColorStop(1, Qt.rgba(root.moss.r, root.moss.g, root.moss.b, 0))
            ctx.fillStyle = g
            ctx.fillRect(0, 0, width, height)
        }
        Connections {
            target: root.pal
            function onGlassChanged() { scrim.requestPaint() }
        }
    }

    Column {
        id: block
        anchors.right: parent.right
        anchors.rightMargin: Math.round(root.width * 0.055)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.10)
        spacing: 12
        opacity: root.bootT
        transform: Translate { y: 20 * (1 - root.bootT) }
        scale: root.ui
        transformOrigin: Item.BottomRight

        Text {
            anchors.right: parent.right
            text: "a v a l o n"
            color: root.goldA(0.85)
            font.family: "Noto Serif Display"
            font.pixelSize: 13
            font.letterSpacing: 9
            font.italic: true
        }

        Text {
            id: timeText
            anchors.right: parent.right
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: root.ivory
            font.family: "Noto Serif Display"
            font.pixelSize: 118
            font.weight: Font.Light
            font.letterSpacing: 3
        }

        // gold hairline, drawn in from the right; blossom rests at its start
        Item {
            id: rule
            anchors.right: parent.right
            width: timeText.width
            height: 16

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * root.bootT
                height: 1
                color: root.goldA(0.45)
            }
            // the glint that crosses on the minute
            Rectangle {
                id: glint
                anchors.verticalCenter: parent.verticalCenter
                width: 46; height: 1
                color: root.ivoryA(0.9)
                opacity: 0
            }
            SequentialAnimation {
                id: glintAnim
                ParallelAnimation {
                    NumberAnimation { target: glint; property: "x"; from: rule.width - 46; to: 24; duration: 900; easing.type: Easing.InOutSine }
                    SequentialAnimation {
                        NumberAnimation { target: glint; property: "opacity"; to: 0.75; duration: 150 }
                        PauseAnimation { duration: 500 }
                        NumberAnimation { target: glint; property: "opacity"; to: 0; duration: 250 }
                    }
                }
            }

            Blossom {
                id: bloom
                anchors.verticalCenter: parent.verticalCenter
                x: 0
                size: 15
                scale: root.bootT
            }

            // the petal that lets go
            Petal {
                id: fallPetal
                x: bloom.x + 4
                y: 0
                size: 7
                opacity: 0
            }
            ParallelAnimation {
                id: petalFall
                NumberAnimation { target: fallPetal; property: "y"; from: 2; to: 74; duration: 2600; easing.type: Easing.InQuad }
                NumberAnimation { target: fallPetal; property: "x"; from: bloom.x + 4; to: bloom.x - 26; duration: 2600; easing.type: Easing.InOutSine }
                NumberAnimation { target: fallPetal; property: "rotation"; from: 0; to: -140; duration: 2600 }
                SequentialAnimation {
                    NumberAnimation { target: fallPetal; property: "opacity"; to: 0.85; duration: 200 }
                    PauseAnimation { duration: 1500 }
                    NumberAnimation { target: fallPetal; property: "opacity"; to: 0; duration: 900 }
                }
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 12

            Text {
                text: Qt.formatDateTime(clock.date, "dddd").toUpperCase()
                color: root.ivoryA(0.55)
                font.family: "Noto Sans"
                font.pixelSize: 14
                font.letterSpacing: 6
            }
            Rectangle {
                width: 5; height: 5
                rotation: 45
                color: root.leaf
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: Qt.formatDateTime(clock.date, "MMMM dd").toUpperCase()
                color: root.ivoryA(0.55)
                font.family: "Noto Sans"
                font.pixelSize: 14
                font.letterSpacing: 6
            }
        }
    }

    // five ivory petals around a gold heart
    component Blossom: Canvas {
        property real size: 14
        width: size * 2
        height: size * 2
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const c = size, pr = size * 0.62
            ctx.fillStyle = root.ivoryA(0.92)
            // qt canvas ellipse() can't rotate: unit arc under a scale transform
            for (let i = 0; i < 5; i++) {
                const a = -Math.PI / 2 + i * Math.PI * 2 / 5
                ctx.save()
                ctx.translate(c + Math.cos(a) * pr * 0.72, c + Math.sin(a) * pr * 0.72)
                ctx.rotate(a + Math.PI / 2)
                ctx.scale(pr * 0.34, pr * 0.60)
                ctx.beginPath()
                ctx.arc(0, 0, 1, 0, Math.PI * 2)
                ctx.restore()
                ctx.fill()
            }
            ctx.beginPath()
            ctx.arc(c, c, size * 0.22, 0, Math.PI * 2)
            ctx.fillStyle = root.gold
            ctx.fill()
        }
        Connections {
            target: root.pal
            function onTextChanged() { requestPaint() }
            function onCyanChanged() { requestPaint() }
        }
    }

    component Petal: Canvas {
        property real size: 7
        width: size * 2
        height: size * 2
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.save()
            ctx.translate(size, size)
            ctx.rotate(0.5)
            ctx.scale(size * 0.45, size * 0.8)
            ctx.beginPath()
            ctx.arc(0, 0, 1, 0, Math.PI * 2)
            ctx.restore()
            ctx.fillStyle = root.ivoryA(0.9)
            ctx.fill()
        }
    }
}
