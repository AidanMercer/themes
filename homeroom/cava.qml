import QtQuick
import Quickshell.Io
import "chalk.js" as Chalk

// homeroom: somebody is sketching the song. While music plays, one
// continuous hand-jittered chalk line rides across the locker band, its
// shape the live spectrum; a slower smudge-ghost of the line decays behind
// it like chalk that hasn't been wiped yet, and a stub of chalk rides the
// leading tip of the stroke. At silence the sketch is erased (the line
// settles flat and fades) and the whole pipeline parks: the smoothing timer
// stops itself, and the cava process is gated off. Click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // pushed by the loader after mount: lock/fullscreen cover + mpris playing
    property bool occluded: false
    property bool playing: true
    readonly property bool feedOn: playing && !occluded

    readonly property color chalk: pal.text
    readonly property color pink: pal.magenta
    readonly property color slate: pal.dim
    function chalkA(a) { return Qt.rgba(chalk.r, chalk.g, chalk.b, a) }

    readonly property int bins: 44

    property var levels: []       // raw cava bins 0..1
    property var display: []      // smoothed values
    property var ghost: []        // the un-wiped chalk behind the line
    property bool humming: false

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }

    Component.onCompleted: {
        const d = [], g = []
        for (let i = 0; i < bins; i++) { d.push(0); g.push(0) }
        display = d
        ghost = g
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

    // smoothing + the ghost's slow decay — stops itself once frames go stale
    // and the sketch has been wiped, so silence costs nothing.
    Timer {
        id: tick
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            const d = root.display, l = root.levels, g = root.ghost
            let loud = 0, settled = true
            for (let i = 0; i < root.bins; i++) {
                let t = l[i] || 0
                if (t < 0.04) t = 0
                d[i] = d[i] + (t - d[i]) * 0.38
                if (d[i] < 0.004) d[i] = 0
                // the un-wiped chalk: holds the outline, wipes away slowly
                g[i] = Math.max(g[i] * 0.985 - 0.001, d[i])
                if (g[i] < 0.004) g[i] = 0
                if (d[i] > loud) loud = d[i]
                if (d[i] > 0.003 || g[i] > 0.003) settled = false
            }

            const now = Date.now()
            const audioActive = loud > 0.05
            if (audioActive) root.lastFrameMs = now

            const nowHumming = audioActive || !settled
            if (nowHumming !== root.humming) root.humming = nowHumming

            sketch.requestPaint()
            if (!nowHumming && now - root.lastFrameMs > 2000) tick.stop()   // cava asleep
        }
    }

    // ── the sketch ──────────────────────────────────────────────────────────
    Canvas {
        id: sketch
        width: Math.round(root.width * 0.46)
        height: Math.round(root.height * 0.17)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.06)
        scale: pal.uiScale
        transformOrigin: Item.Bottom

        opacity: root.bootT * (root.humming ? 1 : 0)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }

        // the hand's slow drift: reseed the jitter every few frames so the
        // stroke is alive without shimmering
        property int frameNo: 0

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            const base = h - 8
            const amp = h * 0.78
            frameNo++
            const seed = 700 + (frameNo >> 3)

            const d = root.display, g = root.ghost
            function pts(arr, lift) {
                const out = []
                const n = root.bins
                for (let i = 0; i < n; i++) {
                    const x = 6 + (w - 12) * i / (n - 1)
                    out.push([x, base - Math.min(1, arr[i] * lift) * amp])
                }
                return out
            }

            // the un-wiped chalk behind the line — one soft pass, no grain
            Chalk.strokePath(ctx, pts(g, 0.95), {
                seed: 5, color: String(root.chalkA(1)), alpha: 0.14,
                width: 5, ghost: false, dust: 0
            })
            // the live stroke, hand-jittered chalk
            const live = pts(d, 1)
            Chalk.strokePath(ctx, live, {
                seed: seed, color: String(root.chalkA(1)), alpha: 0.85,
                width: 2.8, dust: 0.05
            })

            // the chalk stub riding the leading tip of the stroke
            const tip = live[live.length - 1]
            ctx.save()
            ctx.translate(tip[0], tip[1])
            ctx.rotate(-0.6)
            ctx.globalAlpha = 0.9
            ctx.fillStyle = String(root.chalkA(1))
            ctx.fillRect(0, -1.5, 11, 3.5)
            ctx.globalAlpha = 0.5
            ctx.fillStyle = String(Qt.rgba(root.pink.r, root.pink.g, root.pink.b, 1))
            ctx.fillRect(8, -1.5, 3, 3.5)
            ctx.restore()
        }
    }
}
