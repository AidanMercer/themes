import QtQuick
import Quickshell.Io

// road8: the music builds a second city. Thirty-two towers of lit pixel
// windows rise out of the road when sound plays — a skyline equalizer,
// stacked block by block on a hard grid (heights quantize to whole windows,
// nothing glides). Every column carries a pale peak-hold pixel that hangs
// like a rooftop beacon and falls back a floor at a time; columns that run
// hot flash their top windows taillight-red. At silence the city goes dark
// window by window, the canvas stops painting, and the cava process itself
// is parked (feed gate below). Click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // pushed by the loader after mount: lock/fullscreen cover + mpris playing
    property bool occluded: false
    property bool playing: true
    readonly property bool feedOn: playing && !occluded

    readonly property color amber: pal.neon
    readonly property color starlight: pal.cyan
    readonly property color tail: pal.magenta
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function colA(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    readonly property int bins: 32
    readonly property int floors: 14      // vertical resolution, in windows

    property var levels: []       // raw cava bins 0..1
    property var display: []      // smoothed values
    property var peaks: []        // peak-hold, 0..1
    property bool humming: false

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

    Component.onCompleted: {
        const d = [], p = []
        for (let i = 0; i < bins; i++) { d.push(0); p.push(0) }
        display = d
        peaks = p
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
            if (!tick.running) tick.start()
        }
    }

    // smoothing + peak physics — stops itself once frames go stale and the
    // whole skyline has gone dark, so silence costs nothing.
    Timer {
        id: tick
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            const d = root.display, l = root.levels, p = root.peaks
            let loud = 0, settled = true
            for (let i = 0; i < root.bins; i++) {
                // feedOn guard: when the feed is cut (pause/lock) `levels`
                // freezes at its last frame — go dark instead of chasing
                // stale loudness, which would keep this tick alive forever
                let t = root.feedOn ? (l[i] || 0) : 0
                if (t < 0.04) t = 0
                d[i] = d[i] + (t - d[i]) * 0.42
                if (d[i] < 0.005) d[i] = 0
                // beacons hang, then drop a floor at a time
                p[i] = Math.max(p[i] - 0.014, d[i])
                if (p[i] < 0.005) p[i] = 0
                if (d[i] > loud) loud = d[i]
                if (d[i] > 0.004 || p[i] > 0.004) settled = false
            }

            const now = Date.now()
            const audioActive = root.feedOn && loud > 0.05
            if (audioActive) root.lastFrameMs = now

            const nowHumming = audioActive || !settled
            if (nowHumming !== root.humming) root.humming = nowHumming

            city.requestPaint()
            if (!nowHumming && now - root.lastFrameMs > 2000) tick.stop()   // cava asleep
        }
    }

    // ── the skyline ─────────────────────────────────────────────────────────
    Canvas {
        id: city
        width: Math.round(root.width * 0.52)
        height: Math.round(root.height * 0.26)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.075)
        scale: pal.uiScale
        transformOrigin: Item.Bottom

        opacity: root.bootT * (root.humming ? 1 : 0)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            const colW = w / root.bins
            const rowH = h / (root.floors + 1)
            const bw = colW * 0.62            // window width
            const bh = rowH * 0.72            // window height
            const bx = colW * 0.19

            const d = root.display, p = root.peaks
            for (let i = 0; i < root.bins; i++) {
                const lit = Math.round(d[i] * root.floors)       // whole windows only
                const hot = d[i] > 0.86
                for (let b = 0; b < lit; b++) {
                    const y = h - (b + 1) * rowH
                    if (hot && b >= lit - 2) ctx.fillStyle = String(root.colA(root.tail, 0.95))
                    else if (b === lit - 1)  ctx.fillStyle = String(root.colA(root.pal.text, 0.9))
                    else ctx.fillStyle = String(root.amberA(0.30 + 0.55 * (b / root.floors)))
                    ctx.fillRect(i * colW + bx, y, bw, bh)
                }
                // the rooftop beacon, hanging above the tower
                const pk = Math.round(p[i] * root.floors)
                if (pk > 0 && pk >= lit) {
                    const y = h - (pk + 1) * rowH
                    ctx.fillStyle = String(root.colA(root.starlight, 0.85))
                    ctx.fillRect(i * colW + bx + bw * 0.28, y + bh * 0.3, bw * 0.44, bh * 0.5)
                }
            }
            // the ground the city stands on — one dim baseline
            ctx.fillStyle = String(root.amberA(0.18))
            ctx.fillRect(0, h - 2, w, 2)
        }
    }
}
