import QtQuick
import Quickshell

// pines: the station clock, hung in the moonlit upper-left sky. Thin serif
// numerals like a hand-lettered log heading, under a "PINES-9 LOOKOUT" small-
// caps header with the kerosene lamp pip breathing beside it. Nothing fades:
// when the minute turns, the changed digits dissolve into fog (double ghost
// copies drifting apart, defocus read) and the new digits CONDENSE back out
// of it — the house transition. Below, a bearing rule (hairline + degree
// ticks + the benchmark triangle) underlines the date, and once a minute a
// bead of condensation runs down the glass beside the time and is gone.
// Click-through scenery; everything stops while occluded. Also loaded on the
// lock screen — the dark halo keeps it legible over the blur.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while locked or a fullscreen window covers the monitor
    property bool occluded: false

    readonly property color lamp: pal.neon
    readonly property color fogSilver: pal.cyan
    readonly property color ember: pal.magenta
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    function lampA(a)   { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function silverA(a) { return Qt.rgba(fogSilver.r, fogSilver.g, fogSilver.b, a) }
    function inkA(a)    { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function slateA(a)  { return Qt.rgba(slate.r, slate.g, slate.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // ── a glyph that condenses out of fog and dissolves back into it ────────
    // t = 1 condensed (crisp, ghosts gone); t = 0 fog (ghosts apart, faint).
    // On a target change the old glyph dissolves, swaps at the fog point,
    // and the new one condenses — precipitation, not a fade.
    component CondenseGlyph: Item {
        id: cg
        property string target: ""
        property string ch: ""
        property real px: 96
        property color face: root.ink
        property real t: 0
        width: crisp.implicitWidth
        height: crisp.implicitHeight

        Text {
            id: crisp
            text: cg.ch
            color: cg.face
            font.family: root.serif
            font.pixelSize: cg.px
            font.weight: Font.Light
            style: Text.Outline
            styleColor: Qt.rgba(0.01, 0.04, 0.07, 0.55)
            opacity: cg.t * cg.t
        }
        // the fog ghosts: two soft copies drifting apart as t falls
        Text {
            text: cg.ch
            color: root.silverA(0.4)
            font.family: root.serif
            font.pixelSize: cg.px
            font.weight: Font.Light
            x: -6 * (1 - cg.t); y: -4 * (1 - cg.t)
            scale: 1 + 0.10 * (1 - cg.t)
            opacity: 0.55 * (1 - cg.t) * Math.min(1, cg.t * 4 + 0.35)
        }
        Text {
            text: cg.ch
            color: root.silverA(0.3)
            font.family: root.serif
            font.pixelSize: cg.px
            font.weight: Font.Light
            x: 5 * (1 - cg.t); y: 4 * (1 - cg.t)
            scale: 1 + 0.06 * (1 - cg.t)
            opacity: 0.45 * (1 - cg.t) * Math.min(1, cg.t * 4 + 0.35)
        }

        SequentialAnimation {
            id: recondense
            NumberAnimation { target: cg; property: "t"; to: 0; duration: 340; easing.type: Easing.InQuad }
            ScriptAction { script: cg.ch = cg.target }
            NumberAnimation { target: cg; property: "t"; to: 1; duration: 520; easing.type: Easing.OutCubic }
        }
        onTargetChanged: {
            if (cg.ch === "") { cg.ch = target; condenseIn.restart() }
            else if (target !== cg.ch) recondense.restart()
        }
        NumberAnimation { id: condenseIn; target: cg; property: "t"; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
        Component.onCompleted: if (ch === "" && target !== "") { ch = target; condenseIn.restart() }
    }

    // the benchmark triangle — the house survey mark
    component BenchMark: Canvas {
        id: bm
        property color tone: root.silverA(0.8)
        width: 13; height: 11
        onToneChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = String(tone)
            ctx.lineWidth = 1.2
            ctx.beginPath()
            ctx.moveTo(width / 2, 1)
            ctx.lineTo(width - 1, height - 1.5)
            ctx.lineTo(1, height - 1.5)
            ctx.closePath()
            ctx.stroke()
            ctx.fillStyle = String(tone)
            ctx.fillRect(width / 2 - 1, height * 0.52, 2, 2)
        }
    }

    // ── the ensemble, in the moonlit sky ────────────────────────────────────
    Item {
        id: station
        x: Math.round(root.width * 0.07)
        y: Math.round(root.height * 0.09)
        width: col.implicitWidth
        height: col.implicitHeight
        scale: pal.uiScale
        transformOrigin: Item.TopLeft

        // a pool of darkness behind the log so it reads over bright cloud
        Rectangle {
            anchors.centerIn: col
            width: col.implicitWidth * 1.7
            height: col.implicitHeight * 1.5
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0.01, 0.04, 0.07, 0.34) }
                GradientStop { position: 1.0; color: Qt.rgba(0.01, 0.04, 0.07, 0.0) }
            }
        }

        Column {
            id: col
            spacing: 12

            // header: lamp pip + station name
            Row {
                spacing: 10
                Rectangle {
                    id: lampPip
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7; height: 7; radius: 3.5
                    color: root.lamp
                    // the kerosene flame breathes — slow, uneven, only when seen
                    SequentialAnimation on opacity {
                        running: !root.occluded && root.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.45; duration: 1900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1300; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.7; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1500; easing.type: Easing.InOutSine }
                    }
                    Rectangle {   // faint halo
                        anchors.centerIn: parent
                        width: 19; height: 19; radius: 9.5
                        color: root.lampA(0.12)
                        z: -1
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "PINES-9 LOOKOUT"
                    color: root.inkA(0.62)
                    font.family: root.serif
                    font.pixelSize: 13
                    font.letterSpacing: 7
                }
            }

            // the time — each digit its own weather
            Row {
                id: timeRow
                spacing: 4
                CondenseGlyph { target: root.hhmm.charAt(0) }
                CondenseGlyph { target: root.hhmm.charAt(1) }
                CondenseGlyph {
                    target: ":"
                    px: 84
                    face: root.silverA(0.85)
                    anchors.verticalCenter: parent.verticalCenter
                }
                CondenseGlyph { target: root.hhmm.charAt(3) }
                CondenseGlyph { target: root.hhmm.charAt(4) }
            }

            // bearing rule: benchmark, hairline, degree ticks
            Item {
                width: timeRow.width
                height: 12
                BenchMark { x: 0; y: 0 }
                Rectangle {
                    x: 20; y: 5
                    width: parent.width - 20
                    height: 1
                    color: root.slateA(0.9)
                }
                Repeater {
                    model: 9
                    Rectangle {
                        required property int index
                        x: 20 + (index + 1) * (timeRow.width - 26) / 10
                        y: index % 2 === 0 ? 2 : 3.5
                        width: 1
                        height: index % 2 === 0 ? 7 : 4
                        color: root.silverA(index % 2 === 0 ? 0.55 : 0.35)
                    }
                }
            }

            // the log line
            Row {
                spacing: 14
                Text {
                    text: "NIGHT WATCH"
                    color: root.lampA(0.75)
                    font.family: root.mono
                    font.pixelSize: 11
                    font.letterSpacing: 4
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "ddd d MMM").toUpperCase()
                    color: root.inkA(0.7)
                    font.family: root.mono
                    font.pixelSize: 11
                    font.letterSpacing: 4
                }
                Text {
                    text: "ELEV 2130 M"
                    color: root.silverA(0.45)
                    font.family: root.mono
                    font.pixelSize: 11
                    font.letterSpacing: 4
                }
            }
        }

        // once a minute: a bead of condensation runs down the glass beside
        // the time — gathers, slips in two pulls, thins away
        Item {
            id: bead
            property real t: -1
            visible: t >= 0
            x: -26
            y: 34 + 96 * (t < 0 ? 0 : (t < 0.55 ? t * t * 2.4 : 0.72 + (t - 0.55) * 0.62))
            Rectangle {   // the droplet
                width: 4; height: 6; radius: 2
                color: root.silverA(0.85)
            }
            Rectangle {   // its trailing streak
                x: 1.2; y: -14
                width: 1.4; height: 14
                color: root.silverA(0.30)
            }
            opacity: t < 0 ? 0 : (t < 0.1 ? t * 10 : 1 - Math.max(0, t - 0.75) * 4)
            NumberAnimation {
                id: beadAnim
                target: bead; property: "t"
                from: 0; to: 1; duration: 1500; easing.type: Easing.Linear
                onStopped: bead.t = -1
            }
        }
        Connections {
            target: clock
            function onDateChanged() { if (!root.occluded && root.visible) beadAnim.restart() }
        }
    }
}
