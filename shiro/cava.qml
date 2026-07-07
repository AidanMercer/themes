import QtQuick
import Quickshell.Io

// white: the ink enso — a brush-drawn zen circle that IS the spectrum.
//
// Loaded by the archlogo wrapper in place of the Arch triangle. Self-contained:
// runs its own cava with the cava.conf next door. The ring's contour is the
// mirrored spectrum, the brush pressure (stroke weight) drifts slowly around
// the circle while audio plays, bass makes the whole stroke breathe, and hard
// bass hits flick tiny ink droplets off the ring — like the flecks in the
// wallpaper. Paints itself on with a single brush sweep at load; at true
// silence it settles into a calm, still enso and stops repainting.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color ink:      pal.text
    readonly property color wisteria: pal.neon
    readonly property color blush:    pal.cyan

    readonly property real ui: pal.uiScale

    // enso geometry — sits in the empty paper below-right of the clock
    readonly property real cx: root.width * 0.26
    readonly property real cy: root.height * 0.75
    readonly property real ringR: 96 * ui
    readonly property real push: 30 * ui          // loudest outward contour push

    readonly property int barCount: 24
    readonly property int ptCount: 48             // mirrored spectrum around the ring
    property var levels: []
    property var display: []

    property real rot: 0                          // brush-pressure drift, audio-gated
    property real bass: 0
    property real _prevBass: 0
    property var droplets: []                     // {x,y,vx,vy,r,life,blush}
    property double _lastFlick: 0

    // boot-in: the enso draws itself with one brush sweep
    property real bootT: 0
    NumberAnimation on bootT {
        running: true; from: 0; to: 1; duration: 1300; easing.type: Easing.InOutCubic
    }
    onBootTChanged: canvas.requestPaint()

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
            let moved = 0
            let peak = 0
            for (let i = 0; i < root.barCount; i++) {
                let t = l[i] || 0
                if (t < 0.04) t = 0
                const nv = d[i] + (t - d[i]) * 0.38
                moved += Math.abs(nv - d[i])
                d[i] = nv
                if (nv > peak) peak = nv
            }

            const b = ((d[0] || 0) + (d[1] || 0) + (d[2] || 0) + (d[3] || 0)) / 4
            root._prevBass = root.bass
            root.bass = root.bass + (b - root.bass) * 0.5

            // hard bass onset -> flick 1..3 ink droplets off the ring
            const now = Date.now()
            if (root.bass > 0.45 && root.bass - root._prevBass > 0.10
                    && now - root._lastFlick > 220 && root.bootT >= 1) {
                root._lastFlick = now
                const n = 1 + Math.floor(Math.random() * 3)
                const ds = root.droplets
                for (let k = 0; k < n && ds.length < 24; k++) {
                    const a = Math.random() * Math.PI * 2
                    const sp = (1.8 + Math.random() * 3.2) * root.ui
                    ds.push({
                        x: root.ringR * Math.cos(a), y: root.ringR * Math.sin(a),
                        vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 0.4,
                        r: (1.2 + Math.random() * 2.2) * root.ui,
                        life: 1, blush: Math.random() < 0.2
                    })
                }
            }

            // droplets drift, slow down, soak into the paper
            let dropAlive = false
            if (root.droplets.length) {
                const ds = root.droplets
                for (let k = ds.length - 1; k >= 0; k--) {
                    const p = ds[k]
                    p.x += p.vx; p.y += p.vy
                    p.vx *= 0.94; p.vy *= 0.94
                    p.life -= 0.022
                    if (p.life <= 0) ds.splice(k, 1)
                }
                dropAlive = ds.length > 0
            }

            // the brush pressure wanders only while something is audible
            if (peak > 0.03) root.rot = (root.rot + 0.35) % 360

            if (moved > 0.002 || peak > 0.03 || dropAlive)
                canvas.requestPaint()
            // cava sleeps at silence (sleep_timer) — nothing left to ease; parseFrame rearms
            else if (Date.now() - root.lastFrameMs > 2000)
                smooth.stop()
        }
    }

    // mirrored contour: bin j for the left half, reflected on the right, so the
    // ring closes seamlessly
    function binAt(j) {
        const d = root.display
        return (j < root.barCount ? d[j] : d[root.ptCount - 1 - j]) || 0
    }

    Canvas {
        id: canvas
        readonly property real box: (root.ringR + root.push + 84 * root.ui)
        x: root.cx - box
        y: root.cy - box
        width: box * 2
        height: box * 2

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const c = box
            const rotR = root.rot * Math.PI / 180

            // where the brush lifts: the enso's tapered opening
            const gapA = -Math.PI / 3.2 + rotR * 0.25
            const gapHalf = 0.11
            const pressPhase = gapA + Math.PI * 1.25 + rotR * 0.5

            // boot: reveal as one brush sweep from the gap edge
            if (root.bootT < 1) {
                const sweep = Math.max(0.001, root.bootT) * Math.PI * 2
                ctx.beginPath()
                ctx.moveTo(c, c)
                ctx.arc(c, c, box, gapA + gapHalf, gapA + gapHalf + sweep, false)
                ctx.closePath()
                ctx.clip()
            }

            // soft wisteria aura behind the stroke, breathing with the bass
            ctx.beginPath()
            ctx.arc(c, c, root.ringR * (1 + 0.05 * root.bass), 0, Math.PI * 2)
            ctx.strokeStyle = Qt.rgba(root.wisteria.r, root.wisteria.g, root.wisteria.b,
                                      0.05 + 0.10 * root.bass)
            ctx.lineWidth = 30 * root.ui
            ctx.stroke()

            // contour + brush-weight sample points
            const N = root.ptCount
            const R = root.ringR * (1 + 0.05 * root.bass)
            const ox = [], oy = [], ix = [], iy = []
            for (let j = 0; j < N; j++) {
                const a = gapA + gapHalf + (j / N) * Math.PI * 2
                // taper the stroke to nothing across the gap
                const dGap = Math.min(
                    Math.abs(((a - gapA) % (Math.PI * 2) + Math.PI * 3) % (Math.PI * 2) - Math.PI),
                    Math.PI)
                const taper = Math.min(1, Math.max(0, (dGap - gapHalf) / 0.55))
                // brush pressure: one thick pass that drifts around the circle
                const press = Math.pow(0.5 + 0.5 * Math.cos(a - pressPhase), 1.7)
                const w = ((2.4 + 7.6 * press) * root.ui + 2.5 * root.binAt(j)) * taper
                const r = R + root.push * root.binAt(j)
                const ca = Math.cos(a), sa = Math.sin(a)
                ox.push(c + (r + w / 2) * ca); oy.push(c + (r + w / 2) * sa)
                ix.push(c + (r - w / 2) * ca); iy.push(c + (r - w / 2) * sa)
            }

            // ink band: smooth outer loop, then the inner loop reversed cuts the hole
            ctx.beginPath()
            ctx.moveTo((ox[N - 1] + ox[0]) / 2, (oy[N - 1] + oy[0]) / 2)
            for (let j = 0; j < N; j++) {
                const k = (j + 1) % N
                ctx.quadraticCurveTo(ox[j], oy[j], (ox[j] + ox[k]) / 2, (oy[j] + oy[k]) / 2)
            }
            ctx.moveTo((ix[0] + ix[N - 1]) / 2, (iy[0] + iy[N - 1]) / 2)
            for (let j = N - 1; j >= 0; j--) {
                const k = (j - 1 + N) % N
                ctx.quadraticCurveTo(ix[j], iy[j], (ix[j] + ix[k]) / 2, (iy[j] + iy[k]) / 2)
            }
            ctx.fillStyle = Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.78)
            ctx.fill()

            // a whisper of wet-ink bleed just outside the stroke
            ctx.beginPath()
            ctx.moveTo((ox[N - 1] + ox[0]) / 2, (oy[N - 1] + oy[0]) / 2)
            for (let j = 0; j < N; j++) {
                const k = (j + 1) % N
                ctx.quadraticCurveTo(ox[j], oy[j], (ox[j] + ox[k]) / 2, (oy[j] + oy[k]) / 2)
            }
            ctx.strokeStyle = Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)
            ctx.lineWidth = 3 * root.ui
            ctx.stroke()

            // the brush's first touch: a blush dot at the gap's thick edge
            {
                const a = gapA + gapHalf + 0.02
                const r = R + root.push * root.binAt(0)
                ctx.beginPath()
                ctx.arc(c + r * Math.cos(a), c + r * Math.sin(a), 3 * root.ui, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(root.blush.r, root.blush.g, root.blush.b, 0.9)
                ctx.fill()
            }

            // flicked ink droplets
            for (const p of root.droplets) {
                ctx.beginPath()
                ctx.arc(c + p.x, c + p.y, p.r, 0, Math.PI * 2)
                const col = p.blush ? root.blush : root.ink
                ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, 0.55 * p.life)
                ctx.fill()
            }
        }
    }
}
