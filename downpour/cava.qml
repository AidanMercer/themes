import QtQuick
import Quickshell.Io

// downpour: the rain gauge. The music condenses on a window rail — a sagging
// hairline sill low on the pane — as twenty-eight beads hanging beneath it.
// Each bead is one band: quiet bands sit as small tight drops; a loud band's
// bead stretches, loses its surface tension, and lets a drop fall — a short
// run with a thinning tail, then gone. No bars, no columns of light: the
// spectrum is water weight. At silence every bead is drawn back into the
// glass, the canvas stops painting, and the cava process itself is parked
// (feed gate below). Click-through scenery.
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

    readonly property color paneLight: pal.neon
    readonly property color ink: pal.text
    function paneA(a) { return Qt.rgba(paneLight.r, paneLight.g, paneLight.b, a) }
    function inkA(a)  { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    readonly property int bins: 28

    property var levels: []       // raw cava bins 0..1
    property var display: []      // smoothed values
    property var falling: []      // detached drops {i, y, v, a}
    property bool humming: false

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1200; easing.type: Easing.InOutSine }

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
            if (!smooth.running) smooth.start()
        }
    }

    // smoothing + drop physics — stops itself once frames go stale and every
    // bead has been taken back by the glass, so silence costs nothing.
    Timer {
        id: smooth
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            const d = root.display, l = root.levels
            let loud = 0, settled = true
            for (let i = 0; i < root.bins; i++) {
                const t = (l[i] || 0) < 0.03 ? 0 : (l[i] || 0)
                const prev = d[i]
                d[i] = d[i] + (t - d[i]) * 0.30
                if (d[i] < 0.004) d[i] = 0
                if (d[i] > loud) loud = d[i]
                if (d[i] > 0.003) settled = false
                // surface tension breaks: a rising band past the brink drops
                if (prev < 0.80 && d[i] >= 0.80 && root.falling.length < 10)
                    root.falling.push({ i: i, y: 0, v: 1.2 + root.rnd(i * 7) * 1.4, a: 0.85 })
            }
            // gravity on the detached drops
            const keep = []
            for (const dr of root.falling) {
                dr.v += 0.34
                dr.y += dr.v
                dr.a -= 0.016
                if (dr.a > 0.02 && dr.y < gauge.height) { keep.push(dr); settled = false }
            }
            root.falling = keep

            const now = Date.now()
            const audioActive = loud > 0.04
            if (audioActive) root.lastFrameMs = now

            const nowHumming = audioActive || !settled
            if (nowHumming !== root.humming) root.humming = nowHumming

            gauge.requestPaint()
            if (!nowHumming && now - root.lastFrameMs > 2000) smooth.stop()   // cava asleep
        }
    }

    // ── the rail and its beads ──────────────────────────────────────────────
    Canvas {
        id: gauge
        width: Math.round(root.width * 0.50)
        height: Math.round(root.height * 0.13)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.055)
        scale: pal.uiScale
        transformOrigin: Item.Bottom

        opacity: root.bootT * (root.humming ? 1 : 0)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            const colW = w / root.bins
            const railY = 6
            const maxStretch = h * 0.52

            // the sill: a sagging hairline between hashed anchors
            ctx.beginPath()
            ctx.moveTo(0, railY)
            const seg = w / 6
            let px = 0, py = railY
            for (let k = 1; k <= 6; k++) {
                const ny = railY - 1.5 + 3 * root.rnd(k * 13 + 2)
                ctx.quadraticCurveTo(px + seg * 0.5, py + 2, k * seg, ny)
                px = k * seg; py = ny
            }
            ctx.strokeStyle = String(root.paneA(0.34))
            ctx.lineWidth = 1.2
            ctx.stroke()

            // the hanging beads
            const d = root.display
            for (let i = 0; i < root.bins; i++) {
                const v = d[i]
                if (v <= 0) continue
                const cx = i * colW + colW / 2
                const bw = 3.2 + v * 3.4                 // width tightens little
                const bh = 4 + v * maxStretch            // weight is vertical
                const wob = 0.6 * root.rnd(i * 31 + 7)
                // the neck where it clings to the rail
                ctx.beginPath()
                ctx.moveTo(cx - bw * 0.35, railY + 1)
                ctx.quadraticCurveTo(cx - bw * 0.55, railY + bh * 0.45, cx, railY + bh)
                ctx.quadraticCurveTo(cx + bw * 0.55, railY + bh * 0.45, cx + bw * 0.35 + wob, railY + 1)
                ctx.closePath()
                ctx.fillStyle = String(root.paneA(0.30 + v * 0.45))
                ctx.fill()
                // the glint near the bead's shoulder
                if (v > 0.12) {
                    ctx.beginPath()
                    ctx.ellipse(cx - bw * 0.30, railY + bh * 0.28, 1.4, 2.0)
                    ctx.fillStyle = String(root.inkA(0.35 + v * 0.35))
                    ctx.fill()
                }
            }

            // the detached drops, falling with thinning tails
            for (const dr of root.falling) {
                const cx = dr.i * colW + colW / 2
                const dy = railY + 8 + dr.y
                ctx.beginPath()
                ctx.moveTo(cx - 0.8, dy - Math.min(16, dr.y * 0.5))
                ctx.lineTo(cx, dy)
                ctx.strokeStyle = String(root.paneA(dr.a * 0.4))
                ctx.lineWidth = 1.2
                ctx.stroke()
                ctx.beginPath()
                ctx.ellipse(cx - 1.8, dy, 3.6, 4.6)
                ctx.fillStyle = String(root.paneA(dr.a))
                ctx.fill()
            }
        }
    }
}
