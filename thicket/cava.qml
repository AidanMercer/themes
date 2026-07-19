import QtQuick
import Quickshell.Io

// thicket: the parting hedge — an INVERTED visualizer. A closed band of dark
// foliage lies across the lower screen. Sound doesn't raise bars: it PARTS
// THE LEAVES. Each of the 28 bins is a seam in the hedge; as its band gets
// loud the leaves above and below swing aside and ember light spills through
// the gap from somewhere behind the thicket. Loud music = a hedge full of
// burning gaps; silence = the leaves close, the light dies, the canvas stops
// painting and the cava process itself is parked (feed gate below). A hard
// bass spike startles the brush: a pale eyeshine pair glints out of one gap
// for half a beat, then it's gone. Click-through scenery.
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

    readonly property color ember: pal.neon
    readonly property color iris: pal.cyan
    readonly property color dapple: pal.amber
    readonly property color leaf: pal.dim
    function emberA(a)  { return Qt.rgba(ember.r, ember.g, ember.b, a) }
    function irisA(a)   { return Qt.rgba(iris.r, iris.g, iris.b, a) }
    function dappleA(a) { return Qt.rgba(dapple.r, dapple.g, dapple.b, a) }
    function leafA(a)   { return Qt.rgba(leaf.r, leaf.g, leaf.b, a) }

    readonly property int bins: 28

    property var levels: []       // raw cava bins 0..1
    property var display: []      // smoothed values
    property bool humming: false

    // the startle: one gap grows eyes for a few hundred ms
    property int startleBin: -1
    property double startleUntil: 0
    property double startleCooldown: 0

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }

    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

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

    // smoothing — stops itself once frames go stale and every gap has closed,
    // so silence costs nothing.
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
                d[i] = d[i] + (t - d[i]) * 0.38
                if (d[i] < 0.006) d[i] = 0
                if (d[i] > loud) loud = d[i]
                if (d[i] > 0.004) settled = false
            }

            const now = Date.now()
            const audioActive = loud > 0.05
            if (audioActive) root.lastFrameMs = now

            // the startle: a hard bass hit, at most every few seconds
            if (now > root.startleCooldown) {
                const bass = Math.max(l[0] || 0, l[1] || 0, l[2] || 0)
                if (bass > 0.86) {
                    root.startleBin = 3 + Math.floor(root.rnd(Math.floor(now / 100)) * (root.bins - 6))
                    root.startleUntil = now + 460
                    root.startleCooldown = now + 3200
                }
            }
            if (root.startleBin >= 0 && now > root.startleUntil) {
                root.startleBin = -1
                if (settled) settled = false   // one extra frame to erase the eyes
            }

            const nowHumming = audioActive || !settled
            if (nowHumming !== root.humming) root.humming = nowHumming

            hedge.requestPaint()
            if (!nowHumming && now - root.lastFrameMs > 2000) tick.stop()   // cava asleep
        }
    }

    // ── the hedge ───────────────────────────────────────────────────────────
    Canvas {
        id: hedge
        width: Math.round(root.width * 0.56)
        height: Math.round(root.height * 0.115)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.06)
        scale: pal.uiScale
        transformOrigin: Item.Bottom

        opacity: root.bootT * (root.humming ? 1 : 0)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }

        function leafShape(ctx, x, y, len, wid, ang, fill) {
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
            const colW = w / root.bins
            const midY = h * 0.52
            const d = root.display
            const now = Date.now()

            for (let i = 0; i < root.bins; i++) {
                const v = d[i]
                const cx = i * colW + colW / 2

                // the light behind the thicket, spilling through the open seam
                if (v > 0.01) {
                    const glowH = Math.max(2, v * h * 0.86)
                    const g = ctx.createRadialGradient(cx, midY, 1, cx, midY, glowH / 2 + colW * 0.4)
                    const hot = v > 0.8
                    g.addColorStop(0, String(hot ? root.dappleA(0.95) : root.emberA(0.55 + v * 0.4)))
                    g.addColorStop(0.55, String(root.emberA(0.28 * v)))
                    g.addColorStop(1, String(root.emberA(0)))
                    ctx.fillStyle = g
                    ctx.fillRect(cx - colW, midY - glowH / 2 - 6, colW * 2, glowH + 12)
                }

                // the leaves of this seam: three above, three below, swinging
                // aside as the gap opens — they part, they don't shrink
                const open = v * h * 0.34
                for (let k = 0; k < 3; k++) {
                    const s = i * 97 + k * 31
                    const len = colW * (0.85 + root.rnd(s + 1) * 0.5)
                    const wid = 3.5 + root.rnd(s + 2) * 3.5
                    const jx = (root.rnd(s + 3) - 0.5) * colW * 0.5
                    const teal = root.rnd(s + 4) < 0.28
                    const col = teal ? "rgba(26,48,42,0.92)"
                                     : String(root.leafA(0.55 + root.rnd(s + 5) * 0.4))
                    // above: hinged flat, swings up as the seam opens
                    const aBase = -0.25 + (root.rnd(s + 6) - 0.5) * 0.5
                    leafShape(ctx, cx + jx - len / 2, midY - 2 - open * (0.6 + k * 0.25),
                              len, wid, aBase - v * 0.55, col)
                    // below: mirrored, swings down
                    const bBase = 0.25 + (root.rnd(s + 7) - 0.5) * 0.5
                    leafShape(ctx, cx + jx - len / 2, midY + 2 + open * (0.6 + k * 0.25),
                              len, wid, bBase + v * 0.55, col)
                }

                // the startled eyes, glinting out of one gap
                if (i === root.startleBin && now < root.startleUntil) {
                    const a = Math.min(1, (root.startleUntil - now) / 300)
                    ctx.fillStyle = String(root.irisA(0.95 * a))
                    ctx.save(); ctx.translate(cx - 3.5, midY); ctx.scale(1, 0.72)
                    ctx.beginPath(); ctx.arc(0, 0, 2.6, 0, Math.PI * 2); ctx.fill()
                    ctx.restore()
                    ctx.save(); ctx.translate(cx + 4.5, midY - 0.8); ctx.scale(1, 0.72)
                    ctx.beginPath(); ctx.arc(0, 0, 2.6, 0, Math.PI * 2); ctx.fill()
                    ctx.restore()
                    ctx.fillStyle = "rgba(255,255,255," + 0.85 * a + ")"
                    ctx.fillRect(cx - 4.5, midY - 1, 1.6, 1.6)
                    ctx.fillRect(cx + 3.5, midY - 1.6, 1.6, 1.6)
                }
            }
        }
    }
}
