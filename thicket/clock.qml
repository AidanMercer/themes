import QtQuick
import Quickshell

// thicket: the time, sighted through a gap in the leaves. Upper-left canopy
// shadow: a dark hollow opens in the foliage and the hour sits inside it in
// serif — something read off a watch through parted branches. Leaf
// silhouettes (the house LeafSpray renderer) crowd the gap's rim. Nothing
// sways: when the minute turns, the changed digits DART — the old glyph
// flicks down and away like a startled leaf, the new one lands in one quick
// move — the rim rustles once, a patch of dappled ember light jumps to a new
// spot over the digits, and everything freezes again. Click-through scenery;
// no loops run at all (event-driven only), so idle costs nothing.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while locked or a fullscreen window covers the monitor
    property bool occluded: false

    readonly property color ember: pal.neon
    readonly property color iris: pal.cyan
    readonly property color emberRed: pal.magenta
    readonly property color dapple: pal.amber
    readonly property color leaf: pal.dim
    readonly property color ink: pal.text
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    function emberA(a)  { return Qt.rgba(ember.r, ember.g, ember.b, a) }
    function inkA(a)    { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function leafA(a)   { return Qt.rgba(leaf.r, leaf.g, leaf.b, a) }
    function dappleA(a) { return Qt.rgba(dapple.r, dapple.g, dapple.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // deterministic hash — the same thicket every mount
    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // ── a digit that darts: old glyph flicks away, new one lands ───────────
    component DartDigit: Item {
        id: dd
        property string target: " "
        property real size: 96
        width: Math.ceil(size * 0.62)
        height: Math.ceil(size * 1.2)

        property string cur: " "
        property string old: " "
        property real t: 1   // 0 = mid-dart, 1 = settled

        onTargetChanged: {
            if (target === cur) return
            old = cur; cur = target
            dart.restart()
        }
        Component.onCompleted: cur = target
        NumberAnimation {
            id: dart
            target: dd; property: "t"
            from: 0; to: 1; duration: 240
            easing.type: Easing.OutQuint
        }

        // the leaving glyph: flicks down-right and is gone
        Text {
            visible: dd.t < 1
            opacity: Math.max(0, 1 - dd.t * 2.2)
            x: dd.t * dd.size * 0.22
            y: dd.t * dd.size * 0.34
            rotation: dd.t * 14
            text: dd.old
            color: root.leafA(0.9)
            font.family: root.serif
            font.pixelSize: dd.size
        }
        // the arriving glyph: lands in one quick move from just above
        Text {
            opacity: Math.min(1, 0.25 + dd.t * 0.75)
            y: -(1 - dd.t) * dd.size * 0.10
            text: dd.cur
            color: root.ink
            font.family: root.serif
            font.pixelSize: dd.size
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.65)
        }
    }

    // ── the hollow ──────────────────────────────────────────────────────────
    Item {
        id: hollow
        x: Math.round(root.width * 0.055)
        y: Math.round(root.height * 0.115)
        width: 560
        height: 300
        scale: pal.uiScale
        transformOrigin: Item.TopLeft

        opacity: 0
        NumberAnimation on opacity { running: true; to: 1; duration: 420; easing.type: Easing.OutQuad }

        // the dark of the gap — deep shadow so the serif reads on any frame
        Canvas {
            id: shade
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const g = ctx.createRadialGradient(width * 0.42, height * 0.44, 10,
                                                   width * 0.42, height * 0.44, width * 0.55)
                g.addColorStop(0, "rgba(4,8,6,0.62)")
                g.addColorStop(0.75, "rgba(4,8,6,0.34)")
                g.addColorStop(1, "rgba(4,8,6,0)")
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, height)
            }
            Component.onCompleted: requestPaint()
        }

        // the dapple: one warm patch of light lying over the digits; it JUMPS
        // to a new deterministic spot each minute — a dart, then stillness
        Canvas {
            id: dappleSpot
            width: 190; height: 120
            property int seed: 0
            x: 60 + root.rnd(seed * 7 + 1) * 240
            y: 40 + root.rnd(seed * 13 + 5) * 90
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
            opacity: 0.8
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const g = ctx.createRadialGradient(width / 2, height / 2, 4,
                                                   width / 2, height / 2, width / 2)
                g.addColorStop(0, String(root.dappleA(0.14)))
                g.addColorStop(0.6, String(root.dappleA(0.06)))
                g.addColorStop(1, String(root.dappleA(0)))
                ctx.fillStyle = g
                ctx.save(); ctx.translate(width / 2, height / 2); ctx.rotate(-0.35)
                ctx.scale(1, height / width); ctx.translate(-width / 2, -height / 2)
                ctx.fillRect(-width * 0.5, -height * 0.5, width * 2, height * 2)
                ctx.restore()
            }
            Component.onCompleted: requestPaint()
            Connections {
                target: root.pal
                function onAmberChanged() { dappleSpot.requestPaint() }
            }
        }

        // ── the rim of leaves around the gap — parts with a rustle ─────────
        Canvas {
            id: rim
            anchors.fill: parent
            property real rustleT: 1   // 0 = darted apart, 1 = settled
            onRustleTChanged: requestPaint()
            onWidthChanged: requestPaint()
            Component.onCompleted: requestPaint()
            Connections {
                target: root.pal
                function onDimChanged() { rim.requestPaint() }
                function onGlassChanged() { rim.requestPaint() }
            }
            function drawLeaf(ctx, x, y, len, wid, ang, fill) {
                ctx.save()
                ctx.translate(x, y); ctx.rotate(ang)
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.quadraticCurveTo(len * 0.42, -wid, len, -wid * 0.08)
                ctx.quadraticCurveTo(len * 0.46, wid * 0.9, 0, 0)
                ctx.closePath()
                ctx.fillStyle = fill
                ctx.fill()
                ctx.restore()
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height
                // two arcs of leaves: upper-left crowd and lower-right stragglers
                for (let i = 0; i < 26; i++) {
                    const upper = i < 16
                    const f = upper ? i / 15 : (i - 16) / 9
                    const bx = upper ? w * (0.02 + f * 0.72) : w * (0.34 + f * 0.6)
                    const by = upper ? h * 0.10 - Math.sin(f * Math.PI) * h * 0.055
                                     : h * 0.86 + Math.sin(f * Math.PI) * h * 0.05
                    const ang = (upper ? 0.5 : -0.6) + (root.rnd(i * 31 + 2) - 0.5) * 1.5
                                + (upper ? Math.PI : 0)
                    const len = 26 + root.rnd(i * 17 + 9) * 30
                    const wid = 6 + root.rnd(i * 23 + 4) * 7
                    // the dart: each leaf springs outward and settles back
                    const amp = (1 - rustleT) * (5 + root.rnd(i * 11 + 3) * 9)
                    const ox = Math.cos(ang) * amp
                    const oy = Math.sin(ang) * amp
                    const teal = root.rnd(i * 41 + 6) < 0.3
                    const col = teal ? Qt.rgba(0.13, 0.25, 0.22, 0.85)
                                     : root.leafA(0.5 + root.rnd(i * 13) * 0.35)
                    drawLeaf(ctx, bx + ox, by + oy, len, wid, ang, String(col))
                }
            }
            NumberAnimation {
                id: rustle
                target: rim; property: "rustleT"
                from: 0; to: 1; duration: 320
                easing.type: Easing.OutQuint
            }
        }

        Column {
            x: 66
            y: 44
            spacing: 2

            Row {
                id: digitRow
                spacing: 2
                DartDigit { target: root.hhmm.charAt(0) }
                DartDigit { target: root.hhmm.charAt(1) }
                Text {   // the colon holds still — the thicket doesn't fidget
                    text: ":"
                    color: root.inkA(0.85)
                    font.family: root.serif
                    font.pixelSize: 96
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.65)
                }
                DartDigit { target: root.hhmm.charAt(3) }
                DartDigit { target: root.hhmm.charAt(4) }
            }

            Text {
                text: Qt.formatDateTime(clock.date, "dddd d MMMM")
                color: root.dappleA(0.75)
                font.family: root.serif
                font.italic: true
                font.pixelSize: 17
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.5)
            }
        }

        // the minute turns: the rim rustles once, the light patch jumps
        Connections {
            target: clock
            function onDateChanged() {
                if (root.occluded || hollow.opacity < 1) return
                rustle.restart()
                dappleSpot.seed = Math.floor(clock.date.getTime() / 60000) % 997
            }
        }
    }
}
