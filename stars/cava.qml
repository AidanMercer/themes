import QtQuick
import Quickshell.Io

// stars: a meteor shower. A low, centered radiant sits over the platform —
// exactly where the old starlight strand lived — and music peaks fling
// shooting-star streaks up out of it. Louder bands throw brighter, longer,
// faster meteors; the spectrum fans left→right so bass and treble streak to
// opposite sides. Amber cores with coral-hot heads, tapering luminous tails,
// a faint radiant pool where they're born. At true silence it drains, fades
// out completely and stops painting; the platform (and the cat) stay clear.
// Runs its own cava against cava.conf next door; click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // pushed by the loader after mount: lock/fullscreen cover + mpris playing
    property bool occluded: false
    property bool playing: true
    readonly property bool feedOn: playing && !occluded
    readonly property color amber: pal.neon
    readonly property color coral: pal.cyan
    readonly property color slate: pal.dim
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function coralA(a) { return Qt.rgba(coral.r, coral.g, coral.b, a) }
    function colA(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    readonly property int bins: 24

    property var levels: []       // raw cava bins 0..1
    property var display: []      // smoothed values, for onset detection
    property var prev: []         // previous display, for rising-edge onsets
    property var meteors: []      // live particles
    property real energy: 0       // smoothed overall loudness → radiant glow
    property bool humming: false  // audio present or meteors still in flight

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

    Component.onCompleted: {
        const z = [], p = []
        for (let i = 0; i < bins; i++) { z.push(0); p.push(0) }
        display = z
        prev = p
    }

    Process {
        id: cava
        running: root.feedOn
        command: ["cava", "-p", Qt.resolvedUrl("cava.conf").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: line => root.parseFrame(line)
        }
        onRunningChanged: if (root.feedOn && !running) cavaRestart.start()
    }
    Timer {
        id: cavaRestart
        interval: 2000
        // re-assign the binding, not `= true`, or one crash restart would strip
        // the feed gate and leak the reader forever (same trick as AudioBus)
        onTriggered: cava.running = Qt.binding(() => root.feedOn)
    }

    property double lastFrameMs: 0

    function parseFrame(line) {
        const parts = line.split(";")
        const out = []
        for (let i = 0; i < parts.length; i++) {
            if (parts[i] === "") continue
            out.push(Math.min(1, parseInt(parts[i]) / 1000))
        }
        if (out.length) {
            root.levels = out
            root.lastFrameMs = Date.now()
            if (!tick.running) tick.start()
        }
    }

    // spawn one meteor from bin i (spectral position) with strength s (0..1)
    function spawnMeteor(i, s) {
        const w = sky.width, h = sky.height
        const rx = w * 0.5, ry = h - 10          // radiant: low, centered
        const fx = i / (bins - 1) - 0.5          // -0.5..0.5 across spectrum
        const ang = fx * 1.15 + (Math.random() - 0.5) * 0.34   // 0 = straight up
        const dirx = Math.sin(ang)
        const diry = -Math.cos(ang)              // upward
        const speed = 3.4 + s * 5.6 + Math.random() * 1.6
        const m = {
            x: rx + fx * (w * 0.30) + (Math.random() - 0.5) * 10,
            y: ry - Math.random() * 6,
            vx: dirx * speed,
            vy: diry * speed,
            life: 1,
            decay: Math.max(0.011, 0.017 - s * 0.005) + Math.random() * 0.009,
            len: 22 + s * 66,
            wd: 0.9 + s * 1.9,
            hot: s
        }
        const arr = root.meteors
        arr.push(m)
        root.meteors = arr
    }

    // physics + spawn pump — advances meteors, launches new ones on onsets,
    // and gates itself off at true silence so nothing dirties the scene.
    Timer {
        id: tick
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            const d = root.display, l = root.levels, p = root.prev
            let loud = 0
            for (let i = 0; i < root.bins; i++) {
                let t = l[i] || 0
                if (t < 0.04) t = 0
                d[i] = d[i] + (t - d[i]) * 0.45
                if (d[i] > loud) loud = d[i]
            }
            root.energy = root.energy + (loud - root.energy) * 0.2

            const now = Date.now()
            // feedOn guard: when the feed is cut (lock/pause) `levels` freezes
            // at its last frame — without it, stale loudness would keep this
            // tick (and lastFrameMs) alive forever behind the lock screen
            const audioActive = root.feedOn && loud > 0.06

            // launch meteors on rising edges, rationed so peaks burst and
            // quiet passages only sparkle now and then
            if (audioActive && root.meteors.length < 44) {
                for (let i = 0; i < root.bins; i++) {
                    const edge = d[i] - p[i]
                    if (d[i] > 0.40 && edge > 0.09 && Math.random() < 0.32 + d[i] * 0.42)
                        root.spawnMeteor(i, d[i])
                }
            }
            for (let i = 0; i < root.bins; i++) p[i] = d[i]

            // advance + cull
            const alive = []
            const w = sky.width, h = sky.height
            const ms = root.meteors
            for (let k = 0; k < ms.length; k++) {
                const m = ms[k]
                m.x += m.vx; m.y += m.vy
                m.vy += 0.035            // gentle gravity → a soft arc
                m.vx *= 0.996
                m.life -= m.decay
                if (m.life > 0 && m.y > -30 && m.x > -40 && m.x < w + 40) alive.push(m)
            }
            root.meteors = alive

            const nowHumming = audioActive || alive.length > 0
            if (nowHumming !== root.humming) root.humming = nowHumming
            if (audioActive) root.lastFrameMs = now

            if (nowHumming) {
                sky.requestPaint()
            } else {
                sky.requestPaint()   // final clear as it fades out
                if (now - root.lastFrameMs > 2000) tick.stop()  // cava asleep
            }
        }
    }

    // ── the shower ──────────────────────────────────────────────────────────
    Canvas {
        id: sky
        width: Math.round(root.width * 0.60)
        height: Math.round(root.height * 0.42)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.10)
        scale: pal.uiScale
        transformOrigin: Item.Bottom

        opacity: root.bootT * (root.humming ? 1 : 0)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            const rx = w * 0.5, ry = h - 10

            // luminous additive stacking for that hot-meteor glow
            ctx.globalCompositeOperation = "lighter"

            // radiant pool — a faint amber breath where meteors are born
            if (root.energy > 0.02) {
                const rr = 120 * (0.6 + root.energy)
                const g = ctx.createRadialGradient(rx, ry, 0, rx, ry, rr)
                g.addColorStop(0, root.amberA(0.15 * Math.min(1, root.energy * 1.6)))
                g.addColorStop(1, root.amberA(0))
                ctx.fillStyle = g
                ctx.fillRect(0, 0, w, h)
            }

            ctx.lineCap = "round"
            const ms = root.meteors
            for (let k = 0; k < ms.length; k++) {
                const m = ms[k]
                const sp = Math.hypot(m.vx, m.vy) || 1
                const ux = m.vx / sp, uy = m.vy / sp
                const hx = m.x, hy = m.y
                const ex = hx - ux * m.len, ey = hy - uy * m.len
                const a = Math.min(1, m.life * 1.5)
                const head = m.hot > 0.6 ? root.coral : root.amber

                // tapering tail
                const grad = ctx.createLinearGradient(hx, hy, ex, ey)
                grad.addColorStop(0, root.colA(head, 0.9 * a))
                grad.addColorStop(0.4, root.amberA(0.32 * a))
                grad.addColorStop(1, root.amberA(0))
                ctx.strokeStyle = grad
                ctx.lineWidth = m.wd
                ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(ex, ey); ctx.stroke()

                // soft glow bloom around the head
                const hr = (m.wd * 1.6 + m.hot * 1.4) * 3
                const gg = ctx.createRadialGradient(hx, hy, 0, hx, hy, hr)
                gg.addColorStop(0, root.colA(head, 0.85 * a))
                gg.addColorStop(0.5, root.colA(head, 0.22 * a))
                gg.addColorStop(1, root.colA(head, 0))
                ctx.fillStyle = gg
                ctx.beginPath(); ctx.arc(hx, hy, hr, 0, Math.PI * 2); ctx.fill()

                // bright core
                ctx.fillStyle = root.colA(head, a)
                ctx.beginPath(); ctx.arc(hx, hy, Math.max(0.6, m.wd * 0.7), 0, Math.PI * 2); ctx.fill()

                // cross flare on the hottest heads
                if (m.hot > 0.62) {
                    const fr = hr * 0.8
                    ctx.strokeStyle = root.coralA(0.5 * a * m.hot)
                    ctx.lineWidth = 0.7
                    ctx.beginPath()
                    ctx.moveTo(hx - fr, hy); ctx.lineTo(hx + fr, hy)
                    ctx.moveTo(hx, hy - fr); ctx.lineTo(hx, hy + fr)
                    ctx.stroke()
                }
            }

            ctx.globalCompositeOperation = "source-over"
        }
        Connections {
            target: root.pal
            function onNeonChanged() { sky.requestPaint() }
            function onCyanChanged() { sky.requestPaint() }
        }
    }
}
