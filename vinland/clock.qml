import QtQuick
import Quickshell

// vinland: desktop clock, top-left in the empty night sky. Snow serif time
// over a carved stave (a hairline with rune-notch ticks), the north star
// resting at its end. On the minute the star flares and a shooting star
// slips down across the sky under the time.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color snow:  pal.text
    readonly property color ice:   pal.neon
    readonly property color gold:  pal.cyan
    readonly property color night: pal.glass
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"
    function snowA(a) { return Qt.rgba(snow.r, snow.g, snow.b, a) }
    function iceA(a)  { return Qt.rgba(ice.r, ice.g, ice.b, a) }
    function goldA(a) { return Qt.rgba(gold.r, gold.g, gold.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1200; easing.type: Easing.OutCubic }

    // minute flourish: the star flares, a shooting star crosses beneath the time
    property int _lastMin: -1
    Connections {
        target: clock
        function onDateChanged() {
            const m = clock.date.getMinutes()
            if (root._lastMin >= 0 && m !== root._lastMin && root.bootT >= 1) {
                starFlare.restart()
                shootAnim.restart()
            }
            root._lastMin = m
        }
    }

    // a breath of night behind the block so the snow text reads over pale clouds
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
            g.addColorStop(0, Qt.rgba(root.night.r, root.night.g, root.night.b, 0.42))
            g.addColorStop(1, Qt.rgba(root.night.r, root.night.g, root.night.b, 0))
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
        anchors.left: parent.left
        anchors.leftMargin: Math.round(root.width * 0.055)
        anchors.top: parent.top
        anchors.topMargin: Math.round(root.height * 0.09)
        spacing: 12
        opacity: root.bootT
        transform: Translate { y: -16 * (1 - root.bootT) }
        scale: root.ui
        transformOrigin: Item.TopLeft

        Text {
            text: "ᚹᛁᚾᛚᚨᚾᛞ"
            color: root.iceA(0.72)
            font.family: "Noto Sans Runic"
            font.pixelSize: 15
            font.letterSpacing: 9
        }

        Text {
            id: timeText
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: root.snow
            font.family: root.serif
            font.pixelSize: 118
            font.weight: Font.Light
            font.letterSpacing: 3
        }

        // the carved stave: hairline drawn in from the left, rune-notch ticks,
        // the north star resting at its far end
        Item {
            id: rule
            width: timeText.width
            height: 18

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * root.bootT
                height: 1
                color: root.iceA(0.40)
            }
            // three knife-notches along the line
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    x: rule.width * (0.22 + index * 0.22)
                    anchors.verticalCenter: rule.verticalCenter
                    width: 1; height: 5
                    rotation: 20
                    color: root.iceA(0.40)
                    opacity: root.bootT >= (0.25 + index * 0.22) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
            }

            // the shooting star: a slanted glint slipping down-left on the minute
            Rectangle {
                id: shoot
                width: 52; height: 1
                rotation: -14
                color: root.snowA(0.9)
                opacity: 0
            }
            SequentialAnimation {
                id: shootAnim
                ParallelAnimation {
                    NumberAnimation { target: shoot; property: "x"; from: rule.width - 40; to: rule.width * 0.28; duration: 950; easing.type: Easing.InOutSine }
                    NumberAnimation { target: shoot; property: "y"; from: -6; to: 14; duration: 950; easing.type: Easing.InOutSine }
                    SequentialAnimation {
                        NumberAnimation { target: shoot; property: "opacity"; to: 0.8; duration: 140 }
                        PauseAnimation { duration: 480 }
                        NumberAnimation { target: shoot; property: "opacity"; to: 0; duration: 330 }
                    }
                }
            }

            NorthStar {
                id: star
                anchors.verticalCenter: parent.verticalCenter
                x: rule.width * root.bootT - width / 2
                size: 16
                tint: root.gold
            }
            SequentialAnimation {
                id: starFlare
                NumberAnimation { target: star; property: "scale"; to: 1.6; duration: 260; easing.type: Easing.OutQuad }
                NumberAnimation { target: star; property: "scale"; to: 1.0; duration: 700; easing.type: Easing.OutCubic }
            }
        }

        Row {
            spacing: 12

            Text {
                text: Qt.formatDateTime(clock.date, "dddd").toUpperCase()
                color: root.snowA(0.55)
                font.family: "Noto Sans"
                font.pixelSize: 14
                font.letterSpacing: 6
            }
            Rectangle {
                width: 5; height: 5
                rotation: 45
                color: root.goldA(0.85)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: Qt.formatDateTime(clock.date, "MMMM dd").toUpperCase()
                color: root.snowA(0.55)
                font.family: "Noto Sans"
                font.pixelSize: 14
                font.letterSpacing: 6
            }
        }
    }

    // a thin four-point star — the theme's signature
    component NorthStar: Canvas {
        property real size: 14
        property color tint: root.gold
        width: size; height: size
        onTintChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const c = size / 2, R = size / 2
            ctx.beginPath()
            ctx.moveTo(c, c - R)
            ctx.quadraticCurveTo(c, c, c + R, c)
            ctx.quadraticCurveTo(c, c, c, c + R)
            ctx.quadraticCurveTo(c, c, c - R, c)
            ctx.quadraticCurveTo(c, c, c, c - R)
            ctx.closePath()
            ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.95)
            ctx.fill()
        }
        Connections {
            target: root.pal
            function onCyanChanged() { requestPaint() }
        }
    }
}
