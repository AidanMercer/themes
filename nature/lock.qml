import QtQuick

// nature — "golden hour" lock overlay, drawn above the standard lock content
// (blurred wallpaper + the theme clock + password dots — already there).
// As the lock engages a deep forest shade closes in from the edges, daisy
// petals drift down through the shade, a few fireflies wake in the dark, and
// a thin blossom ring draws itself around the clock like a pressed-flower
// frame. Everything rides host.progress, so unlocking plays the shade back
// out while the petals scatter.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host

    readonly property color gold:  pal.neon
    readonly property color rose:  pal.magenta
    readonly property color cream: pal.text
    readonly property color pine:  pal.glass
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    function pineA(a)  { return Qt.rgba(pine.r * 0.6, pine.g * 0.6, pine.b * 0.6, a) }
    function goldA(a)  { return Qt.rgba(gold.r, gold.g, gold.b, a) }
    function creamA(a) { return Qt.rgba(cream.r, cream.g, cream.b, a) }

    // unlock: the petals scatter on the wind
    property real scatterT: 0
    Connections {
        target: root.host
        function onUnlockingChanged() {
            if (root.host.unlocking) scatterAnim.restart()
            else { scatterAnim.stop(); root.scatterT = 0 }
        }
    }
    NumberAnimation {
        id: scatterAnim
        target: root; property: "scatterT"
        from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic
    }

    // ── forest shade closing in from every edge ─────────────────────────────
    Rectangle {
        anchors.left: parent.left
        height: parent.height
        width: parent.width * 0.24
        x: -width * 0.5 * (1 - root.p)
        opacity: root.p
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.pineA(0.55) }
            GradientStop { position: 1.0; color: root.pineA(0) }
        }
    }
    Rectangle {
        anchors.right: parent.right
        height: parent.height
        width: parent.width * 0.24
        x: parent.width - width + width * 0.5 * (1 - root.p)
        opacity: root.p
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.pineA(0) }
            GradientStop { position: 1.0; color: root.pineA(0.55) }
        }
    }
    Rectangle {
        width: parent.width
        height: parent.height * 0.22
        y: -height * 0.5 * (1 - root.p)
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.pineA(0.5) }
            GradientStop { position: 1.0; color: root.pineA(0) }
        }
    }
    Rectangle {
        width: parent.width
        height: parent.height * 0.30
        y: parent.height - height + height * 0.5 * (1 - root.p)
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.pineA(0) }
            GradientStop { position: 1.0; color: root.pineA(0.6) }
        }
    }

    // ── drifting petals through the shade ───────────────────────────────────
    Repeater {
        model: 11
        Canvas {
            id: petal
            required property int index
            readonly property real seed: (index * 0.61803) % 1
            readonly property real baseX: root.width * ((seed * 9.17) % 1)
            readonly property real scatterDir: seed > 0.5 ? 1 : -1
            width: (12 + seed * 8) * root.ui
            height: width * 0.62
            property real fallY: -0.1
            x: baseX + Math.sin(fallY * 6.0 + seed * 6.28) * 46 * root.ui
                + root.scatterT * scatterDir * (160 + seed * 220) * root.ui
            y: fallY * root.height
            rotation: fallY * 260 * (seed > 0.6 ? 1 : -1) + seed * 90
            opacity: root.p * (0.5 + 0.4 * seed) * (1 - root.scatterT)

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.beginPath()
                ctx.moveTo(0, height * 0.6)
                ctx.quadraticCurveTo(width * 0.35, -height * 0.25, width, height * 0.35)
                ctx.quadraticCurveTo(width * 0.45, height * 1.1, 0, height * 0.6)
                const col = petal.index % 4 === 1 ? root.rose : root.cream
                ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, 0.9)
                ctx.fill()
            }
            Connections {
                target: root.pal
                function onTextChanged()    { petal.requestPaint() }
                function onMagentaChanged() { petal.requestPaint() }
            }

            NumberAnimation on fallY {
                running: root.p > 0.1
                loops: Animation.Infinite
                from: -0.12 - petal.seed * 0.3
                to: 1.1
                duration: 17000 + petal.seed * 16000
            }
        }
    }

    // ── fireflies waking in the forest shade ────────────────────────────────
    Repeater {
        model: 6
        Item {
            id: fly
            required property int index
            readonly property real seed: (index * 0.7548) % 1
            width: 26 * root.ui
            height: 26 * root.ui
            x: root.width * (0.08 + (seed * 5.33) % 0.84)
            y: root.height * (0.45 + (seed * 3.77) % 0.5)
            opacity: root.p

            // slow wander
            SequentialAnimation on x {
                running: root.p > 0.1
                loops: Animation.Infinite
                NumberAnimation {
                    to: root.width * (0.08 + ((fly.seed * 5.33) % 0.84 + 0.07) % 0.84)
                    duration: 7000 + fly.seed * 5000; easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: root.width * (0.08 + (fly.seed * 5.33) % 0.84)
                    duration: 7000 + fly.seed * 5000; easing.type: Easing.InOutSine
                }
            }
            SequentialAnimation on y {
                running: root.p > 0.1
                loops: Animation.Infinite
                NumberAnimation {
                    to: root.height * (0.45 + ((fly.seed * 3.77) % 0.5 + 0.05) % 0.5)
                    duration: 5200 + fly.seed * 4600; easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: root.height * (0.45 + (fly.seed * 3.77) % 0.5)
                    duration: 5200 + fly.seed * 4600; easing.type: Easing.InOutSine
                }
            }

            // the glow + the spark
            Rectangle {
                anchors.centerIn: parent
                width: parent.width; height: parent.height
                radius: width / 2
                color: root.goldA(0.10)
            }
            Rectangle {
                id: spark
                anchors.centerIn: parent
                width: 4 * root.ui; height: 4 * root.ui
                radius: width / 2
                color: root.goldA(0.95)
                SequentialAnimation on opacity {
                    running: root.p > 0.1
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.15; duration: 1400 + fly.seed * 1800; easing.type: Easing.InOutSine }
                    PauseAnimation { duration: 300 + fly.seed * 900 }
                    NumberAnimation { to: 1.0; duration: 1000 + fly.seed * 1200; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // ── the blossom ring, framing the clock (upper right in clock.qml) ─────
    Canvas {
        id: ring
        readonly property real cx: root.width - root.width * 0.035 - 230 * root.ui
        readonly property real cy: root.height * 0.085 + 150 * root.ui
        readonly property real rx: 258 * root.ui
        readonly property real ry: 196 * root.ui
        x: cx - rx - 20 * root.ui
        y: cy - ry - 20 * root.ui
        width: (rx + 20 * root.ui) * 2
        height: (ry + 20 * root.ui) * 2
        property real sweep: root.p
        onSweepChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const c = width / 2, cyy = height / 2
            const s = Math.max(0, Math.min(1, sweep))
            if (s <= 0.005) return
            // thin elliptical ring drawing itself clockwise from the top
            ctx.save()
            ctx.translate(c, cyy)
            ctx.scale(1, ry / rx)
            ctx.beginPath()
            ctx.arc(0, 0, rx, -Math.PI / 2, -Math.PI / 2 + s * Math.PI * 2)
            ctx.restore()
            ctx.strokeStyle = root.goldA(0.5)
            ctx.lineWidth = 1.4 * root.ui
            ctx.stroke()
            // small blossoms bud along the ring as it passes them
            const spots = [0.12, 0.3, 0.52, 0.74, 0.9]
            for (let i = 0; i < spots.length; i++) {
                if (s < spots[i]) continue
                const a = -Math.PI / 2 + spots[i] * Math.PI * 2
                const bx = c + Math.cos(a) * rx
                const by = cyy + Math.sin(a) * ry
                const pr = (i % 2 === 0 ? 5.5 : 4) * root.ui
                const grown = Math.min(1, (s - spots[i]) / 0.06)
                ctx.fillStyle = i % 2 === 0 ? root.creamA(0.85) : root.goldA(0.85)
                for (let k = 0; k < 5; k++) {
                    const pa = k * Math.PI * 2 / 5 + a
                    ctx.beginPath()
                    ctx.ellipse(bx + Math.cos(pa) * pr * grown - pr * 0.42,
                                by + Math.sin(pa) * pr * grown - pr * 0.42,
                                pr * 0.84, pr * 0.84)
                    ctx.fill()
                }
                ctx.beginPath()
                ctx.arc(bx, by, pr * 0.4 * grown, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(root.rose.r, root.rose.g, root.rose.b, 0.9)
                ctx.fill()
            }
        }
        Connections {
            target: root.pal
            function onNeonChanged()    { ring.requestPaint() }
            function onTextChanged()    { ring.requestPaint() }
            function onMagentaChanged() { ring.requestPaint() }
        }
    }
}
