import QtQuick
import Quickshell.Io

// pines: the barograph. Music is a storm front, and the station records it
// the only way a lookout can — in ink, on drum paper. When sound plays, a
// strip of ruled paper condenses over the black pines and a pen arm rides
// the mix: the trace scrolls right-to-left as the drum turns (hour lines
// ride along with it), fresh ink glows kerosene-warm at the nib and cools
// to fog silver as it ages leftward, and hard gusts leave small ember tick
// marks on the top rule. At silence the pen settles, the paper dissolves
// back into fog, the canvas stops painting, and the cava process itself is
// parked (feed gate below). Click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // pushed by the loader after mount: lock/fullscreen cover + mpris playing
    property bool occluded: false
    property bool playing: true
    readonly property bool feedOn: playing && !occluded
    // when the feed gates off mid-song the last frame would sit in `levels`
    // forever, holding the mix above the sleep threshold — flush it so the
    // pen settles and the tick timer can stop
    onFeedOnChanged: if (!feedOn) levels = []

    readonly property color lamp: pal.neon
    readonly property color fogSilver: pal.cyan
    readonly property color ember: pal.magenta
    readonly property color slate: pal.dim
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    function colA(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    readonly property int bins: 24
    readonly property int trace: 168        // samples across the drum

    property var levels: []                 // raw cava bins 0..1
    property var inkBuf: []                 // scrolled trace values 0..1
    property var gustBuf: []                // gust flags riding the trace
    property real penV: 0                   // damped pen position
    property int drumStep: 0                // hour-line scroll phase
    property bool humming: false
    property double lastFrameMs: 0

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

    Component.onCompleted: {
        const b = [], g = []
        for (let i = 0; i < trace; i++) { b.push(0); g.push(false) }
        inkBuf = b
        gustBuf = g
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

    function parseFrame(line) {
        const parts = line.split(";")
        const out = []
        for (let i = 0; i < parts.length; i++) {
            if (parts[i] === "") continue
            out.push(Math.min(1, parseInt(parts[i]) / 1000))
        }
        if (out.length === root.bins) {   // one full frame — must match cava.conf `bars`
            root.levels = out
            root.lastFrameMs = Date.now()
            if (!tick.running) tick.start()
        }
    }

    // drum physics — the pen damps toward the mix, the paper scrolls one
    // sample per tick. Stops itself once frames go stale and the pen has
    // settled, clearing the drum so silence costs nothing.
    Timer {
        id: tick
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            // the storm level: bass-weighted mix of the bins
            const l = root.levels
            let sum = 0, wsum = 0
            for (let i = 0; i < l.length; i++) {
                const w = i < l.length * 0.4 ? 1.6 : 1.0
                sum += (l[i] || 0) * w
                wsum += w
            }
            let target = wsum > 0 ? Math.min(1, (sum / wsum) * 1.7) : 0
            if (target < 0.03) target = 0

            // damped pen — overshoots a touch, settles, never snaps
            root.penV = root.penV + (target - root.penV) * 0.38
            if (root.penV < 0.004) root.penV = 0

            // the drum turns: shift the trace, lay fresh ink at the right
            const b = root.inkBuf, g = root.gustBuf
            b.shift(); b.push(root.penV)
            g.shift(); g.push(root.penV > 0.82)
            root.drumStep = (root.drumStep + 1) % 42

            const now = Date.now()
            const audioActive = target > 0.04
            if (audioActive) root.lastFrameMs = now

            const nowHumming = audioActive || root.penV > 0.01
            if (nowHumming !== root.humming) root.humming = nowHumming

            drum.requestPaint()
            if (!nowHumming && now - root.lastFrameMs > 2000) {
                // wipe the drum and sleep — the paper has already dissolved
                for (let i = 0; i < root.trace; i++) { b[i] = 0; g[i] = false }
                drum.requestPaint()
                tick.stop()
            }
        }
    }

    // ── the drum paper ──────────────────────────────────────────────────────
    Item {
        id: sheet
        width: Math.round(root.width * 0.44)
        height: Math.round(root.height * 0.15)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.07)
        scale: pal.uiScale
        transformOrigin: Item.Bottom

        opacity: root.bootT * (root.humming ? 1 : 0)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }

        // the paper itself: a whisper of cold glass with hairline edges
        Rectangle {
            anchors.fill: parent
            color: root.colA(root.glass, 0.42)
            border.width: 1
            border.color: root.colA(root.slate, 0.7)
        }

        // the sheet's heading, in the station's hand
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.top: parent.top
            anchors.topMargin: 4
            text: "BAROGRAPH — MIX TRACE"
            color: root.colA(root.fogSilver, 0.75)
            font.family: root.serif
            font.pixelSize: 10
            font.letterSpacing: 3
        }

        Canvas {
            id: drum
            anchors.fill: parent
            anchors.margins: 1
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height
                const base = h * 0.82          // the trace's rest line
                const amp = h * 0.60           // full-storm swing
                const step = w / (root.trace - 1)

                // ruled paper: three faint horizontal rules
                ctx.lineWidth = 1
                ctx.strokeStyle = String(root.colA(root.slate, 0.35))
                for (let r = 1; r <= 3; r++) {
                    const y = base - amp * r / 3
                    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke()
                }
                ctx.strokeStyle = String(root.colA(root.slate, 0.55))
                ctx.beginPath(); ctx.moveTo(0, base); ctx.lineTo(w, base); ctx.stroke()

                // hour lines, riding the drum leftward
                ctx.strokeStyle = String(root.colA(root.slate, 0.4))
                for (let x = w - root.drumStep * step; x > 0; x -= 42 * step) {
                    ctx.beginPath(); ctx.moveTo(x, h * 0.12); ctx.lineTo(x, base); ctx.stroke()
                }

                // the ink: aged silver behind, warming toward the nib
                const b = root.inkBuf
                ctx.lineWidth = 1.4
                ctx.lineJoin = "round"
                const warm = 22                 // samples of fresh ink
                // aged trace
                ctx.beginPath()
                ctx.moveTo(0, base - b[0] * amp)
                for (let i = 1; i < root.trace - warm + 1; i++)
                    ctx.lineTo(i * step, base - b[i] * amp)
                ctx.strokeStyle = String(root.colA(root.fogSilver, 0.55))
                ctx.stroke()
                // fresh ink
                ctx.beginPath()
                ctx.moveTo((root.trace - warm) * step, base - b[root.trace - warm] * amp)
                for (let i = root.trace - warm + 1; i < root.trace; i++)
                    ctx.lineTo(i * step, base - b[i] * amp)
                ctx.strokeStyle = String(root.colA(root.lamp, 0.95))
                ctx.lineWidth = 1.8
                ctx.stroke()

                // gust marks on the top rule — every other sample, with the
                // parity riding the drum so each mark stays glued to its ink
                // as the paper scrolls (a fixed parity would strobe at ~15Hz)
                ctx.fillStyle = String(root.colA(root.ember, 0.85))
                const g = root.gustBuf
                for (let i = root.drumStep % 2; i < root.trace; i += 2)
                    if (g[i]) ctx.fillRect(i * step - 1, h * 0.12, 2, 5)

                // the pen arm: pivot at the drum's right cheek, nib on the trace
                const nibX = (root.trace - 1) * step
                const nibY = base - b[root.trace - 1] * amp
                ctx.strokeStyle = String(root.colA(root.slate, 0.9))
                ctx.lineWidth = 1.2
                ctx.beginPath()
                ctx.moveTo(w - 2, h - 4)
                ctx.lineTo(nibX, nibY)
                ctx.stroke()
                ctx.fillStyle = String(root.lamp)
                ctx.beginPath()
                ctx.arc(nibX, nibY, 2.4, 0, 2 * Math.PI)
                ctx.fill()
            }
        }
    }
}
