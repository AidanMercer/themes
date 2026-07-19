import QtQuick
import QtQuick.Effects
import Quickshell.Io

// encore: the GLOWSTICK SEA. The visualizer is not bars — it's the crowd.
// Forty-eight glowsticks in three depth rows across the foot of the screen,
// each one a thin capsule of light in an invisible hand, each wired to its
// own spectrum bin: the stick lifts with its bin and the whole sea leans
// together, flipping its lean on the internal beat count (law 1 — the sway
// is quantized to the bar, not free-drifting). Most sticks are the diva's
// teal; a scattered minority answer in crowd magenta (law 4 — the two
// voices alternate, never blend). At silence the sea blacks out and the
// cava process itself is parked (law 3 — house lights, resting stage).
// Click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // pushed by the loader after mount: lock/fullscreen cover + mpris playing
    property bool occluded: false
    property bool playing: true
    readonly property bool feedOn: playing && !occluded

    readonly property color teal: pal.neon
    readonly property color crowd: pal.magenta
    readonly property color spot: pal.amber
    function colA(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    readonly property int bins: 48

    property var levels: []       // raw cava bins 0..1
    property var display: []      // smoothed values
    property bool humming: false

    // the internal count: advances only on audible signal, 500ms per beat.
    // the sea flips its lean every two beats — a hard target change the
    // smoothing then carries, like a crowd catching the next downbeat.
    property real beatMs: 0
    property int beatIdx: 0
    property real lean: 1          // current lean target, +1 / -1
    property real leanNow: 1       // smoothed toward lean

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 500; easing.type: Easing.OutCubic }

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

    // smoothing + the beat count — stops itself once frames go stale and
    // every stick has gone dark, so silence costs nothing.
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
                if (d[i] > 0.005) settled = false
            }

            const now = Date.now()
            const audioActive = loud > 0.05
            if (audioActive) {
                root.lastFrameMs = now
                // the count only runs while the hall is loud (law 1+3)
                root.beatMs += tick.interval
                const bi = Math.floor(root.beatMs / 500)
                if (bi !== root.beatIdx) {
                    root.beatIdx = bi
                    if (bi % 2 === 0) root.lean = -root.lean   // catch the downbeat
                }
            }
            root.leanNow = root.leanNow + (root.lean - root.leanNow) * 0.12

            const nowHumming = audioActive || !settled
            if (nowHumming !== root.humming) root.humming = nowHumming

            sea.requestPaint()
            if (!nowHumming && now - root.lastFrameMs > 2000) tick.stop()   // cava asleep
        }
    }

    // ── the sea ─────────────────────────────────────────────────────────────
    // soft light bleed over the crowd: one blurred copy of the whole canvas
    MultiEffect {
        source: sea
        anchors.fill: sea
        autoPaddingEnabled: true
        blurEnabled: true
        blur: 1.0
        blurMax: 24
        brightness: 0.08
        opacity: 0.75
        visible: sea.visible
        scale: sea.scale
        transformOrigin: Item.Bottom
    }

    Canvas {
        id: sea
        width: Math.round(root.width * 0.86)
        height: Math.round(root.height * 0.20)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.012)
        scale: pal.uiScale * (0.94 + 0.06 * root.bootT)
        transformOrigin: Item.Bottom
        renderStrategy: Canvas.Threaded

        // blackout, not fade: the sticks die individually as their bins fall,
        // then the whole layer hard-cuts once the sea has settled dark.
        opacity: root.humming ? root.bootT : 0
        visible: opacity > 0.01

        // deterministic crowd: each stick keeps its hand, its row, its voice
        function rnd(n) {
            let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
            x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
            return (x >>> 0) / 4294967296
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            const d = root.display, n = root.bins
            const lean = root.leanNow

            // three depth rows: back (small, dim), mid, front (tall, bright)
            // sticks interleave bins so neighbours in space aren't neighbours
            // in frequency — the sea moves as a crowd, not as a spectrum.
            for (let i = 0; i < n; i++) {
                const bin = (i * 7) % n                    // shuffle
                const lvl = d[bin] || 0
                const row = i % 3                          // 0 back … 2 front
                const rf = row / 2                          // 0..1 depth factor
                const fx = (i + 0.5) / n + (sea.rnd(i * 31 + 7) - 0.5) * 0.012
                const x = fx * w
                const baseY = h - 2 - row * (h * 0.055)
                const len = h * (0.30 + 0.16 * rf) * (0.55 + 0.45 * lvl)
                const lift = lvl * h * (0.22 + 0.14 * rf)
                // the lean: whole sea together, scaled per stick by its hand
                const amp = 0.32 + 0.3 * sea.rnd(i * 131 + 3)
                const tilt = lean * amp * (0.35 + 0.65 * lvl)
                const tipX = x + Math.sin(tilt) * len
                const tipY = baseY - lift - Math.cos(tilt) * len

                const magenta = sea.rnd(i * 977 + 11) < 0.18   // the answering voice
                const col = magenta ? root.crowd : root.teal
                const a = 0.10 + 0.85 * lvl

                if (a <= 0.11 && lvl <= 0.01) continue          // dark stick, dark hall

                // the stick: one thick round-capped stroke of light
                ctx.strokeStyle = String(root.colA(col, a * (0.55 + 0.45 * rf)))
                ctx.lineWidth = 2.2 + 2.2 * rf
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.moveTo(x, baseY - lift)
                ctx.lineTo(tipX, tipY)
                ctx.stroke()

                // its hot core at the tip — the chemical bright spot
                if (lvl > 0.12) {
                    ctx.fillStyle = String(root.colA(root.spot, Math.min(0.9, lvl)))
                    ctx.beginPath()
                    ctx.arc(tipX, tipY, 1.2 + 1.6 * rf * lvl, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }
    }
}
