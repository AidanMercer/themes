import QtQuick
import Quickshell.Io

// avalon: the bloom — a white flower whose twelve petals are the spectrum.
// Lows at the crown, highs at the foot, mirrored so it stays symmetric. The
// gold heart breathes with the bass, hard onsets let loose petals drift off,
// and at true silence it settles into a closed bud and stops repainting.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // pushed by the loader after mount: lock/fullscreen cover + mpris playing
    property bool occluded: false
    property bool playing: true
    readonly property bool feedOn: playing && !occluded
    readonly property color ivory: pal.text
    readonly property color leaf:  pal.neon
    readonly property color gold:  pal.cyan
    readonly property real ui: pal.uiScale

    // sits at the pond's edge, lower left
    readonly property real cx: root.width * 0.20
    readonly property real cy: root.height * 0.72
    readonly property real coreR: 10 * ui
    readonly property real baseLen: 34 * ui        // closed-bud petal length
    readonly property real push: 58 * ui           // loudest petal stretch

    readonly property int barCount: 24
    readonly property int petalCount: 12
    property var levels: []
    property var display: []

    property real bass: 0
    property real _prevBass: 0
    property var loose: []                          // {x,y,vx,vy,a,spin,life}
    property double _lastShed: 0

    property real bootT: 0
    NumberAnimation on bootT {
        running: true; from: 0; to: 1; duration: 1500; easing.type: Easing.OutCubic
    }
    onBootTChanged: canvas.requestPaint()

    Component.onCompleted: {
        const z = []
        for (let i = 0; i < petalCount; i++) z.push(0)
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

    // petal i (0 = crown, clockwise): mirrored bins so both sides match
    function petalLevel(i) {
        const l = root.levels
        const k = (i <= root.petalCount / 2) ? i : root.petalCount - i
        const b = Math.round(k * (root.barCount - 2) / (root.petalCount / 2))
        return ((l[b] || 0) + (l[b + 1] || 0)) / 2
    }

    Timer {
        id: smooth
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            const d = root.display
            let moved = 0
            let peak = 0
            for (let i = 0; i < root.petalCount; i++) {
                let t = root.petalLevel(i)
                if (t < 0.04) t = 0
                const nv = d[i] + (t - d[i]) * 0.34
                moved += Math.abs(nv - d[i])
                d[i] = nv
                if (nv > peak) peak = nv
            }

            const b = (d[0] + d[1] + d[root.petalCount - 1]) / 3
            root._prevBass = root.bass
            root.bass = root.bass + (b - root.bass) * 0.5

            // hard onset -> shed a petal or two
            const now = Date.now()
            if (root.bass > 0.45 && root.bass - root._prevBass > 0.10
                    && now - root._lastShed > 260 && root.bootT >= 1) {
                root._lastShed = now
                const n = 1 + Math.floor(Math.random() * 2)
                for (let k = 0; k < n && root.loose.length < 14; k++) {
                    const a = Math.random() * Math.PI * 2
                    const sp = (1.2 + Math.random() * 2.2) * root.ui
                    root.loose.push({
                        x: Math.cos(a) * root.baseLen, y: Math.sin(a) * root.baseLen,
                        vx: Math.cos(a) * sp * 0.5, vy: Math.abs(Math.sin(a)) * sp * 0.4 + 0.5,
                        a: a, spin: (Math.random() - 0.5) * 0.06,
                        life: 1
                    })
                }
            }

            let looseAlive = false
            if (root.loose.length) {
                const ls = root.loose
                for (let k = ls.length - 1; k >= 0; k--) {
                    const p = ls[k]
                    p.x += p.vx; p.y += p.vy
                    p.vx = (p.vx + 0.02) * 0.97      // a hint of breeze
                    p.vy = p.vy * 0.985
                    p.a += p.spin
                    p.life -= 0.012
                    if (p.life <= 0) ls.splice(k, 1)
                }
                looseAlive = ls.length > 0
            }

            if (moved > 0.002 || peak > 0.03 || looseAlive)
                canvas.requestPaint()
            // cava sleeps at silence (sleep_timer) — nothing left to ease; parseFrame rearms
            else if (Date.now() - root.lastFrameMs > 2000)
                smooth.stop()
        }
    }

    Canvas {
        id: canvas
        readonly property real box: root.baseLen + root.push + 90 * root.ui
        x: root.cx - box
        y: root.cy - box
        width: box * 2
        height: box * 2

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const c = box
            const N = root.petalCount

            for (let i = 0; i < N; i++) {
                // unfurl one by one on boot
                const open = Math.min(1, Math.max(0, root.bootT * 1.8 - i * 0.07))
                if (open <= 0) continue
                const lv = root.display[i] || 0
                const a = -Math.PI / 2 + i * Math.PI * 2 / N
                const L = (root.baseLen + root.push * lv) * open
                const W = (root.baseLen * 0.34) * (0.75 + 0.7 * lv) * open

                const tipX = c + Math.cos(a) * (root.coreR + L)
                const tipY = c + Math.sin(a) * (root.coreR + L)
                const bx = c + Math.cos(a) * root.coreR
                const by = c + Math.sin(a) * root.coreR
                const mx = c + Math.cos(a) * (root.coreR + L * 0.5)
                const my = c + Math.sin(a) * (root.coreR + L * 0.5)
                const px = -Math.sin(a), py = Math.cos(a)

                ctx.beginPath()
                ctx.moveTo(bx, by)
                ctx.quadraticCurveTo(mx + px * W, my + py * W, tipX, tipY)
                ctx.quadraticCurveTo(mx - px * W, my - py * W, bx, by)
                ctx.fillStyle = Qt.rgba(root.ivory.r, root.ivory.g, root.ivory.b,
                                        0.30 + 0.55 * lv)
                ctx.fill()
                // a whisper of moss-light along the hot petal's rim
                if (lv > 0.55) {
                    ctx.strokeStyle = Qt.rgba(root.leaf.r, root.leaf.g, root.leaf.b,
                                              0.5 * (lv - 0.55) / 0.45)
                    ctx.lineWidth = 1
                    ctx.stroke()
                }
            }

            // gold heart, breathing with the bass
            const hr = root.coreR * (1 + 0.35 * root.bass) * Math.min(1, root.bootT * 2)
            ctx.beginPath()
            ctx.arc(c, c, hr, 0, Math.PI * 2)
            ctx.fillStyle = Qt.rgba(root.gold.r, root.gold.g, root.gold.b, 0.85)
            ctx.fill()
            ctx.beginPath()
            ctx.arc(c, c, hr * 1.9, 0, Math.PI * 2)
            ctx.strokeStyle = Qt.rgba(root.gold.r, root.gold.g, root.gold.b,
                                      0.10 + 0.20 * root.bass)
            ctx.lineWidth = 6 * root.ui
            ctx.stroke()

            // loose petals adrift
            for (const p of root.loose) {
                ctx.save()
                ctx.translate(c + p.x, c + p.y)
                ctx.rotate(p.a)
                ctx.scale(3.2 * root.ui, 5.4 * root.ui)
                ctx.beginPath()
                ctx.arc(0, 0, 1, 0, Math.PI * 2)
                ctx.restore()
                ctx.fillStyle = Qt.rgba(root.ivory.r, root.ivory.g, root.ivory.b, 0.55 * p.life)
                ctx.fill()
            }
        }
    }
}
