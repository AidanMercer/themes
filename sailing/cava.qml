import QtQuick
import Quickshell.Io

// sailing: the sea swell — audio visualizer for the "THROUGH SILENCE"
// wallpaper. Low on the left, over the open water: at silence it settles to
// a single calm hairline (a second horizon) and stops painting entirely.
// With audio it becomes three layered rolling swells — back, mid and front
// wave lines with parallax amplitudes, slowly drifting astern, their crests
// flecked with pale foam. Runs its own cava against cava.conf next door.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // pushed by the loader after mount: lock/fullscreen cover + mpris playing
    property bool occluded: false
    property bool playing: true
    readonly property bool feedOn: playing && !occluded
    readonly property color dusk:  pal.cyan
    readonly property color slate: pal.dim
    readonly property color pale:  pal.text
    readonly property real ui: pal.uiScale
    function paleA(a)  { return Qt.rgba(pale.r, pale.g, pale.b, a) }
    function duskA(a)  { return Qt.rgba(dusk.r, dusk.g, dusk.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }

    // the water band, left of the railing and below the horizon
    readonly property real bandX: root.width * 0.035
    readonly property real bandW: root.width * 0.40
    readonly property real bandY: root.height * 0.60   // canvas top
    readonly property real bandH: root.height * 0.17

    readonly property int barCount: 36
    property var levels: []
    property var display: []
    property real drift: 0          // waves roll astern only while audio plays

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1400; easing.type: Easing.OutCubic }
    onBootTChanged: canvas.requestPaint()

    Component.onCompleted: {
        const z = []
        for (let i = 0; i < barCount; i++) z.push(0)
        display = z
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
            smooth.start()
        }
    }

    // ease display toward levels; stop painting once the sea is truly calm
    Timer {
        id: smooth
        interval: 40
        running: true
        repeat: true
        onTriggered: {
            const d = root.display
            const l = root.levels
            let moved = 0
            let peak = 0
            for (let i = 0; i < root.barCount; i++) {
                let t = l[i] || 0
                if (t < 0.04) t = 0
                const nv = d[i] + (t - d[i]) * 0.3
                moved += Math.abs(nv - d[i])
                d[i] = nv
                if (nv > peak) peak = nv
            }
            if (peak > 0.03) root.drift += 0.06        // the swell rolls astern
            if (moved > 0.003 || peak > 0.03) {
                root.display = d
                canvas.requestPaint()
            }
            // cava sleeps at silence (sleep_timer) — nothing left to ease; parseFrame rearms
            else if (Date.now() - root.lastFrameMs > 2000)
                smooth.stop()
        }
    }

    Canvas {
        id: canvas
        x: root.bandX
        y: root.bandY
        width: root.bandW
        height: root.bandH
        opacity: root.bootT
        renderStrategy: Canvas.Threaded

        // pal reads config.toml async — retint the calm line if it lands late
        Connections {
            target: root.pal
            function onCyanChanged() { canvas.requestPaint() }
            function onDimChanged() { canvas.requestPaint() }
            function onTextChanged() { canvas.requestPaint() }
        }

        // sample the spectrum as a smooth spatial wave: linear interpolation
        // between bars, shifted by the rolling drift, faded at both ends
        function waveAt(t, amp, phase) {
            const n = root.barCount
            const d = root.display
            let idx = (t * (n - 1) + root.drift * 3 + phase * n) % n
            if (idx < 0) idx += n
            const i0 = Math.floor(idx), i1 = (i0 + 1) % n
            const f = idx - i0
            const v = (d[i0] || 0) * (1 - f) + (d[i1] || 0) * f
            const env = Math.sin(Math.PI * t)          // calm at both ends
            return v * env * amp
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            const baseY = h * 0.62
            const maxRise = h * 0.52
            const pts = 84

            // overall sea state — the back swells surface only with the music,
            // so silence leaves a single calm hairline on the water
            const d = root.display
            let energy = 0
            for (let i = 0; i < root.barCount; i++) energy += d[i] || 0
            energy /= root.barCount
            const rough = Math.min(1, energy * 9)

            // three swells, back to front — parallax amplitude and drift
            const layers = [
                { amp: 0.45, phase: 0.53, dy: -h * 0.16, col: root.slateA(0.55 * rough), lw: 1.2 },
                { amp: 0.70, phase: 0.21, dy: -h * 0.07, col: root.duskA(0.65 * rough),  lw: 1.4 },
                { amp: 1.00, phase: 0.00, dy: 0,         col: root.paleA(0.45 + 0.30 * rough), lw: 1.7 }
            ]

            for (let li = 0; li < layers.length; li++) {
                const L = layers[li]
                ctx.beginPath()
                for (let k = 0; k <= pts; k++) {
                    const t = k / pts
                    const y = baseY + L.dy - waveAt(t, L.amp, L.phase) * maxRise
                    const x = t * w
                    if (k === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                }
                ctx.strokeStyle = L.col
                ctx.lineWidth = L.lw
                ctx.stroke()
            }

            // foam: pale flecks just above the front swell's crests
            ctx.fillStyle = root.paleA(0.85)
            let prev = 0, prev2 = 0
            for (let k = 0; k <= pts; k++) {
                const t = k / pts
                const v = waveAt(t, 1.0, 0)
                if (k >= 2 && prev > 0.30 && prev >= v && prev >= prev2) {
                    const px = ((k - 1) / pts) * w
                    const py = baseY - prev * maxRise - 3
                    ctx.beginPath()
                    ctx.arc(px, py, 1.1, 0, Math.PI * 2)
                    ctx.fill()
                    if (prev > 0.55) {
                        ctx.beginPath()
                        ctx.arc(px + 5, py + 2, 0.8, 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
                prev2 = prev; prev = v
            }
        }
    }
}
