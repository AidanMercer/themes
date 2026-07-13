import QtQuick
import QtQuick.Effects
import Quickshell.Io

// Cyberpunk: Edgerunners center visualizer for the "moon" wallpaper — "reactor".
//
// Loaded by the quickshell archlogo wrapper while this wallpaper is showing, in
// place of the default Arch triangle. Self-contained (lives outside the repo's
// module tree), runs its own cava and ships its own cava.conf next door.
//
// A cyberdeck reactor core: 40 cava bars mirrored to a full ring (left/right
// symmetric) burst radially out of a neon "er" glyph, framed by a static HUD tick ring
// and two arc segments that rotate — but only while audio is actually playing,
// so a silent desktop costs nothing. Neon yellow with a steady, subtle
// cyan/magenta chromatic fringe.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // pushed by the loader after mount: lock/fullscreen cover + mpris playing
    property bool occluded: false
    property bool playing: true
    readonly property bool feedOn: playing && !occluded
    readonly property color neon:    pal.neon
    readonly property color cyan:    pal.cyan
    readonly property color magenta: pal.magenta

    readonly property int barCount: 40
    property var levels: []
    property var display: []

    // ring radius and the loudest outward bar push (px)
    readonly property real base: 84
    readonly property real barMax: 92

    property real spin: 0                         // arc rotation, advanced only on audio

    // steady, subtle chromatic fringe — no glitch jumps.
    readonly property real gx: 1.6

    // boot-in: arcs sweep into place while the stage fades/scales up.
    // bootT drives bindings so pal.uiScale stays live.
    property real bootT: 0
    onSpinChanged: canvas.requestPaint()

    ParallelAnimation {
        id: bootAnim
        NumberAnimation { target: root; property: "bootT"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "spin"; from: 285; to: 360; duration: 700; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: {
        const z = []
        for (let i = 0; i < barCount; i++) z.push(0)
        display = z
        bootAnim.start()
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
                if (t < 0.05) t = 0
                const nv = d[i] + (t - d[i]) * 0.4
                moved += Math.abs(nv - d[i])
                d[i] = nv
                if (nv > peak) peak = nv
            }
            if (moved > 0.002) {
                root.display = d
                canvas.requestPaint()
            }
            // advance the rotating arcs whenever there's audible signal *anywhere*
            // in the spectrum (peak, not just bass), independent of the move gate so
            // a steady passage still spins. Frozen only at true silence.
            if (peak > 0.03) {
                root.spin = (root.spin + 0.9) % 360
                canvas.requestPaint()
            }
            // cava sleeps at silence (sleep_timer) — nothing left to ease; parseFrame rearms
            else if (moved <= 0.002 && Date.now() - root.lastFrameMs > 2000)
                smooth.stop()
        }
    }

    readonly property real pulse: {
        const d = display
        if (!d.length) return 0
        return (d[0] + d[1] + d[2]) / 3
    }

    Item {
        id: stage
        width: 480
        height: 480
        anchors.centerIn: parent
        opacity: root.bootT
        scale: pal.uiScale * (0.92 + 0.08 * root.bootT)

        // GPU glow: a blurred neon copy of the crisp core below.
        MultiEffect {
            source: canvas
            anchors.fill: canvas
            autoPaddingEnabled: true
            blurEnabled: true
            blur: 1.0
            blurMax: 32
            colorization: 1.0
            colorizationColor: root.neon
            brightness: 0.18
            opacity: 0.8
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            renderStrategy: Canvas.Threaded

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const cx = width / 2, cy = height / 2
                const d = root.display, n = root.barCount
                const gx = root.gx
                const base = root.base, barMax = root.barMax
                const spin = root.spin * Math.PI / 180
                const ptsN = 80                     // 40 bars mirrored around the ring

                function spectrum(ox, oy, color, lw, alpha) {
                    ctx.globalAlpha = alpha
                    ctx.strokeStyle = color
                    ctx.lineWidth = lw
                    ctx.lineCap = "round"
                    for (let k = 0; k < ptsN; k++) {
                        const half = k < 40 ? k : 79 - k         // mirror → symmetric
                        const lvl = d[half] || 0
                        const ang = (k / ptsN) * Math.PI * 2 - Math.PI / 2
                        const ca = Math.cos(ang), sa = Math.sin(ang)
                        const r0 = base + 4, r1 = base + 4 + barMax * lvl
                        ctx.beginPath()
                        ctx.moveTo(cx + ca * r0 + ox, cy + sa * r0 + oy)
                        ctx.lineTo(cx + ca * r1 + ox, cy + sa * r1 + oy)
                        ctx.stroke()
                    }
                    ctx.globalAlpha = 1
                }

                function ring(rad, ox, oy, color, lw, alpha) {
                    ctx.globalAlpha = alpha
                    ctx.strokeStyle = color
                    ctx.lineWidth = lw
                    ctx.beginPath()
                    ctx.arc(cx + ox, cy + oy, rad, 0, Math.PI * 2)
                    ctx.stroke()
                    ctx.globalAlpha = 1
                }

                // static HUD tick ring (cyan): long ticks every 90°, short between
                const tickR = base + barMax + 18
                ctx.strokeStyle = root.cyan
                ctx.lineWidth = 2
                ctx.globalAlpha = 0.7
                for (let i = 0; i < 24; i++) {
                    const a = i / 24 * Math.PI * 2
                    const long = (i % 6 === 0)
                    const r1 = tickR + (long ? 13 : 6)
                    ctx.beginPath()
                    ctx.moveTo(cx + Math.cos(a) * tickR, cy + Math.sin(a) * tickR)
                    ctx.lineTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1)
                    ctx.stroke()
                }
                ctx.globalAlpha = 1

                // two opposed arc segments that rotate while audio plays
                const arcR = base + barMax + 10
                ctx.strokeStyle = root.neon
                ctx.lineWidth = 3
                ctx.lineCap = "butt"
                ctx.globalAlpha = 0.9
                ctx.beginPath(); ctx.arc(cx, cy, arcR, spin, spin + Math.PI * 0.3); ctx.stroke()
                ctx.beginPath(); ctx.arc(cx, cy, arcR, spin + Math.PI, spin + Math.PI + Math.PI * 0.3); ctx.stroke()
                ctx.globalAlpha = 1

                // radial spectrum with chromatic ghosts, crisp neon on top
                spectrum(gx, gx * 0.5, root.magenta, 2.4, 0.8)
                spectrum(-gx, -gx * 0.5, root.cyan, 2.4, 0.8)
                spectrum(0, 0, root.neon, 3.0, 1.0)

                // core ring
                ring(base, gx, gx * 0.5, root.magenta, 2.0, 0.7)
                ring(base, -gx, -gx * 0.5, root.cyan, 2.0, 0.7)
                ring(base, 0, 0, root.neon, 2.4, 1.0)
            }
        }

        // bass-pulsing core glyph (the "er" mark) — three chromatic-split copies,
        // yellow on top with blue/pink ghosts, plus a soft neon glow. Same RGB-split
        // treatment the spectrum and rings use. Replaces the old core hexagon.
        Item {
            id: glyph
            anchors.centerIn: parent
            readonly property real h: 80 + root.pulse * 50
            readonly property real aspect: 830 / 1692
            width: h * aspect
            height: h

            Image {
                id: glyphSrc
                anchors.fill: parent
                source: Qt.resolvedUrl("reactor.png")
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                visible: false
            }

            // soft neon glow behind
            MultiEffect {
                source: glyphSrc
                anchors.fill: glyphSrc
                autoPaddingEnabled: true
                blurEnabled: true
                blur: 1.0
                blurMax: 28
                colorization: 1.0
                colorizationColor: root.neon
                brightness: 0.15
                opacity: 0.85
            }

            // pink ghost
            MultiEffect {
                source: glyphSrc
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: root.gx
                anchors.verticalCenterOffset: root.gx * 0.5
                width: glyphSrc.width
                height: glyphSrc.height
                colorization: 1.0
                colorizationColor: root.magenta
                opacity: 0.8
            }
            // blue ghost
            MultiEffect {
                source: glyphSrc
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -root.gx
                anchors.verticalCenterOffset: -root.gx * 0.5
                width: glyphSrc.width
                height: glyphSrc.height
                colorization: 1.0
                colorizationColor: root.cyan
                opacity: 0.8
            }
            // crisp yellow core
            MultiEffect {
                source: glyphSrc
                anchors.fill: glyphSrc
                colorization: 1.0
                colorizationColor: root.neon
            }
        }
    }
}
