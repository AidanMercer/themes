import QtQuick
import Quickshell.Io

// vinland: the aurora — curtains of light hanging in the sky above the hills,
// one per spectrum band, swaying up from a shallow arc. Ice at the base
// shading toward pale aurora green at the tips, brighter where the music is.
// At true silence the sky goes dark again and the canvas stops repainting.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color snow: pal.text
    readonly property color ice:  pal.neon
    readonly property real ui: pal.uiScale

    // a pale green the ice drifts toward at the curtain tips
    readonly property color veil: Qt.rgba(
        Math.min(1, ice.r * 0.72), Math.min(1, ice.g * 1.04), Math.min(1, ice.b * 0.86), 1)

    // the sky band: right of the clock, above thorfinn and the hills
    readonly property real bandL: root.width * 0.34
    readonly property real bandR: root.width * 0.90
    readonly property real baseY: root.height * 0.34
    readonly property real maxLen: root.height * 0.24

    readonly property int barCount: 28
    property var levels: []
    property var display: []
    property real loud: 0          // smoothed overall level
    property real auraT: 0         // 0 = dark sky, 1 = aurora up

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1500; easing.type: Easing.OutCubic }
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
            let moved = 0
            let sum = 0
            for (let i = 0; i < root.barCount; i++) {
                let t = root.levels[i] || 0
                if (t < 0.04) t = 0
                const nv = d[i] + (t - d[i]) * 0.30
                moved += Math.abs(nv - d[i])
                d[i] = nv
                sum += nv
            }
            root.loud = root.loud + (sum / root.barCount - root.loud) * 0.3

            // the sky lights up while something plays, settles dark when it stops
            const want = root.loud > 0.015 ? 1 : 0
            const prevA = root.auraT
            root.auraT = root.auraT + (want - root.auraT) * 0.06
            if (root.auraT < 0.004) root.auraT = 0

            if (moved > 0.002 || Math.abs(root.auraT - prevA) > 0.001)
                canvas.requestPaint()
            // cava sleeps at silence (sleep_timer) — wait for the aura clamp so no residual glow freezes
            else if (root.auraT === 0 && Date.now() - root.lastFrameMs > 2000)
                smooth.stop()
        }
    }

    Canvas {
        id: canvas
        x: root.bandL - 40
        y: root.baseY - root.maxLen - 60
        width: (root.bandR - root.bandL) + 80
        height: root.maxLen + 100

        Connections {
            target: root.pal
            function onNeonChanged() { canvas.requestPaint() }
            function onTextChanged() { canvas.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (root.auraT <= 0 || root.bootT <= 0) return

            const N = root.barCount
            const bandW = root.bandR - root.bandL
            const step = bandW / N
            const a = root.auraT * root.bootT
            const baseLocalY = height - 40

            for (let i = 0; i < N; i++) {
                const lv = root.display[i] || 0
                const t = i / (N - 1)
                // shallow arc: the curtain hangs a little higher mid-band
                const by = baseLocalY - Math.sin(t * Math.PI) * 26 * root.ui
                const cx = 40 + step * (i + 0.5)
                const len = (0.16 + 0.84 * lv) * root.maxLen * a
                const w = step * 0.72
                // each curtain leans a fixed, quiet amount — frozen wind
                const lean = Math.sin(i * 2.399) * step * 0.35

                const g = ctx.createLinearGradient(cx, by, cx + lean, by - len)
                const mix = 0.35 + 0.5 * t
                const r = root.ice.r + (root.veil.r - root.ice.r) * mix
                const gg = root.ice.g + (root.veil.g - root.ice.g) * mix
                const b = root.ice.b + (root.veil.b - root.ice.b) * mix
                g.addColorStop(0, Qt.rgba(r, gg, b, (0.05 + 0.24 * lv) * a))
                g.addColorStop(0.7, Qt.rgba(r, gg, b, (0.02 + 0.12 * lv) * a))
                g.addColorStop(1, Qt.rgba(r, gg, b, 0))
                ctx.fillStyle = g

                ctx.beginPath()
                ctx.moveTo(cx - w / 2, by)
                ctx.lineTo(cx + w / 2, by)
                ctx.lineTo(cx + w / 2 + lean, by - len)
                ctx.lineTo(cx - w / 2 + lean, by - len)
                ctx.closePath()
                ctx.fill()

                // a bright thread at the foot of the hot curtains
                if (lv > 0.5) {
                    ctx.fillStyle = Qt.rgba(root.snow.r, root.snow.g, root.snow.b,
                                            0.25 * (lv - 0.5) / 0.5 * a)
                    ctx.fillRect(cx - w / 2, by - 1.5, w, 1.5)
                }
            }

            // the faint glow line the curtains hang from
            ctx.strokeStyle = Qt.rgba(root.ice.r, root.ice.g, root.ice.b,
                                      (0.06 + 0.16 * root.loud) * a)
            ctx.lineWidth = 1
            ctx.beginPath()
            for (let i = 0; i <= 40; i++) {
                const t = i / 40
                const px = 40 + bandW * t
                const py = baseLocalY - Math.sin(t * Math.PI) * 26 * root.ui
                if (i === 0) ctx.moveTo(px, py)
                else ctx.lineTo(px, py)
            }
            ctx.stroke()
        }
    }
}
