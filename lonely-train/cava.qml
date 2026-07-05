import QtQuick
import QtQuick.Effects
import Quickshell.Io
import Quickshell.Services.Mpris

// lonely-train: the cassette deck, centered on screen.
// A ghost cassette drawn in thin dusk lines: two reels whose tape packs
// wind from left to right as the track plays, spokes turning only while
// audio is audible, and between them the spectrum rises off the tape line
// like passing city lights — amber, with a faint blue reflection under the
// line. SIDE A in the corner, a red REC pip while the tape rolls.
// Runs its own cava against the conf next door; silence = a still deck.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color amber: pal.neon
    readonly property color dusk:  pal.cyan
    readonly property color tail:  pal.magenta
    readonly property color ink:   pal.text
    readonly property string mono: pal.fontMono

    readonly property int barCount: 44
    property var levels: []
    property var display: []
    property real spin: 0          // reel angle, advanced only on audio
    property real loud: 0          // smoothed overall level, dims the deck at rest

    // track progress → tape pack radii (mpris, re-read once a second)
    readonly property var player: {
        const ps = Mpris.players.values
        if (ps.length === 0) return null
        return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps[0]
    }
    readonly property bool playing: player !== null && player.playbackState === MprisPlaybackState.Playing
    property real progress: 0.4
    Timer {
        interval: 1000; repeat: true
        running: root.playing
        triggeredOnStart: true
        onTriggered: {
            const p = root.player
            root.progress = (p && p.length > 0 && p.position >= 0)
                ? Math.min(1, p.position / p.length) : 0.4
            canvas.requestPaint()
        }
    }

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
    onBootTChanged: canvas.requestPaint()
    onSpinChanged: canvas.requestPaint()

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
            let peak = 0
            for (let i = 0; i < root.barCount; i++) {
                let t = l[i] || 0
                if (t < 0.05) t = 0
                const nv = d[i] + (t - d[i]) * 0.4
                moved += Math.abs(nv - d[i])
                d[i] = nv
                if (nv > peak) peak = nv
            }
            const nl = root.loud + (Math.min(1, peak * 1.6) - root.loud) * 0.08
            if (Math.abs(nl - root.loud) > 0.002) root.loud = nl
            if (moved > 0.002) {
                root.display = d
                canvas.requestPaint()
            }
            // reels turn while anything is audible; a silent deck stands still
            if (peak > 0.03) root.spin = (root.spin + 2.4) % 360
        }
    }

    readonly property real bass: {
        const d = display
        if (!d.length) return 0
        return (d[0] + d[1] + d[2]) / 3
    }

    Item {
        id: stage
        width: 640
        height: 260
        anchors.centerIn: parent
        opacity: root.bootT * (0.45 + 0.55 * root.loud)
        scale: pal.uiScale * (0.94 + 0.06 * root.bootT)

        // soft amber glow of the crisp deck below — breathes with the bass
        MultiEffect {
            source: canvas
            anchors.fill: canvas
            autoPaddingEnabled: true
            blurEnabled: true
            blur: 1.0
            blurMax: 30
            colorization: 1.0
            colorizationColor: root.amber
            brightness: 0.1
            opacity: 0.35 + 0.35 * root.bass
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            renderStrategy: Canvas.Threaded

            // pal reads config.toml async — retint when it lands
            Connections {
                target: root.pal
                function onNeonChanged() { canvas.requestPaint() }
                function onCyanChanged() { canvas.requestPaint() }
                function onMagentaChanged() { canvas.requestPaint() }
            }

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height
                const cy = h * 0.44
                const amber = root.amber, dusk = root.dusk
                function col(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

                // ── cassette shell: rounded outline + corner screws ──
                const m = 8, r = 16
                ctx.strokeStyle = col(dusk, 0.35)
                ctx.lineWidth = 1.2
                ctx.beginPath()
                ctx.moveTo(m + r, m)
                ctx.lineTo(w - m - r, m); ctx.arcTo(w - m, m, w - m, m + r, r)
                ctx.lineTo(w - m, h - m - r); ctx.arcTo(w - m, h - m, w - m - r, h - m, r)
                ctx.lineTo(m + r, h - m); ctx.arcTo(m, h - m, m, h - m - r, r)
                ctx.lineTo(m, m + r); ctx.arcTo(m, m, m + r, m, r)
                ctx.closePath()
                ctx.stroke()
                for (const [sx, sy] of [[m + 12, m + 12], [w - m - 12, m + 12], [m + 12, h - m - 12], [w - m - 12, h - m - 12]]) {
                    ctx.beginPath()
                    ctx.arc(sx, sy, 2.4, 0, Math.PI * 2)
                    ctx.strokeStyle = col(dusk, 0.45)
                    ctx.lineWidth = 1
                    ctx.stroke()
                }

                // ── reels ──
                const rx = [w * 0.5 - 190, w * 0.5 + 190]
                const hubR = 15, packMax = 42, packMin = 20
                const packs = [packMin + (packMax - packMin) * (1 - root.progress),
                               packMin + (packMax - packMin) * root.progress]
                for (let i = 0; i < 2; i++) {
                    const cx = rx[i]
                    // tape pack
                    ctx.beginPath()
                    ctx.arc(cx, cy, packs[i], 0, Math.PI * 2)
                    ctx.strokeStyle = col(dusk, 0.55)
                    ctx.lineWidth = 2
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(cx, cy, packs[i] - 4, 0, Math.PI * 2)
                    ctx.strokeStyle = col(dusk, 0.18)
                    ctx.lineWidth = 1
                    ctx.stroke()
                    // hub with three spokes, turned by spin (reels counter-rotate)
                    const a0 = (i === 0 ? 1 : -1) * root.spin * Math.PI / 180
                    ctx.beginPath()
                    ctx.arc(cx, cy, hubR, 0, Math.PI * 2)
                    ctx.strokeStyle = col(amber, 0.95)
                    ctx.lineWidth = 2
                    ctx.stroke()
                    for (let s = 0; s < 3; s++) {
                        const a = a0 + s * Math.PI * 2 / 3
                        ctx.beginPath()
                        ctx.moveTo(cx + Math.cos(a) * 3, cy + Math.sin(a) * 3)
                        ctx.lineTo(cx + Math.cos(a) * (hubR - 2), cy + Math.sin(a) * (hubR - 2))
                        ctx.strokeStyle = col(amber, 0.9)
                        ctx.lineWidth = 2
                        ctx.stroke()
                    }
                }

                // ── the tape line between the packs ──
                const tapeY = cy + packMax + 14
                ctx.beginPath()
                ctx.moveTo(rx[0], cy + packs[0])
                ctx.quadraticCurveTo(rx[0], tapeY, rx[0] + 34, tapeY)
                ctx.lineTo(rx[1] - 34, tapeY)
                ctx.quadraticCurveTo(rx[1], tapeY, rx[1], cy + packs[1])
                ctx.strokeStyle = col(dusk, 0.5)
                ctx.lineWidth = 1.4
                ctx.stroke()

                // counter ticks along the tape, like a tape ruler
                ctx.strokeStyle = col(dusk, 0.35)
                ctx.lineWidth = 1
                for (let x = rx[0] + 40; x <= rx[1] - 40; x += 24) {
                    ctx.beginPath()
                    ctx.moveTo(x, tapeY + 4)
                    ctx.lineTo(x, tapeY + 8)
                    ctx.stroke()
                }

                // ── the spectrum: city lights rising off the tape ──
                const d = root.display, n = root.barCount
                const x0 = rx[0] + 44, x1 = rx[1] - 44
                const step = (x1 - x0) / (n - 1)
                const barMax = 88 * root.bootT
                ctx.lineCap = "round"
                for (let i = 0; i < n; i++) {
                    const lvl = d[i] || 0
                    if (lvl <= 0.01) continue
                    const x = x0 + i * step
                    const bh = 3 + barMax * lvl
                    // blue reflection under the line, like lights on wet glass
                    ctx.beginPath()
                    ctx.moveTo(x, tapeY + 10)
                    ctx.lineTo(x, tapeY + 10 + bh * 0.28)
                    ctx.strokeStyle = col(dusk, 0.30)
                    ctx.lineWidth = 3
                    ctx.stroke()
                    // amber light above
                    ctx.beginPath()
                    ctx.moveTo(x, tapeY - 2)
                    ctx.lineTo(x, tapeY - 2 - bh)
                    ctx.strokeStyle = col(amber, 0.42 + 0.55 * lvl)
                    ctx.lineWidth = 3.4
                    ctx.stroke()
                }
            }
        }

        // SIDE A · 90 — the label corner
        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 26
            anchors.topMargin: 18
            spacing: 8
            Text {
                text: "SIDE A"
                color: Qt.rgba(root.amber.r, root.amber.g, root.amber.b, 0.9)
                font.family: root.mono
                font.pixelSize: 12
                font.weight: Font.Bold
                font.letterSpacing: 4
            }
            Text {
                text: "· 90 min"
                color: Qt.rgba(root.dusk.r, root.dusk.g, root.dusk.b, 0.6)
                font.family: root.mono
                font.pixelSize: 10
                font.letterSpacing: 2
            }
        }

        // REC pip — steady red while the tape rolls, gone at rest
        Row {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 26
            anchors.topMargin: 18
            spacing: 6
            opacity: root.loud > 0.05 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7; height: 7; radius: 3.5
                color: root.tail
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "REC"
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
                font.family: root.mono
                font.pixelSize: 10
                font.letterSpacing: 3
            }
        }
    }
}
