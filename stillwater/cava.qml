import QtQuick
import Quickshell.Io

// stillwater: the music lights the far shore. Twenty-eight thin pillars of
// light stand on the wallpaper's real horizon line, right of the lone figure,
// and rise with the spectrum — humble above the line, but the water answers
// with MORE than it was given: every pillar's reflection is a longer, broken,
// faintly wavering streak stretching down toward the viewer, the way distant
// lights lie on still water. A peak glint hangs above each pillar and settles
// back down to the surface. At silence everything sinks into the line, the
// canvas stops painting, and the cava process itself is parked (feed gate
// below). Click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // pushed by the loader after mount: lock/fullscreen cover + mpris playing
    property bool occluded: false
    property bool playing: true
    readonly property bool feedOn: playing && !occluded
    // parking the feed mid-song leaves the last frame in `levels`; clear it so
    // the tick can decay to settled and stop instead of chasing stale audio
    onFeedOnChanged: if (!feedOn) levels = []

    readonly property color lamp: pal.neon
    readonly property color sky: pal.cyan
    readonly property color rose: pal.magenta
    function colA(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    readonly property int bins: 28
    // the wallpaper's waterline, and the far-right stretch of shore — clear
    // of the figure (x≈0.39), the clock (left sky) and the lyrics (center)
    readonly property real hzY: root.height * 0.527
    readonly property real bandX: root.width * 0.735
    readonly property real bandW: root.width * 0.235

    property var levels: []       // raw cava bins 0..1
    property var display: []      // smoothed values
    property var peaks: []        // peak-hold glints, 0..1
    property bool humming: false

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1100; easing.type: Easing.OutCubic }

    Component.onCompleted: {
        const d = [], p = []
        for (let i = 0; i < bins; i++) { d.push(0); p.push(0) }
        display = d
        peaks = p
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

    // smoothing + glint physics — stops itself once frames go stale and the
    // whole shore has gone dark, so silence costs nothing.
    Timer {
        id: tick
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            const d = root.display, l = root.levels, p = root.peaks
            let loud = 0, settled = true
            for (let i = 0; i < root.bins; i++) {
                let t = l[i] || 0
                if (t < 0.04) t = 0
                d[i] = d[i] + (t - d[i]) * 0.30          // slow water, not a meter
                if (d[i] < 0.005) d[i] = 0
                // glints hang, then sink slowly back toward the surface
                p[i] = Math.max(p[i] - 0.010, d[i])
                if (p[i] < 0.005) p[i] = 0
                if (d[i] > loud) loud = d[i]
                if (d[i] > 0.004 || p[i] > 0.004) settled = false
            }

            const now = Date.now()
            const audioActive = loud > 0.05
            if (audioActive) root.lastFrameMs = now

            const nowHumming = audioActive || !settled
            if (nowHumming !== root.humming) root.humming = nowHumming

            shoreCanvas.requestPaint()
            if (!nowHumming && now - root.lastFrameMs > 2000) tick.stop()   // cava asleep
        }
    }

    // ── the lit shore and its answer in the water ───────────────────────────
    Canvas {
        id: shoreCanvas
        x: root.bandX
        y: root.hzY - height * 0.34
        width: root.bandW
        height: Math.round(root.height * 0.30)
        // the waterline sits at 34% of the canvas: pillars above, streaks below
        readonly property real lineY: height * 0.34

        opacity: root.bootT * (root.humming ? 1 : 0)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, ly = lineY
            const n = root.bins
            const colW = w / n
            const maxUp = ly * 0.9                 // humble above the line
            const maxDn = (height - ly) * 0.96     // generous below it
            const ph = Date.now() / 1000
            const d = root.display, p = root.peaks
            const ui = Math.max(1, root.pal.uiScale)

            for (let i = 0; i < n; i++) {
                const v = d[i]
                if (v <= 0 && p[i] <= 0) continue
                const cx = Math.round(i * colW + colW / 2)
                // every seventh light burns rose, every fifth cool blue —
                // a town's mixed windows; the rest warm white
                const tone = (i % 7 === 3) ? root.rose : (i % 5 === 2) ? root.sky : root.lamp

                if (v > 0) {
                    // the pillar: a thin light rising off the line, brightest
                    // at its foot, dying into the haze above
                    const hUp = v * maxUp
                    const gUp = ctx.createLinearGradient(0, ly, 0, ly - hUp)
                    gUp.addColorStop(0, String(root.colA(tone, 0.95)))
                    gUp.addColorStop(1, String(root.colA(tone, 0)))
                    ctx.fillStyle = gUp
                    ctx.fillRect(cx - ui, ly - hUp, 2 * ui, hUp)
                    // the lamp at the waterline
                    ctx.fillStyle = String(root.colA(root.lamp, 0.9))
                    ctx.fillRect(cx - ui - 1, ly - 2, 2 * ui + 2, 2)

                    // the streak: broken slivers wavering down into the water
                    const hDn = Math.min(maxDn, v * maxDn * 1.25)
                    let y = ly + 3
                    let k = 0
                    while (y < ly + hDn) {
                        const depth = (y - ly) / maxDn
                        const sw = Math.max(1, (2 * ui) * (1 - depth * 0.5))
                        const wob = Math.sin(ph * 1.7 + i * 1.3 + k * 0.9) * (1 + depth * 5)
                        ctx.fillStyle = String(root.colA(tone, 0.5 * (1 - depth) * (1 - depth) + 0.03))
                        ctx.fillRect(cx - sw / 2 + wob, y, sw, Math.max(1.5, 3 - depth * 2))
                        y += 4 + depth * 9 + (k % 3)   // gaps widen with depth
                        k++
                    }
                }

                // the glint: a spark hanging above the pillar, settling back
                const pk = p[i]
                if (pk > 0.02 && pk >= v) {
                    ctx.fillStyle = String(root.colA(root.lamp, 0.8))
                    ctx.fillRect(cx - 1, ly - pk * maxUp - 3, 2, 2)
                }
            }
        }
    }
}
