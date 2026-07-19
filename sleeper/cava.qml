import QtQuick
import Quickshell.Io

// sleeper: the music is IN the tea. A podstakannik — tea glass in its brass
// holder — stands on the table below the window, and while music plays the
// tea's surface is the spectrum: a low amber waveform swaying across the rim,
// beats ringing ripples out to the glass walls, steam rising with the mids,
// and the spoon rattling against the holder on the bass. The whole glass
// rocks on the shared bogie rhythm — the same wall-time sway every sleeper
// widget locks to. At silence the surface settles flat, the steam dies, the
// canvas stops painting and the cava process itself is parked (feed gate
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

    readonly property color green: pal.neon
    readonly property color moonpale: pal.cyan
    readonly property color tea: pal.amber
    readonly property color wood: pal.dim
    readonly property color linen: pal.text
    function colA(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    readonly property int bins: 24

    property var levels: []
    property var display: []
    property bool humming: false
    property real bassPrev: 0
    property var rings: []        // {r: 0..1, a: alpha}
    property real rattle: 0       // spoon energy, decays
    property real steamT: 0       // steam phase, advances only while humming

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

    Component.onCompleted: {
        const d = []
        for (let i = 0; i < bins; i++) d.push(0)
        display = d
    }

    // ── the bogie clock (shared wall-time phase — see DESIGN.md) ───────────
    readonly property real swayPeriod: 4200
    property real swayPhase: 0
    property real swayAmp: humming ? 1 : 0
    Behavior on swayAmp { NumberAnimation { duration: 1400; easing.type: Easing.InOutSine } }
    readonly property real rock: Math.sin(swayPhase) * swayAmp
    readonly property real heave: Math.sin(swayPhase * 2 + 0.7) * swayAmp

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

    // smoothing + ripple/rattle physics — stops itself once frames go stale
    // and the tea has gone flat, so silence costs nothing.
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
                d[i] = d[i] + (t - d[i]) * 0.35
                if (d[i] < 0.005) d[i] = 0
                if (d[i] > loud) loud = d[i]
                if (d[i] > 0.004) settled = false
            }

            // bass edge → a new ripple ring + spoon rattle
            let bass = 0
            for (let i = 0; i < 4; i++) bass = Math.max(bass, d[i])
            if (bass - root.bassPrev > 0.16 && bass > 0.3) {
                root.rings.push({ r: 0.12, a: 0.5 * bass })
                if (root.rings.length > 5) root.rings.shift()
                root.rattle = Math.min(1, root.rattle + bass * 0.9)
            }
            root.bassPrev = bass

            // rings run out to the walls and die there
            const keep = []
            for (const g of root.rings) {
                g.r += 0.045
                g.a *= 0.92
                if (g.r < 1 && g.a > 0.01) { keep.push(g); settled = false }
            }
            root.rings = keep
            root.rattle *= 0.86
            if (root.rattle < 0.01) root.rattle = 0
            else settled = false

            // the bogie phase + steam advance ride the same tick
            root.swayPhase = ((Date.now() % root.swayPeriod) / root.swayPeriod) * 2 * Math.PI
            root.steamT += 0.033

            const now = Date.now()
            const audioActive = loud > 0.05
            if (audioActive) root.lastFrameMs = now

            const nowHumming = audioActive || !settled
            if (nowHumming !== root.humming) root.humming = nowHumming

            glassC.requestPaint()
            if (!nowHumming && now - root.lastFrameMs > 2000) tick.stop()   // cava asleep
        }
    }

    // ── the glass on the table ──────────────────────────────────────────────
    Canvas {
        id: glassC
        width: 170
        height: 210
        x: Math.round(root.width * 0.535 - width / 2)
        y: Math.round(root.height * 0.885 - height * 0.8) + root.heave * 1.8
        scale: pal.uiScale
        transformOrigin: Item.Bottom
        rotation: root.rock * 0.7

        opacity: root.bootT * (root.humming ? 1 : 0.4)
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            const gx = 45, gw = 80              // glass left / width
            const gTop = 32, gBot = 168         // rim / bottom
            const teaY = 66                     // resting tea line
            const cx = gx + gw / 2

            const energy = root.display.reduce((a, b) => Math.max(a, b), 0)
            let mid = 0
            for (let i = 8; i < 16; i++) mid = Math.max(mid, root.display[i] || 0)

            // warm halo behind the glass, breathing with the music
            if (energy > 0.02) {
                const halo = ctx.createRadialGradient(cx, (teaY + gBot) / 2, 10, cx, (teaY + gBot) / 2, 95)
                halo.addColorStop(0, String(root.colA(root.tea, 0.10 * energy + 0.03)))
                halo.addColorStop(1, String(root.colA(root.tea, 0)))
                ctx.fillStyle = halo
                ctx.fillRect(0, 0, w, h)
            }

            // ── the tea: filled to the waveform surface ──
            ctx.beginPath()
            const n = root.bins
            for (let i = 0; i <= n; i++) {
                const fx = gx + 2 + (gw - 4) * (i / n)
                const v = i === n ? (root.display[n - 1] || 0) : (root.display[i] || 0)
                // edges pinned so the tea never leaves the glass walls
                const pin = Math.sin(Math.PI * (i / n))
                const fy = teaY - v * 16 * pin
                if (i === 0) ctx.moveTo(fx, fy); else ctx.lineTo(fx, fy)
            }
            ctx.lineTo(gx + gw - 2, gBot - 2)
            ctx.lineTo(gx + 2, gBot - 2)
            ctx.closePath()
            const teaG = ctx.createLinearGradient(0, teaY - 16, 0, gBot)
            teaG.addColorStop(0, String(root.colA(root.tea, 0.55)))
            teaG.addColorStop(1, String(Qt.rgba(root.tea.r * 0.4, root.tea.g * 0.32, root.tea.b * 0.28, 0.6)))
            ctx.fillStyle = teaG
            ctx.fill()

            // the surface gleam — moon catching the moving tea
            ctx.beginPath()
            for (let i = 0; i <= n; i++) {
                const fx = gx + 2 + (gw - 4) * (i / n)
                const v = i === n ? (root.display[n - 1] || 0) : (root.display[i] || 0)
                const pin = Math.sin(Math.PI * (i / n))
                const fy = teaY - v * 16 * pin
                if (i === 0) ctx.moveTo(fx, fy); else ctx.lineTo(fx, fy)
            }
            ctx.strokeStyle = String(root.colA(root.moonpale, 0.35 + energy * 0.45))
            ctx.lineWidth = 1.4
            ctx.stroke()

            // ── ripple rings running out to the walls ──
            for (const g of root.rings) {
                ctx.beginPath()
                ctx.ellipse(cx - (gw / 2 - 4) * g.r, teaY - 4 * g.r,
                            (gw - 8) * g.r, 8 * g.r)
                ctx.strokeStyle = String(root.colA(root.moonpale, g.a))
                ctx.lineWidth = 1
                ctx.stroke()
            }

            // ── steam, riding the mids ──
            const sA = Math.min(0.35, mid * 0.5)
            if (sA > 0.02) {
                for (let s = 0; s < 3; s++) {
                    const sx = cx - 18 + s * 18
                    ctx.beginPath()
                    ctx.moveTo(sx, teaY - 6)
                    for (let k = 1; k <= 5; k++) {
                        const ky = teaY - 6 - k * 9
                        const kx = sx + Math.sin(root.steamT * 1.3 + s * 2.1 + k * 0.9) * (3 + k * 1.5)
                        ctx.lineTo(kx, ky)
                    }
                    ctx.strokeStyle = String(root.colA(root.linen, sA * (1 - s * 0.22)))
                    ctx.lineWidth = 1.2
                    ctx.stroke()
                }
            }

            // ── the glass walls ──
            ctx.strokeStyle = String(root.colA(root.linen, 0.45))
            ctx.lineWidth = 1.5
            ctx.beginPath()
            ctx.moveTo(gx, gTop)
            ctx.lineTo(gx, gBot)
            ctx.lineTo(gx + gw, gBot)
            ctx.lineTo(gx + gw, gTop)
            ctx.stroke()
            // rim ellipse
            ctx.beginPath()
            ctx.ellipse(gx, gTop - 3, gw, 6)
            ctx.strokeStyle = String(root.colA(root.linen, 0.35))
            ctx.lineWidth = 1
            ctx.stroke()

            // ── the spoon, leaning in the glass — rattling on the bass ──
            const rt = (Math.random() - 0.5) * 6 * root.rattle
            ctx.save()
            ctx.translate(gx + gw - 14, teaY)
            ctx.rotate((-24 + rt) * Math.PI / 180)
            ctx.strokeStyle = String(root.colA(root.moonpale, 0.7))
            ctx.lineWidth = 2
            ctx.beginPath()
            ctx.moveTo(0, -46)
            ctx.lineTo(0, 26)
            ctx.stroke()
            ctx.beginPath()
            ctx.ellipse(-3, 26, 6, 12)
            ctx.strokeStyle = String(root.colA(root.moonpale, 0.5))
            ctx.lineWidth = 1.2
            ctx.stroke()
            ctx.restore()

            // ── the podstakannik: brass band, lattice, handle ──
            const bandY = 108
            ctx.strokeStyle = String(root.colA(root.tea, 0.8))
            ctx.lineWidth = 1.5
            ctx.strokeRect(gx - 4, bandY, gw + 8, gBot - bandY)
            // diamond lattice
            ctx.lineWidth = 1
            ctx.strokeStyle = String(root.colA(root.tea, 0.5 + 0.3 * energy))
            const step = 14
            for (let lx = gx - 4; lx < gx + gw + 4; lx += step) {
                ctx.beginPath()
                ctx.moveTo(lx, bandY)
                ctx.lineTo(lx + step / 2, (bandY + gBot) / 2)
                ctx.lineTo(lx, gBot)
                ctx.moveTo(lx + step, bandY)
                ctx.lineTo(lx + step / 2, (bandY + gBot) / 2)
                ctx.lineTo(lx + step, gBot)
                ctx.stroke()
            }
            // the handle
            ctx.beginPath()
            ctx.moveTo(gx + gw + 4, bandY + 6)
            ctx.bezierCurveTo(gx + gw + 30, bandY + 2, gx + gw + 30, gBot + 4, gx + gw + 4, gBot - 4)
            ctx.strokeStyle = String(root.colA(root.tea, 0.8))
            ctx.lineWidth = 2
            ctx.stroke()
            // base ring
            ctx.beginPath()
            ctx.ellipse(gx - 8, gBot - 2, gw + 16, 8)
            ctx.strokeStyle = String(root.colA(root.tea, 0.55))
            ctx.lineWidth = 1.5
            ctx.stroke()
        }
    }
}
