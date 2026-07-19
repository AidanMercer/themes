import QtQuick
import Quickshell
import "chalk.js" as Chalk

// homeroom: the time, chalked on the morning sky up and left of the boards.
// The digits are WRITTEN — the chalk.js stroke font reveals each glyph
// tip-first with hand jitter — and when the minute turns the stale digit
// goes under the eraser (a pale dry smudge sweeps it away) before the new
// one is written in its place. When the fresh minute lands, the halo — the
// room's one supernatural thing — draws itself in above the time, hangs a
// breath, and fades. Date under a jittered chalk rule. Click-through
// scenery; everything stops while occluded.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while locked or a fullscreen window covers the monitor
    property bool occluded: false

    readonly property color chalk: pal.text
    readonly property color halo: pal.neon
    readonly property string mono: pal.fontMono
    function chalkA(a) { return Qt.rgba(chalk.r, chalk.g, chalk.b, a) }
    function haloA(a)  { return Qt.rgba(halo.r, halo.g, halo.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // ── a chalk digit: erased, then rewritten ──────────────────────────────
    component ChalkDigit: Canvas {
        id: cd
        property string target: " "
        property string ch: " "
        property real cell: 84          // glyph box height
        property real reveal: 1         // 0..1 write progress
        property real eraseT: 0         // 0..1 smudge progress
        property int seed: 1
        width: cell * 0.78
        height: cell

        onRevealChanged: requestPaint()
        onEraseTChanged: requestPaint()

        SequentialAnimation {
            id: rewrite
            // the eraser takes the old digit…
            NumberAnimation { target: cd; property: "eraseT"; from: 0; to: 1; duration: 240; easing.type: Easing.InOutQuad }
            PropertyAction  { target: cd; property: "ch"; value: cd.target }
            PropertyAction  { target: cd; property: "eraseT"; value: 0 }
            // …and the hand writes the new one
            NumberAnimation { target: cd; property: "reveal"; from: 0; to: 1; duration: 520; easing.type: Easing.InOutSine }
        }
        onTargetChanged: {
            if (root.occluded) {        // nobody's watching: just be correct
                rewrite.stop(); bootWrite.stop()
                ch = target; eraseT = 0; reveal = 1
                requestPaint()
            } else if (ch === " ") {    // boot: nothing to erase, just write
                ch = target
                bootWrite.restart()
            } else {
                rewrite.restart()
            }
        }
        NumberAnimation { id: bootWrite; target: cd; property: "reveal"; from: 0; to: 1; duration: 700; easing.type: Easing.InOutSine }
        Component.onCompleted: if (ch === " " && target !== " ") { ch = target; bootWrite.restart() }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            if (eraseT > 0) {
                // fading old glyph under the smudge
                ctx.globalAlpha = Math.max(0, 1 - eraseT * 1.1)
                Chalk.drawGlyph(ctx, ch, 0, 0, w, h, {
                    seed: seed, color: String(root.chalkA(0.92)), alpha: 0.92,
                    width: Math.max(2.5, h * 0.075), reveal: 1
                })
                ctx.globalAlpha = 1
                Chalk.drawSmudge(ctx, 0, 0, w, h, eraseT, String(root.chalkA(1)), seed)
            } else {
                Chalk.drawGlyph(ctx, ch, 0, 0, w, h, {
                    seed: seed, color: String(root.chalkA(0.92)), alpha: 0.92,
                    width: Math.max(2.5, h * 0.075), reveal: reveal
                })
            }
        }
        Connections {
            target: root.pal
            function onTextChanged() { cd.requestPaint() }
        }
    }

    // ── the ensemble, on the open sky upper-left ───────────────────────────
    Item {
        id: sign
        x: Math.round(root.width * 0.065)
        y: Math.round(root.height * 0.085)
        scale: pal.uiScale
        transformOrigin: Item.TopLeft

        opacity: 0
        NumberAnimation on opacity { running: true; to: 1; duration: 400 }

        // header: pinned name-tag voice, settles slightly crooked
        Item {
            id: header
            y: 0
            rotation: -1.2
            transformOrigin: Item.TopLeft
            SequentialAnimation {
                id: headerPin
                running: true
                NumberAnimation { target: header; property: "y"; from: -10; to: 2; duration: 260; easing.type: Easing.OutQuad }
                NumberAnimation { target: header; property: "y"; from: 2; to: 0; duration: 140; easing.type: Easing.OutQuad }
            }
            Row {
                spacing: 10
                Rectangle {    // a small ring pip — the halo's understudy
                    anchors.verticalCenter: parent.verticalCenter
                    width: 11; height: 11; radius: 5.5
                    color: "transparent"
                    border.width: 2
                    border.color: root.haloA(0.85)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "MORNING HOMEROOM"
                    color: root.chalkA(0.62)
                    font.family: root.mono
                    font.pixelSize: 12
                    font.letterSpacing: 6
                }
            }
        }

        // the time, written in chalk
        Row {
            id: digitRow
            y: 34
            spacing: 12
            ChalkDigit { target: root.hhmm.charAt(0); seed: 11 }
            ChalkDigit { target: root.hhmm.charAt(1); seed: 23 }
            ChalkDigit { target: root.hhmm.charAt(2); seed: 37; width: cell * 0.42 }
            ChalkDigit { target: root.hhmm.charAt(3); seed: 41 }
            ChalkDigit { target: root.hhmm.charAt(4); seed: 53 }
        }

        // the chalk rule + date
        Canvas {
            id: rule
            y: 136
            width: digitRow.width
            height: 10
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                Chalk.strokePath(ctx, [[2, 5], [width - 2, 4]], {
                    seed: 71, color: String(root.chalkA(1)), alpha: 0.5,
                    width: 2.6, dust: 0.14
                })
            }
            Component.onCompleted: requestPaint()
            Connections {
                target: root.pal
                function onTextChanged() { rule.requestPaint() }
            }
        }
        Text {
            y: 152
            text: Qt.formatDateTime(clock.date, "dddd d MMMM").toLowerCase()
            color: root.chalkA(0.66)
            font.family: root.mono
            font.pixelSize: 14
            font.letterSpacing: 5
        }

        // ── the halo: draws itself in above the time when the minute lands ──
        Canvas {
            id: haloRing
            x: digitRow.width - 44
            y: 6
            width: 64
            height: 30
            property real sweep: 0     // 0..1 arc draw-in
            property real glow: 0      // 0..1 presence
            visible: glow > 0.01
            onSweepChanged: requestPaint()
            onGlowChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                if (glow <= 0.01 || sweep <= 0.01) return
                const cx = width / 2, cy = height / 2
                const rx = width * 0.42, ry = height * 0.34
                const a0 = -Math.PI * 0.5
                const a1 = a0 + Math.PI * 2 * sweep
                // wide soft pass, then the clean bright ring — supernatural,
                // not chalk: no jitter, a perfect line
                ctx.save()
                ctx.translate(cx, cy)
                ctx.scale(1, ry / rx)
                ctx.beginPath()
                ctx.arc(0, 0, rx, a0, a1)
                ctx.strokeStyle = String(root.haloA(0.22 * glow))
                ctx.lineWidth = 9
                ctx.lineCap = "round"
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(0, 0, rx, a0, a1)
                ctx.strokeStyle = String(root.haloA(0.95 * glow))
                ctx.lineWidth = 3
                ctx.stroke()
                ctx.restore()
            }
            SequentialAnimation {
                id: haloFlourish
                PropertyAction  { target: haloRing; property: "sweep"; value: 0 }
                PropertyAction  { target: haloRing; property: "glow"; value: 1 }
                NumberAnimation { target: haloRing; property: "sweep"; from: 0; to: 1; duration: 550; easing.type: Easing.InOutQuad }
                PauseAnimation  { duration: 900 }
                NumberAnimation { target: haloRing; property: "glow"; from: 1; to: 0; duration: 700; easing.type: Easing.InQuad }
            }
        }
        Connections {
            target: clock
            function onDateChanged() { if (!root.occluded && sign.opacity === 1) haloFlourish.restart() }
        }
    }
}
