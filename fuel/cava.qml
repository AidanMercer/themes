import QtQuick
import Quickshell.Io

// fuel: pump-flow display, standing low on the snowy forecourt (bottom-left,
// echoing the striped pumps across the drive). A chamfered pump-face panel —
// bent neon stripe on top, warm pump-screen glass — carrying:
//   left  — an analog PRESSURE gauge whose needle rides the overall level
//   right — a dot-matrix EQ: 20 columns of amber pump-display dots with
//           neon tips and a red peak row, like the readout mid-fill
// Runs its own cava (cava.conf next door). While the forecourt is silent the
// needle falls to rest, the dots go dark and the whole panel dims — no timers
// spin beyond cava's own idle stream.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // pushed by the loader after mount: lock/fullscreen cover + mpris playing
    property bool occluded: false
    property bool playing: true
    readonly property bool feedOn: playing && !occluded
    readonly property color neon:  pal.neon
    readonly property color ice:   pal.cyan
    readonly property color red:   pal.magenta
    readonly property color amber: pal.amber
    readonly property color dim:   pal.dim
    readonly property color ink:   pal.text
    readonly property string mono: pal.fontMono
    function inkA(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function iceA(a) { return Qt.rgba(ice.r, ice.g, ice.b, a) }

    readonly property int barCount: 20
    property var levels: []
    property var display: []
    property real level: 0            // smoothed overall, drives the needle
    property bool hot: false          // audio in the last ~2.5s

    Component.onCompleted: {
        const z = []
        for (let i = 0; i < barCount; i++) z.push(0)
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

    // smoothing pass — repaints only when something actually moved
    property real _lastSignal: 0
    Timer {
        id: smooth
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            const d = root.display
            const l = root.levels
            let moved = 0, sum = 0, peak = 0
            for (let i = 0; i < root.barCount; i++) {
                let t = l[i] || 0
                if (t < 0.04) t = 0
                const nv = d[i] + (t - d[i]) * 0.4
                moved += Math.abs(nv - d[i])
                d[i] = nv
                sum += nv
                if (nv > peak) peak = nv
            }
            if (moved > 0.002) {
                root.display = d
                dots.requestPaint()
            }
            root.level = root.level + (sum / root.barCount - root.level) * 0.25
            const now = Date.now()
            if (peak > 0.03) root._lastSignal = now
            root.hot = (now - root._lastSignal) < 2500
            // cava sleeps at silence (sleep_timer) — stop once everything settled; parseFrame rearms
            if (moved <= 0.002 && !root.hot && root.level < 0.003
                    && now - root.lastFrameMs > 2000)
                smooth.stop()
        }
    }

    // ── the pump face ───────────────────────────────────────────────────────
    Item {
        id: panel
        width: 356
        height: 148
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Math.round(root.width * 0.045)
        anchors.bottomMargin: Math.round(root.height * 0.11)
        scale: pal.uiScale
        transformOrigin: Item.BottomLeft
        opacity: root.hot ? 1.0 : 0.30
        Behavior on opacity { NumberAnimation { duration: 700 } }

        Canvas {
            id: plate
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            Connections {
                target: root.pal
                function onNeonChanged() { plate.requestPaint() }
                function onDimChanged()  { plate.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                const w = width, h = height, c = 12
                ctx.reset()
                ctx.beginPath()
                ctx.moveTo(0, c); ctx.lineTo(c, 0); ctx.lineTo(w - c, 0)
                ctx.lineTo(w, c); ctx.lineTo(w, h); ctx.lineTo(0, h)
                ctx.closePath()
                // warm pump-screen glass
                const g = ctx.createLinearGradient(0, 0, 0, h)
                g.addColorStop(0, "rgba(11,10,5,0.72)")
                g.addColorStop(1, "rgba(6,7,8,0.66)")
                ctx.fillStyle = g
                ctx.fill()
                ctx.strokeStyle = root.pal.dim
                ctx.globalAlpha = 0.5
                ctx.lineWidth = 1
                ctx.stroke()
                ctx.globalAlpha = 1
                // bent neon stripe
                ctx.beginPath()
                ctx.moveTo(0.8, c + 4); ctx.lineTo(c + 1.5, 1.2)
                ctx.lineTo(w - c - 1.5, 1.2); ctx.lineTo(w - 0.8, c + 4)
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.strokeStyle = root.pal.neon
                ctx.lineWidth = 4
                ctx.globalAlpha = 0.18
                ctx.stroke()
                ctx.lineWidth = 1.4
                ctx.globalAlpha = 0.9
                ctx.stroke()
                ctx.globalAlpha = 1
            }
        }

        // header
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 12
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            height: 12
            Text {
                anchors.left: parent.left
                text: "PUMP FLOW"
                color: root.amber
                font.family: root.mono
                font.weight: Font.Bold
                font.pixelSize: 9
                font.letterSpacing: 3
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "L/MIN"
                    color: root.iceA(0.55)
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Rectangle { width: 14; height: 2; color: root.amber; opacity: 0.8 }
                    Rectangle { width: 14; height: 2; color: root.neon; opacity: 0.9 }
                    Rectangle { width: 14; height: 2; color: root.red; opacity: 0.7 }
                }
            }
        }

        // ── analog pressure gauge ───────────────────────────────────────────
        Item {
            id: gauge
            width: 92
            height: 92
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.top: header.bottom
            anchors.topMargin: 8

            // static face: arc, ticks, red zone
            Canvas {
                id: face
                anchors.fill: parent
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: root.pal
                    function onCyanChanged()    { face.requestPaint() }
                    function onMagentaChanged() { face.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2, cy = height / 2, r = width / 2 - 6
                    const a0 = Math.PI * 0.75, a1 = Math.PI * 2.25
                    // dial arc
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, a0, a1)
                    ctx.strokeStyle = root.pal.dim
                    ctx.lineWidth = 2
                    ctx.globalAlpha = 0.8
                    ctx.stroke()
                    ctx.globalAlpha = 1
                    // red zone: last 20% of the sweep
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, a0 + (a1 - a0) * 0.8, a1)
                    ctx.strokeStyle = root.pal.magenta
                    ctx.lineWidth = 3
                    ctx.stroke()
                    // ticks
                    for (let i = 0; i <= 10; i++) {
                        const a = a0 + (a1 - a0) * i / 10
                        const long = i % 5 === 0
                        const r0 = r - (long ? 9 : 5)
                        ctx.beginPath()
                        ctx.moveTo(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0)
                        ctx.lineTo(cx + Math.cos(a) * (r - 1), cy + Math.sin(a) * (r - 1))
                        ctx.strokeStyle = root.pal.cyan
                        ctx.globalAlpha = long ? 0.9 : 0.45
                        ctx.lineWidth = long ? 1.6 : 1
                        ctx.stroke()
                    }
                    ctx.globalAlpha = 1
                }
            }

            // the needle
            Rectangle {
                id: needle
                width: 2.5
                height: gauge.width / 2 - 12
                radius: 1
                color: root.hot ? root.neon : root.dim
                antialiasing: true
                x: gauge.width / 2 - width / 2
                y: gauge.height / 2 - height
                transformOrigin: Item.Bottom
                rotation: -135 + 270 * Math.min(1, root.level * 1.35)
                Behavior on rotation { NumberAnimation { duration: 120 } }
                Behavior on color { ColorAnimation { duration: 500 } }
            }
            // hub cap
            Rectangle {
                anchors.centerIn: parent
                width: 8; height: 8; radius: 4
                color: root.amber
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                text: "PRESSURE"
                color: root.iceA(0.5)
                font.family: root.mono
                font.pixelSize: 7
                font.letterSpacing: 2
            }
        }

        // ── dot-matrix EQ ───────────────────────────────────────────────────
        Canvas {
            id: dots
            anchors.left: gauge.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.top: header.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            Connections {
                target: root.pal
                function onNeonChanged() { dots.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const n = root.barCount
                const rows = 9
                const gap = 3
                const cw = (width - gap * (n - 1)) / n
                const ch = (height - gap * (rows - 1)) / rows
                const rad = Math.min(cw, ch) * 0.32
                const d = root.display
                const amber = root.pal.amber, neon = root.pal.neon
                const red = root.pal.magenta, ink = root.pal.text
                function rr(x, y, w, h, r) {
                    ctx.beginPath()
                    ctx.moveTo(x + r, y)
                    ctx.arcTo(x + w, y, x + w, y + h, r)
                    ctx.arcTo(x + w, y + h, x, y + h, r)
                    ctx.arcTo(x, y + h, x, y, r)
                    ctx.arcTo(x, y, x + w, y, r)
                    ctx.closePath()
                }
                for (let i = 0; i < n; i++) {
                    const lit = Math.round((d[i] || 0) * rows)
                    for (let j = 0; j < rows; j++) {
                        // j counts from the bottom
                        const y = height - (j + 1) * ch - j * gap
                        const on = j < lit
                        if (on) {
                            ctx.fillStyle = j >= 8 ? red : j >= 6 ? neon : amber
                            ctx.globalAlpha = 0.95
                        } else {
                            ctx.fillStyle = ink
                            ctx.globalAlpha = 0.07
                        }
                        rr(i * (cw + gap), y, cw, ch, rad)
                        ctx.fill()
                    }
                }
                ctx.globalAlpha = 1
            }
        }
    }
}
