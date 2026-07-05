import QtQuick

// white: lock overlay. An ink-wash vignette breathes in from the paper's
// edges, a few ink flecks drift down, and a small enso brush-draws itself
// around the passcode dots as the lock engages. Wrong password inks the
// stroke rose; while PAM is checking, the brush pressure circles slowly.
// Drawn above LockContent (blurred wallpaper + the theme clock), and
// everything rides host.progress so the unlock plays it all backwards.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host

    readonly property color ink:      pal.text
    readonly property color wisteria: pal.neon
    readonly property color blush:    pal.cyan
    readonly property color rose:     pal.magenta
    readonly property real p: host.progress
    function inkA(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    // ── ink-wash vignette, seeping in from the edges ─────────────────────────
    Rectangle {
        anchors.left: parent.left
        height: parent.height
        width: 170
        x: -60 * (1 - root.p)
        opacity: root.p
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.inkA(0.16) }
            GradientStop { position: 1.0; color: root.inkA(0) }
        }
    }
    Rectangle {
        anchors.right: parent.right
        height: parent.height
        width: 170
        x: parent.width - width + 60 * (1 - root.p)
        opacity: root.p
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.inkA(0) }
            GradientStop { position: 1.0; color: root.inkA(0.16) }
        }
    }
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 130
        y: -50 * (1 - root.p)
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.inkA(0.13) }
            GradientStop { position: 1.0; color: root.inkA(0) }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 130
        y: parent.height - height + 50 * (1 - root.p)
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.inkA(0) }
            GradientStop { position: 1.0; color: root.inkA(0.13) }
        }
    }

    // ── drifting ink flecks ──────────────────────────────────────────────────
    Repeater {
        model: 12
        Rectangle {
            id: fleck
            required property int index
            readonly property real seed: (index * 0.61803) % 1
            width: (1.5 + seed * 2.5) * pal.uiScale
            height: width
            radius: width / 2
            color: index % 5 === 0 ? root.blush : root.ink
            opacity: (0.10 + seed * 0.16) * root.p
            x: root.width * ((seed * 7.13) % 1)

            NumberAnimation on y {
                loops: Animation.Infinite
                from: -20 - fleck.seed * root.height * 0.3
                to: root.height + 20
                duration: 26000 + fleck.seed * 30000
            }
        }
    }

    // ── the lock enso, wrapped around the passcode dots ─────────────────────
    Canvas {
        id: enso
        readonly property real r0: 78 * pal.uiScale
        readonly property real box: r0 + 26 * pal.uiScale
        width: box * 2
        height: box * 2
        anchors.horizontalCenter: parent.horizontalCenter
        // centred on LockContent's passcode dots (bottom-anchored at 15%)
        y: Math.round(parent.height * 0.85) - 30 - box

        property real sweep: root.p
        property real drift: 0
        property color stroke: root.host.failed ? root.rose : root.ink
        Behavior on stroke { ColorAnimation { duration: 260 } }

        onSweepChanged: requestPaint()
        onDriftChanged: requestPaint()
        onStrokeChanged: requestPaint()

        // the brush keeps circling while PAM thinks
        NumberAnimation on drift {
            running: root.host.busy
            loops: Animation.Infinite
            from: 0; to: 360
            duration: 2600
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const c = box
            const gapA = -Math.PI / 2 + 0.35        // brush lifts near the top
            const gapHalf = 0.13
            const driftR = drift * Math.PI / 180
            const pressPhase = gapA + Math.PI * 1.2 + driftR

            // reveal as one brush sweep from the gap edge
            const sw = Math.max(0.001, Math.min(1, sweep)) * Math.PI * 2
            ctx.beginPath()
            ctx.moveTo(c, c)
            ctx.arc(c, c, box, gapA + gapHalf, gapA + gapHalf + sw, false)
            ctx.closePath()
            ctx.clip()

            const N = 72
            const ox = [], oy = [], ix = [], iy = []
            for (let j = 0; j < N; j++) {
                const a = gapA + gapHalf + (j / N) * Math.PI * 2
                const dGap = Math.min(
                    Math.abs(((a - gapA) % (Math.PI * 2) + Math.PI * 3) % (Math.PI * 2) - Math.PI),
                    Math.PI)
                const taper = Math.min(1, Math.max(0, (dGap - gapHalf) / 0.5))
                const press = Math.pow(0.5 + 0.5 * Math.cos(a - pressPhase), 1.6)
                // a little deterministic hand-wobble so it reads brushed, not drawn
                const wob = Math.sin(j * 0.26) * 1.4 + Math.sin(j * 0.11 + 2.1) * 1.0
                const w = ((2.0 + 6.0 * press) * pal.uiScale) * taper
                const r = r0 + wob * pal.uiScale
                const ca = Math.cos(a), sa = Math.sin(a)
                ox.push(c + (r + w / 2) * ca); oy.push(c + (r + w / 2) * sa)
                ix.push(c + (r - w / 2) * ca); iy.push(c + (r - w / 2) * sa)
            }

            ctx.beginPath()
            ctx.moveTo((ox[N - 1] + ox[0]) / 2, (oy[N - 1] + oy[0]) / 2)
            for (let j = 0; j < N; j++) {
                const k = (j + 1) % N
                ctx.quadraticCurveTo(ox[j], oy[j], (ox[j] + ox[k]) / 2, (oy[j] + oy[k]) / 2)
            }
            ctx.moveTo((ix[0] + ix[N - 1]) / 2, (iy[0] + iy[N - 1]) / 2)
            for (let j = N - 1; j >= 0; j--) {
                const k = (j - 1 + N) % N
                ctx.quadraticCurveTo(ix[j], iy[j], (ix[j] + ix[k]) / 2, (iy[j] + iy[k]) / 2)
            }
            ctx.fillStyle = Qt.rgba(stroke.r, stroke.g, stroke.b, 0.72)
            ctx.fill()

            // first touch of the brush: a blush dot at the gap's edge
            {
                const a = gapA + gapHalf + 0.02
                ctx.beginPath()
                ctx.arc(c + r0 * Math.cos(a), c + r0 * Math.sin(a),
                        3 * pal.uiScale, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(root.blush.r, root.blush.g, root.blush.b, 0.9 * sweep)
                ctx.fill()
            }
        }
    }
}
