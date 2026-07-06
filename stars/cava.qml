import QtQuick
import Quickshell.Io

// stars: a strand of starlight. One thin luminous line low over the platform
// that ripples with the music — amber core, soft glow, and tiny star sparks
// where a band peaks. At true silence it fades out completely and stops
// painting; the platform (and the cat) stay unobstructed. Runs its own cava
// against cava.conf next door; click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color amber: pal.neon
    readonly property color coral: pal.cyan
    readonly property color slate: pal.dim
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function coralA(a) { return Qt.rgba(coral.r, coral.g, coral.b, a) }

    readonly property int bins: 24

    property var levels: []       // raw cava bins 0..1
    property var display: []      // smoothed values the strand binds to
    property bool humming: false  // false = true silence, nothing on screen

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

    Component.onCompleted: {
        const z = []
        for (let i = 0; i < bins; i++) z.push(0)
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

    function parseFrame(line) {
        const parts = line.split(";")
        const out = []
        for (let i = 0; i < parts.length; i++) {
            if (parts[i] === "") continue
            out.push(Math.min(1, parseInt(parts[i]) / 1000))
        }
        if (out.length) root.levels = out
    }

    // smoothing pump — repaints only while something is moving; at true
    // silence `humming` drops, the strand fades, and the timer's work is a
    // cheap no-op that stops dirtying the scene.
    property int stillFrames: 0
    Timer {
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            const d = root.display
            const l = root.levels
            let moved = 0
            for (let i = 0; i < root.bins; i++) {
                let t = l[i] || 0
                if (t < 0.04) t = 0
                const nv = d[i] + (t - d[i]) * 0.4
                moved += Math.abs(nv - d[i])
                d[i] = nv
            }
            if (moved > 0.003) {
                root.display = d
                root.stillFrames = 0
                root.humming = true
                strand.requestPaint()
            } else if (root.humming) {
                root.stillFrames++
                if (root.stillFrames > 45) {   // ~1.5s of stillness → lights out
                    for (let i = 0; i < root.bins; i++) d[i] = 0
                    root.display = d
                    root.humming = false
                    strand.requestPaint()
                }
            }
        }
    }

    // ── the strand ──────────────────────────────────────────────────────────
    Canvas {
        id: strand
        width: Math.round(root.width * 0.46)
        height: 130
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.10)
        scale: pal.uiScale
        transformOrigin: Item.Bottom

        opacity: root.bootT * (root.humming ? 1 : 0)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const n = root.bins
            const d = root.display
            const w = width, h = height
            const inset = 10
            const baseY = h - 14
            const rise = h - 40

            // curve points, softly pinched at the ends so the strand tapers
            const pts = []
            for (let i = 0; i < n; i++) {
                const f = i / (n - 1)
                const taper = Math.sin(Math.PI * f) * 0.35 + 0.65
                const v = (d[i] || 0) * taper
                pts.push({ x: inset + f * (w - inset * 2), y: baseY - v * rise, v: v })
            }

            function trace() {
                ctx.beginPath()
                ctx.moveTo(pts[0].x, pts[0].y)
                for (let i = 1; i < n - 1; i++) {
                    const mx = (pts[i].x + pts[i + 1].x) / 2
                    const my = (pts[i].y + pts[i + 1].y) / 2
                    ctx.quadraticCurveTo(pts[i].x, pts[i].y, mx, my)
                }
                ctx.lineTo(pts[n - 1].x, pts[n - 1].y)
            }

            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            // wide soft glow, then the bright core
            ctx.strokeStyle = root.amberA(0.14)
            ctx.lineWidth = 6
            trace(); ctx.stroke()
            ctx.strokeStyle = root.amberA(0.85)
            ctx.lineWidth = 1.6
            trace(); ctx.stroke()

            // star sparks where a band sings
            for (let i = 0; i < n; i++) {
                const p = pts[i]
                if (p.v < 0.5) continue
                const s = (p.v - 0.5) * 2          // 0..1 above threshold
                const r = 1.2 + s * 1.6
                ctx.fillStyle = s > 0.6 ? root.coralA(0.95) : root.amberA(0.6 + s * 0.4)
                ctx.beginPath()
                ctx.arc(p.x, p.y, r, 0, Math.PI * 2)
                ctx.fill()
                // a tiny cross flare on the strongest peaks
                if (s > 0.55) {
                    ctx.strokeStyle = root.coralA(0.5 * s)
                    ctx.lineWidth = 0.8
                    ctx.beginPath()
                    ctx.moveTo(p.x - r * 2.6, p.y); ctx.lineTo(p.x + r * 2.6, p.y)
                    ctx.moveTo(p.x, p.y - r * 2.6); ctx.lineTo(p.x, p.y + r * 2.6)
                    ctx.stroke()
                }
            }
        }
        Connections {
            target: root.pal
            function onNeonChanged() { strand.requestPaint() }
            function onCyanChanged() { strand.requestPaint() }
        }
    }
}
