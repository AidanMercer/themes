import QtQuick
import Quickshell.Io

// guts: center visualizer — a sword wound. A rough horizontal gash lies
// across the screen's middle; the 44 cava bands are diagonal slash marks
// cutting through it, alternating up/down like frenzied swings. Strokes
// attack instantly and dry slowly (fast rise, slow fade — wet ink drying),
// the loudest cuts flash arterial red, and bass kicks spatter ink off the
// wound. Every slash is drawn manga-style: a paper-white casing under the
// ink core, so the marks read over both the white sky and the dark figure.
// Runs its own cava (cava.conf next door); silent desktop = zero repaints.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color ink:   pal.text
    readonly property color blood: pal.neon
    readonly property color fresh: pal.magenta
    readonly property color paper: pal.glass

    readonly property int barCount: 44
    property var levels: []
    property var display: []
    property var splats: []          // {x, y, vx, vy, r, life, red}
    property real pulse: 0           // bass energy 0..1
    property real prevPulse: 0
    property bool anyInk: false      // anything still visible on canvas?

    // boot-in
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 600; easing.type: Easing.OutCubic }

    Component.onCompleted: {
        const z = []
        for (let i = 0; i < barCount; i++) z.push(0)
        display = z
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

    Timer {
        id: smooth
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            const d = root.display
            const l = root.levels
            let moved = 0, vis = 0
            for (let i = 0; i < root.barCount; i++) {
                let t = l[i] || 0
                if (t < 0.04) t = 0
                // wet attack, slow dry
                const gain = t > d[i] ? 0.55 : 0.075
                const nv = d[i] + (t - d[i]) * gain
                moved += Math.abs(nv - d[i])
                d[i] = nv
                if (nv > 0.012) vis++
            }
            // bass drives the gash + the spatter
            root.prevPulse = root.pulse
            root.pulse = ((l[0] || 0) + (l[1] || 0) + (l[2] || 0) + (l[3] || 0)) / 4
            if (root.pulse > 0.5 && root.pulse - root.prevPulse > 0.14)
                root.spawnSplats()

            // advance spatter physics
            let sp = root.splats
            if (sp.length) {
                const next = []
                for (const s of sp) {
                    s.x += s.vx; s.y += s.vy; s.vy += 0.35
                    s.life -= 0.045
                    if (s.life > 0) next.push(s)
                }
                root.splats = next
                vis++
            }

            const active = moved > 0.002 || root.splats.length > 0 || vis > 0
            if (active) {
                root.display = d
                root.anyInk = true
                canvas.requestPaint()
            } else if (root.anyInk) {
                root.anyInk = false        // one final clear, then rest
                canvas.requestPaint()
            }
            // cava sleeps at silence (sleep_timer) — nothing left to ease; parseFrame rearms
            else if (Date.now() - root.lastFrameMs > 2000)
                smooth.stop()
        }
    }

    function spawnSplats() {
        const sp = root.splats.slice()
        const n = 4 + Math.round(Math.random() * 4)
        for (let i = 0; i < n && sp.length < 40; i++) {
            const a = Math.random() * Math.PI * 2
            const v = 2.5 + Math.random() * 5
            sp.push({
                x: stage.width / 2 + (Math.random() - 0.5) * stage.width * 0.4,
                y: stage.height / 2 + (Math.random() - 0.5) * 24,
                vx: Math.cos(a) * v,
                vy: Math.sin(a) * v - 2.5,
                r: 1.2 + Math.random() * 2.6,
                life: 1,
                red: Math.random() < 0.3
            })
        }
        root.splats = sp
    }

    Item {
        id: stage
        width: 960
        height: 420
        anchors.centerIn: parent
        opacity: root.bootT
        scale: pal.uiScale

        Canvas {
            id: canvas
            anchors.fill: parent
            renderStrategy: Canvas.Threaded

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                if (!root.anyInk) return
                const w = width, h = height, cy = h / 2
                const d = root.display, n = root.barCount
                const span = w * 0.86
                const x0 = (w - span) / 2
                const maxLen = h * 0.40
                const slashA = -0.62           // slash angle (rad from horizontal)

                // ── the gash: a rough horizontal wound, breathing with bass ──
                const gw = 1.5 + root.pulse * 3.5
                const galpha = 0.25 + Math.min(0.5, root.pulse * 0.7)
                ctx.lineCap = "round"
                // paper casing first
                ctx.strokeStyle = Qt.rgba(root.paper.r, root.paper.g, root.paper.b, galpha * 0.9)
                ctx.lineWidth = gw + 4
                ctx.beginPath()
                ctx.moveTo(x0 - 14, cy + Math.sin(x0) * 2)
                for (let x = x0 - 14; x <= x0 + span + 14; x += 12)
                    ctx.lineTo(x, cy + Math.sin(x * 0.02) * 2.2)
                ctx.stroke()
                // ink core
                ctx.strokeStyle = Qt.rgba(root.ink.r, root.ink.g, root.ink.b, galpha)
                ctx.lineWidth = gw
                ctx.beginPath()
                ctx.moveTo(x0 - 14, cy + Math.sin(x0) * 2)
                for (let x = x0 - 14; x <= x0 + span + 14; x += 12)
                    ctx.lineTo(x, cy + Math.sin(x * 0.02) * 2.2)
                ctx.stroke()
                // blood welling in the wound on a heavy hit
                if (root.pulse > 0.45) {
                    ctx.strokeStyle = Qt.rgba(root.fresh.r, root.fresh.g, root.fresh.b,
                                              (root.pulse - 0.45) * 1.3)
                    ctx.lineWidth = Math.max(1, gw * 0.4)
                    ctx.beginPath()
                    ctx.moveTo(x0 + span * 0.2, cy + 1)
                    for (let x = x0 + span * 0.2; x <= x0 + span * 0.8; x += 12)
                        ctx.lineTo(x, cy + 1 + Math.sin(x * 0.02) * 2.2)
                    ctx.stroke()
                }

                // ── the slashes: one cut per band, alternating direction ──
                function slash(xc, lvl, up, jig) {
                    const len = (0.12 + lvl * 0.88) * maxLen
                    const a = slashA + jig
                    const dx = Math.cos(a) * len, dy = Math.sin(a) * len
                    const sx = xc - dx * 0.5, sy = cy - (up ? dy : -dy) * 0.5
                    const ex = xc + dx * 0.5, ey = cy + (up ? dy : -dy) * 0.5
                    const alpha = Math.min(1, lvl * 1.7)
                    const hot = lvl > 0.78
                    const lw = 1.6 + lvl * 2.6
                    // paper casing
                    ctx.strokeStyle = Qt.rgba(root.paper.r, root.paper.g, root.paper.b, alpha * 0.85)
                    ctx.lineWidth = lw + 3
                    ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(ex, ey); ctx.stroke()
                    // core: ink, arterial red when the cut runs deep
                    ctx.strokeStyle = hot
                        ? Qt.rgba(root.fresh.r, root.fresh.g, root.fresh.b, alpha)
                        : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, alpha)
                    ctx.lineWidth = lw
                    ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(ex, ey); ctx.stroke()
                    // dry-brush exit fleck on strong cuts
                    if (lvl > 0.5) {
                        ctx.fillStyle = ctx.strokeStyle
                        ctx.beginPath()
                        ctx.arc(ex + Math.cos(a) * 5, ey + (up ? 1 : -1) * Math.sin(a) * 5,
                                lw * 0.35, 0, Math.PI * 2)
                        ctx.fill()
                    }
                }

                for (let i = 0; i < n; i++) {
                    const lvl = d[i] || 0
                    if (lvl <= 0.012) continue
                    // low bands cut near the center, highs toward the edges
                    const k = i / (n - 1)
                    const xc = x0 + span * k
                    const jig = Math.sin(i * 3.7) * 0.10
                    slash(xc, lvl, i % 2 === 0, jig)
                }

                // ── ink spatter kicked off the wound ──
                for (const s of root.splats) {
                    const c = s.red ? root.fresh : root.ink
                    ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, Math.max(0, s.life) * 0.9)
                    ctx.beginPath()
                    ctx.arc(s.x, s.y, s.r * (0.5 + s.life * 0.5), 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }
    }
}
