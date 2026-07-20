import QtQuick
import Quickshell.Io

// sakura: the low branch. A slender twig arcs across the lower middle of the
// screen carrying sixteen blossom clusters — one per cava band. Each cluster
// opens with its band (bud at silence, full five-petal bloom at peak) and a
// hard onset shakes a single petal loose to drift down and fade (law 2).
// At true silence the whole branch closes to buds, fades out completely and
// stops painting. Runs its own cava against cava.conf; click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // pushed by the loader after mount: lock/fullscreen cover + mpris playing
    property bool occluded: false
    property bool playing: true
    readonly property bool feedOn: playing && !occluded

    readonly property color pink:  pal.neon
    readonly property color sky:   pal.cyan
    readonly property color cream: pal.text
    readonly property color twig:  pal.dim
    function pinkA(a)  { return Qt.rgba(pink.r, pink.g, pink.b, a) }
    function creamA(a) { return Qt.rgba(cream.r, cream.g, cream.b, a) }
    function twigA(a)  { return Qt.rgba(twig.r, twig.g, twig.b, a) }

    readonly property int bins: 16

    property var levels: []       // raw cava bins 0..1
    property var display: []      // smoothed bloom per cluster
    property var prev: []         // previous display, for onset detection
    property var petals: []       // loose petals in flight
    property real energy: 0       // smoothed loudness → faint light on the branch
    property bool humming: false  // audio present or petals still falling

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutSine }

    Component.onCompleted: {
        const z = [], p = []
        for (let i = 0; i < bins; i++) { z.push(0); p.push(0) }
        display = z
        prev = p
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

    // cluster position along the branch arc, in canvas coords
    function clusterX(i) { return branch.width * (0.06 + 0.88 * i / (bins - 1)) }
    function branchY(t)  { return branch.height * (0.82 - 0.16 * Math.sin(Math.PI * t)) }

    // shake one petal loose from cluster i with strength s
    function shedPetal(i, s) {
        const t = 0.06 + 0.88 * i / (bins - 1)
        const arr = root.petals
        arr.push({
            x: clusterX(i) + (Math.random() - 0.5) * 8,
            y: branchY(t) - 14,
            vx: (Math.random() - 0.5) * 0.9 + 0.35,
            vy: 0.5 + s * 0.8,
            rot: Math.random() * 360,
            vr: (Math.random() - 0.5) * 3.2,
            life: 1,
            decay: 0.006 + Math.random() * 0.004,
            r: 4.5 + s * 3.5
        })
        root.petals = arr
    }

    // smoothing + physics pump — gates itself off at true silence
    Timer {
        id: tick
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            const d = root.display, l = root.levels, p = root.prev
            let loud = 0
            for (let i = 0; i < root.bins; i++) {
                let t = l[i] || 0
                if (t < 0.04) t = 0
                d[i] = d[i] + (t - d[i]) * 0.38
                if (d[i] > loud) loud = d[i]
            }
            root.energy = root.energy + (loud - root.energy) * 0.2

            const now = Date.now()
            // feedOn guard: when the feed is cut (lock/pause) `levels` freezes —
            // without it stale loudness would keep this tick alive forever
            const audioActive = root.feedOn && loud > 0.06

            // onsets shake petals loose, rationed so it stays a drift not a storm
            if (audioActive && root.petals.length < 30) {
                for (let i = 0; i < root.bins; i++) {
                    const edge = d[i] - p[i]
                    if (d[i] > 0.5 && edge > 0.11 && Math.random() < 0.20 + d[i] * 0.25)
                        root.shedPetal(i, d[i])
                }
            }
            for (let i = 0; i < root.bins; i++) p[i] = d[i]

            // advance + cull the loose petals
            const alive = []
            const ps = root.petals
            for (let k = 0; k < ps.length; k++) {
                const m = ps[k]
                m.x += m.vx + Math.sin(m.life * 9) * 0.4
                m.y += m.vy
                m.vy = Math.min(1.6, m.vy + 0.012)
                m.rot += m.vr
                m.life -= m.decay
                if (m.life > 0 && m.y < branch.height + 20) alive.push(m)
            }
            root.petals = alive

            const nowHumming = audioActive || alive.length > 0 || root.energy > 0.02
            if (nowHumming !== root.humming) root.humming = nowHumming
            if (audioActive) root.lastFrameMs = now

            if (nowHumming) {
                branch.requestPaint()
            } else {
                branch.requestPaint()   // final clear as it fades out
                if (now - root.lastFrameMs > 2000) tick.stop()  // cava asleep
            }
        }
    }

    // the notched-petal blossom, bud→bloom — the theme's one glyph
    function drawBlossom(ctx, r, bloom, fillCol, coreCol) {
        if (bloom < 0.1) {
            ctx.beginPath()
            ctx.arc(0, 0, Math.max(1, r * 0.30), 0, 2 * Math.PI)
            ctx.fillStyle = fillCol
            ctx.fill()
            return
        }
        const pr = r * (0.4 + 0.6 * bloom)
        const w = pr * 0.55 * (0.55 + 0.45 * bloom)
        for (let i = 0; i < 5; i++) {
            ctx.save()
            ctx.rotate(i * Math.PI * 2 / 5)
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.bezierCurveTo(-w, -pr * 0.35, -w * 0.9, -pr * 0.85, -pr * 0.16, -pr * 0.97)
            ctx.lineTo(0, -pr * 0.85)
            ctx.lineTo(pr * 0.16, -pr * 0.97)
            ctx.bezierCurveTo(w * 0.9, -pr * 0.85, w, -pr * 0.35, 0, 0)
            ctx.closePath()
            ctx.fillStyle = fillCol
            ctx.fill()
            ctx.restore()
        }
        ctx.beginPath()
        ctx.arc(0, 0, Math.max(0.8, r * 0.13), 0, 2 * Math.PI)
        ctx.fillStyle = coreCol
        ctx.fill()
    }

    // one loose petal (single notched petal shape)
    function drawPetal(ctx, x, y, r, rot, a) {
        ctx.save()
        ctx.translate(x, y)
        ctx.rotate(rot * Math.PI / 180)
        ctx.beginPath()
        ctx.moveTo(0, r * 0.5)
        ctx.bezierCurveTo(-r * 0.8, 0, -r * 0.6, -r * 0.8, -r * 0.14, -r * 0.9)
        ctx.lineTo(0, -r * 0.76)
        ctx.lineTo(r * 0.14, -r * 0.9)
        ctx.bezierCurveTo(r * 0.6, -r * 0.8, r * 0.8, 0, 0, r * 0.5)
        ctx.closePath()
        ctx.fillStyle = String(root.pinkA(0.75 * a))
        ctx.fill()
        ctx.restore()
    }

    Canvas {
        id: branch
        width: Math.round(root.width * 0.52)
        height: Math.round(root.height * 0.30)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.06)
        scale: pal.uiScale
        transformOrigin: Item.Bottom

        opacity: root.bootT * (root.humming ? 1 : 0)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height

            // faint pink light pooling under the branch while it plays
            if (root.energy > 0.03) {
                const g = ctx.createRadialGradient(w / 2, h * 0.75, 0, w / 2, h * 0.75, w * 0.38)
                g.addColorStop(0, String(root.pinkA(0.10 * Math.min(1, root.energy * 1.5))))
                g.addColorStop(1, String(root.pinkA(0)))
                ctx.fillStyle = g
                ctx.fillRect(0, 0, w, h)
            }

            // the twig: a slender arc, drawn thick-to-thin like a real branch
            ctx.lineCap = "round"
            const steps = 26
            for (let s = 0; s < steps; s++) {
                const t0 = s / steps, t1 = (s + 1) / steps
                ctx.beginPath()
                ctx.moveTo(w * (0.03 + 0.94 * t0), root.branchY(0.03 + 0.94 * t0))
                ctx.lineTo(w * (0.03 + 0.94 * t1), root.branchY(0.03 + 0.94 * t1))
                ctx.strokeStyle = String(root.twigA(0.9))
                ctx.lineWidth = 2.6 - 1.8 * t0
                ctx.stroke()
            }

            // blossom clusters, one per band
            const d = root.display
            for (let i = 0; i < root.bins; i++) {
                const t = 0.06 + 0.88 * i / (root.bins - 1)
                const bx = root.clusterX(i)
                const by = root.branchY(t)
                const bloom = d[i] || 0
                const lift = 10 + bloom * 10          // blossoms ride up as they open
                const r = 7 + bloom * 7

                // stem up from the twig
                ctx.beginPath()
                ctx.moveTo(bx, by)
                ctx.lineTo(bx, by - lift + 3)
                ctx.strokeStyle = String(root.twigA(0.8))
                ctx.lineWidth = 1
                ctx.stroke()

                ctx.save()
                ctx.translate(bx, by - lift)
                root.drawBlossom(ctx, r, bloom,
                                 String(root.pinkA(0.42 + bloom * 0.5)),
                                 String(root.creamA(0.5 + bloom * 0.4)))
                ctx.restore()
            }

            // the loose petals
            const ps = root.petals
            for (let k = 0; k < ps.length; k++) {
                const m = ps[k]
                drawPetal(ctx, m.x, m.y, m.r, m.rot, Math.min(1, m.life * 1.6))
            }
        }
        Connections {
            target: root.pal
            function onNeonChanged() { branch.requestPaint() }
            function onDimChanged() { branch.requestPaint() }
        }
    }
}
