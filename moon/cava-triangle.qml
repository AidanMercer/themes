import QtQuick
import QtQuick.Effects
import Quickshell.Io

// Cyberpunk: Edgerunners center visualizer for the "moon" wallpaper.
//
// Loaded by the quickshell archlogo wrapper while this wallpaper is showing, in
// place of the default Arch triangle. Self-contained (lives outside the repo's
// module tree), so it runs its own cava and ships its own cava.conf next door.
//
// Same bones as the Arch visualizer — `cava` raw-ascii frames bent around an
// equilateral triangle — restyled as a cyberdeck readout: neon-yellow outline
// with cyan/magenta chromatic ghosts that split on a glitch burst, a GPU glow,
// HUD vertex ticks, and a bass-pulsing core diamond where the logo used to be.
Item {
    id: root
    anchors.fill: parent

    readonly property color neon:    "#fcee0a"
    readonly property color cyan:    "#00e5ff"
    readonly property color magenta: "#ff2e6c"

    readonly property int barCount: 40
    property var levels: []
    property var display: []

    readonly property real triR: 135
    readonly property real amp: 26

    // chromatic split: calm baseline, slammed wide on a glitch burst (matches the
    // clock). gx drives the cyan/magenta ghost offset and forces a repaint.
    property real gx: 2
    onGxChanged: canvas.requestPaint()

    Timer {
        id: glitchTimer
        interval: 2600
        repeat: true
        running: true
        onTriggered: {
            glitchBurst.restart()
            interval = 1500 + Math.floor(Math.random() * 3600)
        }
    }
    SequentialAnimation {
        id: glitchBurst
        NumberAnimation { target: root; property: "gx"; to: 9; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "gx"; to: 2; duration: 300; easing.type: Easing.OutQuad }
    }

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

    function parseFrame(line) {
        const parts = line.split(";")
        const out = []
        for (let i = 0; i < parts.length; i++) {
            if (parts[i] === "") continue
            out.push(Math.min(1, parseInt(parts[i]) / 1000))
        }
        if (out.length) root.levels = out
    }

    Timer {
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            const d = root.display
            const l = root.levels
            let moved = 0
            for (let i = 0; i < root.barCount; i++) {
                let t = l[i] || 0
                if (t < 0.05) t = 0
                const nv = d[i] + (t - d[i]) * 0.4
                moved += Math.abs(nv - d[i])
                d[i] = nv
            }
            if (moved > 0.002) {
                root.display = d
                canvas.requestPaint()
            }
        }
    }

    readonly property real pulse: {
        const d = display
        if (!d.length) return 0
        return (d[0] + d[1] + d[2]) / 3
    }

    Item {
        id: stage
        width: 460
        height: 460
        anchors.centerIn: parent

        // GPU glow: a blurred neon copy of the crisp outline below.
        MultiEffect {
            source: canvas
            anchors.fill: canvas
            autoPaddingEnabled: true
            blurEnabled: true
            blur: 1.0
            blurMax: 30
            colorization: 1.0
            colorizationColor: root.neon
            brightness: 0.18
            opacity: 0.8
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            renderStrategy: Canvas.Threaded

            // build the reactive triangle's point list once per frame
            function buildPts(cx, cy) {
                const R = root.triR, amp = root.amp
                const d = root.display, n = root.barCount
                const verts = [
                    { x: cx,                 y: cy - R },
                    { x: cx - R * 0.8660254, y: cy + R * 0.5 },
                    { x: cx + R * 0.8660254, y: cy + R * 0.5 }
                ]
                const pts = []
                for (let e = 0; e < 3; e++) {
                    const P = verts[e], Q = verts[(e + 1) % 3]
                    const dx = Q.x - P.x, dy = Q.y - P.y
                    let nx = dy, ny = -dx
                    const len = Math.hypot(nx, ny)
                    nx /= len; ny /= len
                    const mx = (P.x + Q.x) / 2 - cx, my = (P.y + Q.y) / 2 - cy
                    if (nx * mx + ny * my < 0) { nx = -nx; ny = -ny }
                    for (let s = 0; s < n; s++) {
                        const p = s / n
                        const idx = Math.min(n - 1, Math.floor(p * (n - 1)))
                        const win = Math.sin(p * Math.PI)
                        const push = amp * (d[idx] || 0) * win
                        pts.push({ x: P.x + dx * p + nx * push,
                                   y: P.y + dy * p + ny * push })
                    }
                }
                return { pts: pts, verts: verts }
            }

            function strokeTri(ctx, pts, ox, oy, color, lw, alpha) {
                ctx.globalAlpha = alpha
                ctx.beginPath()
                ctx.moveTo(pts[0].x + ox, pts[0].y + oy)
                for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x + ox, pts[i].y + oy)
                ctx.closePath()
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                ctx.lineWidth = lw
                ctx.strokeStyle = color
                ctx.stroke()
                ctx.globalAlpha = 1
            }

            function diamond(ctx, cx, cy, r, ox, oy, color, alpha) {
                ctx.globalAlpha = alpha
                ctx.beginPath()
                ctx.moveTo(cx + ox, cy - r + oy)
                ctx.lineTo(cx + r + ox, cy + oy)
                ctx.lineTo(cx + ox, cy + r + oy)
                ctx.lineTo(cx - r + ox, cy + oy)
                ctx.closePath()
                ctx.fillStyle = color
                ctx.fill()
                ctx.globalAlpha = 1
            }

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const cx = width / 2, cy = height / 2
                const b = buildPts(cx, cy)
                const pts = b.pts, verts = b.verts
                const gx = root.gx

                // chromatic ghosts, then the crisp neon outline on top
                strokeTri(ctx, pts,  gx,  gx * 0.5, root.magenta, 2.0, 0.85)
                strokeTri(ctx, pts, -gx, -gx * 0.5, root.cyan,    2.0, 0.85)
                strokeTri(ctx, pts,   0,        0,  root.neon,    2.6, 1.0)

                // HUD ticks at the three vertices
                for (let e = 0; e < 3; e++) {
                    ctx.fillStyle = root.cyan
                    ctx.fillRect(verts[e].x - 3, verts[e].y - 3, 6, 6)
                }

                // bass-pulsing core diamond where the logo used to be
                const cr = 13 + root.pulse * 22
                diamond(ctx, cx, cy, cr,  gx,  gx * 0.5, root.magenta, 0.8)
                diamond(ctx, cx, cy, cr, -gx, -gx * 0.5, root.cyan,    0.8)
                diamond(ctx, cx, cy, cr,   0,        0,  root.neon,    1.0)
            }
        }
    }
}
