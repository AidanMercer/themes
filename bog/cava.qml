import QtQuick
import Quickshell.Io

// bog: the pond breathes music. The spectrum IS the water — a band of open
// water low on the screen whose surface curve swells and chops with the bins
// (bass rolls in from the left, treble ripples out to the right). Three lily
// pads ride the swell, lifting and tilting with the slope under them, and a
// pair of dragonflies hovers above the loudest reach of water, drifting to
// wherever the music is. Below the surface curve the water carries a dim
// mirrored glow — the house reflection rule, painted by hand here. At true
// silence the pond flattens, the canvas stops painting, and the cava process
// itself is parked (feed gate below). Click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // pushed by the loader after mount: lock/fullscreen cover + mpris playing
    property bool occluded: false
    property bool playing: true
    readonly property bool feedOn: playing && !occluded
    // feed cut mid-frame (lock/pause) freezes levels non-zero and the tick
    // would chase them forever — drain so it settles and stops
    onFeedOnChanged: if (!feedOn) levels = []

    readonly property color sun: pal.neon
    readonly property color moss: pal.cyan
    readonly property color straw: pal.text
    function sunA(a)  { return Qt.rgba(sun.r, sun.g, sun.b, a) }
    function mossA(a) { return Qt.rgba(moss.r, moss.g, moss.b, a) }
    function colA(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    readonly property int bins: 36

    property var levels: []       // raw cava bins 0..1
    property var display: []      // smoothed values
    property bool humming: false
    property real phase: 0        // slow drift under the swell

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1200; easing.type: Easing.OutSine }

    Component.onCompleted: {
        const d = []
        for (let i = 0; i < bins; i++) d.push(0)
        display = d
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
        // the feed gate and leak the reader forever
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

    // smoothing — heavy-damped, the pond takes its time. Stops itself once
    // frames go stale and the water has flattened, so silence costs nothing.
    Timer {
        id: tick
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            const d = root.display, l = root.levels
            let loud = 0, settled = true
            for (let i = 0; i < root.bins; i++) {
                let t = l[i] || 0
                if (t < 0.04) t = 0
                d[i] = d[i] + (t - d[i]) * 0.16   // slow water, not a meter
                if (d[i] < 0.004) d[i] = 0
                if (d[i] > loud) loud = d[i]
                if (d[i] > 0.003) settled = false
            }
            root.phase += 0.016

            const now = Date.now()
            const audioActive = loud > 0.05
            if (audioActive) root.lastFrameMs = now

            const nowHumming = audioActive || !settled
            if (nowHumming !== root.humming) root.humming = nowHumming

            pond.requestPaint()
            if (!nowHumming && now - root.lastFrameMs > 2000) tick.stop()   // cava asleep
        }
    }

    // surface height at 0..1 across the band (catmull-ish smooth between bins)
    function surfAt(u) {
        const d = root.display
        const f = u * (root.bins - 1)
        const i = Math.floor(f)
        const t = f - i
        const a = d[Math.max(0, i)] || 0
        const b = d[Math.min(root.bins - 1, i + 1)] || 0
        const v = a + (b - a) * (t * t * (3 - 2 * t))
        return v
    }

    // ── the water ───────────────────────────────────────────────────────────
    Canvas {
        id: pond
        width: Math.round(root.width * 0.55)
        height: Math.round(root.height * 0.17)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.145)
        scale: pal.uiScale
        transformOrigin: Item.Bottom

        opacity: root.bootT * (root.humming ? 1 : 0)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            const base = h * 0.55            // the resting waterline
            const amp = h * 0.42             // how high the music can lift it
            const N = 72                     // drawing resolution

            // the surface path
            const pts = []
            for (let k = 0; k <= N; k++) {
                const u = k / N
                // edges taper so the band melts into the painted pond
                const edge = Math.sin(Math.PI * u)
                const swell = root.surfAt(u) * edge
                const shimmer = Math.sin(u * 21 + root.phase * 2.1) * 0.012 * edge
                pts.push([u * w, base - (swell + shimmer) * amp])
            }

            // the body of water under the curve, fading down into murk
            const grad = ctx.createLinearGradient(0, base - amp, 0, h)
            grad.addColorStop(0, String(root.mossA(0.30)))
            grad.addColorStop(0.5, String(root.mossA(0.10)))
            grad.addColorStop(1, String(root.mossA(0)))
            ctx.beginPath()
            ctx.moveTo(0, h)
            for (const p of pts) ctx.lineTo(p[0], p[1])
            ctx.lineTo(w, h)
            ctx.closePath()
            ctx.fillStyle = grad
            ctx.fill()

            // the sunlit surface line itself
            ctx.beginPath()
            for (let k = 0; k < pts.length; k++) {
                if (k === 0) ctx.moveTo(pts[k][0], pts[k][1])
                else ctx.lineTo(pts[k][0], pts[k][1])
            }
            ctx.strokeStyle = String(root.sunA(0.75))
            ctx.lineWidth = 1.6
            ctx.stroke()

            // glints where the water runs high
            ctx.fillStyle = String(root.colA(root.straw, 0.7))
            for (let k = 4; k < N; k += 6) {
                const u = k / N
                const v = root.surfAt(u)
                if (v > 0.45)
                    ctx.fillRect(pts[k][0] - 2, pts[k][1] - 1.5, 4, 1.5)
            }

            // the reflection: the same curve mirrored under the resting line,
            // dim and broken — the house rule, by hand
            ctx.beginPath()
            for (let k = 0; k < pts.length; k++) {
                const y = base + (base - pts[k][1]) * 0.5
                if (k === 0) ctx.moveTo(pts[k][0], y)
                else ctx.lineTo(pts[k][0], y)
            }
            ctx.strokeStyle = String(root.sunA(0.13))
            ctx.lineWidth = 1
            ctx.stroke()

            // ── three lily pads riding the swell ──
            for (let padI = 0; padI < 3; padI++) {
                const u = 0.22 + padI * 0.28
                const v = root.surfAt(u)
                const x = u * w
                const y = base - v * amp - 1.5
                // slope under the pad tilts it
                const slope = (root.surfAt(Math.min(1, u + 0.04)) - root.surfAt(Math.max(0, u - 0.04))) * amp
                ctx.save()
                ctx.translate(x, y)
                ctx.rotate(Math.atan2(-slope, w * 0.08) * 0.5)
                ctx.scale(1, 0.34)
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.arc(0, 0, 11, -0.3, 2 * Math.PI - 0.9)
                ctx.closePath()
                ctx.fillStyle = String(root.mossA(0.55 + v * 0.4))
                ctx.fill()
                ctx.restore()
            }

            // ── the dragonflies, hovering over the loudest water ──
            const d = root.display
            let hot = [0, 0]      // best two bin indices
            for (let i = 0; i < root.bins; i++) {
                if (d[i] > (d[hot[0]] || 0)) { hot[1] = hot[0]; hot[0] = i }
                else if (d[i] > (d[hot[1]] || 0) && Math.abs(i - hot[0]) > 5) hot[1] = i
            }
            for (let f = 0; f < 2; f++) {
                const i = hot[f]
                const v = d[i] || 0
                if (v < 0.12) continue
                const u = i / (root.bins - 1)
                const x = u * w + Math.sin(root.phase * (1.7 + f)) * 6
                const y = base - v * amp - 14 - f * 6 + Math.sin(root.phase * 3.1 + f * 2) * 2.5
                const tone = f === 0 ? root.sun : root.straw
                // body
                ctx.strokeStyle = String(root.colA(tone, 0.85))
                ctx.lineWidth = 1.4
                ctx.beginPath()
                ctx.moveTo(x - 4, y + 1)
                ctx.quadraticCurveTo(x, y - 0.5, x + 4, y + 0.5)
                ctx.stroke()
                // wing blurs
                ctx.fillStyle = String(root.colA(tone, 0.25))
                ctx.save(); ctx.translate(x - 0.5, y - 2); ctx.scale(1, 0.4)
                ctx.beginPath(); ctx.arc(-2, -3, 4, 0, 2 * Math.PI)
                ctx.arc(3, -3, 4, 0, 2 * Math.PI)
                ctx.restore(); ctx.fill()
            }
        }
    }
}
