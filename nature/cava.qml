import QtQuick
import Quickshell.Io

// nature — "golden hour" visualizer: a meadow that hears.
//
// Replaces the default Arch triangle. A field of grass blades and flower
// stems grows along the bottom of the screen; the spectrum is planted with
// the bass at the center and the highs feathering to the edges, so music
// reads as wind moving through the meadow. Every so often a stem is tipped
// with a five-petal blossom that opens on peaks and closes as the sound
// drains away. At true silence the meadow settles to short, still grass and
// stops repainting entirely. Runs its own cava with cava.conf next door.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color gold:  pal.neon
    readonly property color leaf:  pal.cyan
    readonly property color rose:  pal.magenta
    readonly property color moss:  pal.dim
    readonly property color cream: pal.text
    readonly property real ui: pal.uiScale

    readonly property int barCount: 40
    readonly property int bladeCount: 72
    property var levels: []
    property var display: []      // smoothed per-blade level
    property var bloom: []        // per-blossom open factor
    property real phase: 0        // wind phase — advances only while audio plays

    // boot-in: the meadow grows out of the ground once
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1400; easing.type: Easing.OutCubic }
    onBootTChanged: meadow.requestPaint()

    Component.onCompleted: {
        const z = [], b = []
        for (let i = 0; i < bladeCount; i++) z.push(0)
        for (let i = 0; i < bladeCount; i++) b.push(0)
        display = z
        bloom = b
    }

    Process {
        id: cava
        running: true
        command: ["cava", "-p", Qt.resolvedUrl("cava.conf").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: line => root.parseFrame(line)
        }
        onRunningChanged: if (!running) cavaRestart.start()
    }
    Timer {
        id: cavaRestart
        interval: 2000
        onTriggered: cava.running = true
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

    // deterministic per-blade jitter
    function jit(i, s) { return ((Math.sin(i * 127.1 + s * 311.7) * 43758.5453) % 1 + 1) % 1 }

    // blade i samples the spectrum: bass planted center, highs at the edges
    function binFor(i) {
        const t = Math.abs((i + 0.5) / bladeCount - 0.5) * 2
        return Math.min(barCount - 1, Math.floor(t * (barCount - 1)))
    }

    Timer {
        id: smooth
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            const d = root.display
            const bl = root.bloom
            const l = root.levels
            let moved = 0, peak = 0
            for (let i = 0; i < root.bladeCount; i++) {
                let t = l[root.binFor(i)] || 0
                if (t < 0.04) t = 0
                const nv = d[i] + (t - d[i]) * (t > d[i] ? 0.42 : 0.18)
                moved += Math.abs(nv - d[i])
                d[i] = nv
                if (nv > peak) peak = nv
                // blossoms: snap open on peaks, close slowly
                if (i % 8 === 3) {
                    const target = nv > 0.72 ? 1 : nv > 0.45 ? (nv - 0.45) / 0.27 : 0
                    bl[i] = bl[i] + (target - bl[i]) * (target > bl[i] ? 0.35 : 0.05)
                }
            }
            // the wind only blows while something is audible
            if (peak > 0.03) root.phase += 0.055 + peak * 0.05
            if (moved > 0.0025 || peak > 0.03) {
                root.display = d
                root.bloom = bl
                meadow.requestPaint()
            }
            // cava sleeps at silence (sleep_timer) — nothing left to ease; parseFrame rearms
            else if (Date.now() - root.lastFrameMs > 2000)
                smooth.stop()
        }
    }

    Canvas {
        id: meadow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.round(210 * root.ui)
        renderStrategy: Canvas.Threaded

        onWidthChanged: requestPaint()
        Connections {
            target: root.pal
            function onNeonChanged()    { meadow.requestPaint() }
            function onCyanChanged()    { meadow.requestPaint() }
            function onMagentaChanged() { meadow.requestPaint() }
            function onDimChanged()     { meadow.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            if (w <= 0) return
            const N = root.bladeCount
            const d = root.display
            const bl = root.bloom
            const grow = root.bootT

            // a whisper of ground haze so the meadow roots into the frame
            const g = ctx.createLinearGradient(0, h * 0.55, 0, h)
            g.addColorStop(0, "rgba(0,0,0,0)")
            g.addColorStop(1, Qt.rgba(root.pal.glass.r, root.pal.glass.g, root.pal.glass.b, 0.32))
            ctx.fillStyle = g
            ctx.fillRect(0, h * 0.55, w, h * 0.45)

            ctx.lineCap = "round"
            for (let i = 0; i < N; i++) {
                const j1 = root.jit(i, 1), j2 = root.jit(i, 2), j3 = root.jit(i, 3)
                const bx = ((i + 0.5) / N + (j1 - 0.5) * 0.011) * w
                const lvl = d[i] || 0
                const rest = (7 + j2 * 12) * root.ui
                const bh = grow * (rest + lvl * (h - 60 * root.ui))
                const lean = (j3 - 0.5) * 8 * root.ui
                const sway = Math.sin(root.phase + i * 0.62 + j1 * 6.28)
                    * (2.5 * root.ui + lvl * 15 * root.ui)
                const tipX = bx + lean + sway
                const tipY = h - bh
                const isBlossom = i % 8 === 3

                // the blade: a curved stem, greener when tall, mossier at rest
                ctx.beginPath()
                ctx.moveTo(bx, h)
                ctx.quadraticCurveTo(bx + lean * 0.4 + sway * 0.35, h - bh * 0.55, tipX, tipY)
                const gr = 0.35 + lvl * 0.6
                ctx.strokeStyle = Qt.rgba(
                    root.moss.r + (root.leaf.r - root.moss.r) * gr,
                    root.moss.g + (root.leaf.g - root.moss.g) * gr,
                    root.moss.b + (root.leaf.b - root.moss.b) * gr,
                    0.5 + lvl * 0.45)
                ctx.lineWidth = (1.3 + j2 * 0.9 + lvl * 0.8) * root.ui
                ctx.stroke()

                // a small leaf partway up the taller stems
                if (bh > 46 * root.ui && (i % 3 === 0)) {
                    const lx = bx + (lean + sway) * 0.4
                    const ly = h - bh * 0.45
                    ctx.save()
                    ctx.translate(lx, ly)
                    ctx.rotate((j1 - 0.5) * 1.6 + (i % 2 === 0 ? -0.8 : 0.8))
                    ctx.beginPath()
                    ctx.ellipse(0, -2.2 * root.ui, (7 + lvl * 5) * root.ui, 4.4 * root.ui)
                    ctx.fillStyle = Qt.rgba(root.leaf.r, root.leaf.g, root.leaf.b, 0.35 + lvl * 0.3)
                    ctx.fill()
                    ctx.restore()
                }

                // blossom tips: five petals that open on peaks
                if (isBlossom) {
                    const open = bl[i] || 0
                    if (open > 0.04) {
                        const pr = (3.5 + open * 6.5) * root.ui
                        const petal = i % 16 === 3 ? root.rose : root.cream
                        ctx.save()
                        ctx.translate(tipX, tipY)
                        ctx.rotate(sway * 0.02)
                        ctx.fillStyle = Qt.rgba(petal.r, petal.g, petal.b, 0.35 + open * 0.6)
                        for (let k = 0; k < 5; k++) {
                            const a = -Math.PI / 2 + k * Math.PI * 2 / 5
                            ctx.save()
                            ctx.translate(Math.cos(a) * pr * 0.75, Math.sin(a) * pr * 0.75)
                            ctx.rotate(a + Math.PI / 2)
                            ctx.beginPath()
                            ctx.ellipse(-pr * 0.32, -pr * 0.75, pr * 0.64, pr * 1.5)
                            ctx.fill()
                            ctx.restore()
                        }
                        ctx.beginPath()
                        ctx.arc(0, 0, pr * 0.34, 0, Math.PI * 2)
                        ctx.fillStyle = Qt.rgba(root.gold.r, root.gold.g, root.gold.b, 0.55 + open * 0.45)
                        ctx.fill()
                        ctx.restore()
                    } else {
                        // closed bud resting on the tip
                        ctx.beginPath()
                        ctx.ellipse(tipX - 1.8 * root.ui, tipY - 2.6 * root.ui, 3.6 * root.ui, 5.2 * root.ui)
                        ctx.fillStyle = Qt.rgba(root.gold.r, root.gold.g, root.gold.b, 0.45)
                        ctx.fill()
                    }
                }
            }
        }
    }
}
