import QtQuick
import Quickshell.Io

// nightshift: the census skyline. The visualizer isn't drawn over the city —
// it IS the city. Each frequency bucket is a building, its height quantized to
// whole floors, its rooms lighting with that band's energy: bass lights the
// ground floors right across the district, treble puts one room on at the top.
// Rooms never dim smoothly on the way down — a floor holds, then goes out.
//
// At silence the city empties from the top down, floor by floor, the canvas
// stops painting and the cava process itself is parked. Click-through scenery,
// sitting along the bottom edge where the real rooftops are.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // pushed by the loader after mount: lock/fullscreen cover + mpris playing
    property bool occluded: false
    property bool playing: true
    readonly property bool feedOn: playing && !occluded
    // a stale last frame would hold the district above the sleep threshold
    // forever — flush it so the blackout can run and the tick timer can stop
    onFeedOnChanged: if (!feedOn) levels = []

    readonly property color sodium: pal.neon
    readonly property color haze: pal.cyan
    readonly property color beacon: pal.magenta
    readonly property color slate: pal.dim
    readonly property real ui: pal.uiScale
    function colA(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // ── the district, in rooms ──────────────────────────────────────────────
    readonly property int bins: 32          // must match cava.conf `bars`
    readonly property int bw: 4             // rooms across one building
    readonly property int floors: 16

    // room size derives from the panel so the skyline reads the same on a
    // 32:9 desktop and a laptop
    readonly property real span: Math.min(root.width * 0.64, 2900 * ui)
    readonly property real bldgW: span / bins * 0.74
    readonly property real cell: Math.max(3, bldgW / bw * 0.80)
    readonly property real gap: Math.max(1, cell * 0.26)
    readonly property real bldgGap: span / bins - (bw * (cell + gap) - gap)

    property var levels: []                 // raw cava bins 0..1
    property var energy: []                 // smoothed per-building energy
    property var rooms: []                  // per-room brightness 0..1
    property bool humming: false
    property double lastFrameMs: 0
    property int blackoutFloor: -1          // the emptying sweep, top floor first

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

    function alloc() {
        const e = [], r = []
        for (let i = 0; i < bins; i++) e.push(0)
        for (let i = 0; i < bins * bw * floors; i++) r.push(0)
        energy = e; rooms = r
    }
    Component.onCompleted: alloc()

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
        if (out.length === root.bins) {
            root.levels = out
            root.lastFrameMs = Date.now()
            root.blackoutFloor = -1
            if (!tick.running) tick.start()
        }
    }

    // the district's physics. Energy damps per building; a room is lit when its
    // floor is below the building's height, and each room carries a little of
    // its own phase so a building never lights as one solid slab.
    Timer {
        id: tick
        interval: 33
        running: false
        repeat: true
        onTriggered: {
            const l = root.levels, e = root.energy, rm = root.rooms
            const now = Date.now()
            const stale = now - root.lastFrameMs > 2000

            let moving = false
            for (let b = 0; b < root.bins; b++) {
                const target = stale ? 0 : (l[b] || 0)
                // rises fast, falls slow — a room stays on for a moment after
                // the sound that lit it
                e[b] += (target - e[b]) * (target > e[b] ? 0.55 : 0.10)
                if (e[b] < 0.004) e[b] = 0
                if (Math.abs(e[b] - target) > 0.004) moving = true

                const lit = e[b] * root.floors
                for (let f = 0; f < root.floors; f++) {
                    // the top-down blackout wins over the audio while it sweeps
                    const blacked = root.blackoutFloor >= 0 && f >= root.blackoutFloor
                    let want = (!blacked && f < lit) ? 1 : 0
                    if (want && f + 1 > lit) want = (lit - f)      // the part floor
                    for (let c = 0; c < root.bw; c++) {
                        const idx = (b * root.bw + c) * root.floors + f
                        // rooms in a floor don't all agree — a fixed per-room
                        // bias keeps the skyline from looking like a bar chart
                        const bias = 0.72 + 0.28 * (((idx * 2654435761) % 1000) / 1000)
                        const tgt = want * bias
                        rm[idx] += (tgt - rm[idx]) * (tgt > rm[idx] ? 0.65 : 0.16)
                        if (rm[idx] < 0.01) rm[idx] = 0
                        else if (Math.abs(rm[idx] - tgt) > 0.01) moving = true
                    }
                }
            }

            const nowHumming = !stale && moving
            if (nowHumming !== root.humming) root.humming = nowHumming
            sky.requestPaint()

            if (stale) {
                // the city empties from the roof down
                if (root.blackoutFloor < 0) root.blackoutFloor = root.floors - 1
                else if (root.blackoutFloor > 0 && tick.count % 3 === 0) root.blackoutFloor--
                tick.count++
                if (!moving && root.blackoutFloor <= 0) {
                    for (let i = 0; i < rm.length; i++) rm[i] = 0
                    sky.requestPaint()
                    tick.stop()
                }
            }
        }
        property int count: 0
    }


    // ── the skyline ─────────────────────────────────────────────────────────
    Item {
        id: district
        width: root.span
        height: root.floors * (root.cell + root.gap) - root.gap
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.055)

        opacity: root.bootT * (root.humming ? 1 : 0)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 620; easing.type: Easing.InOutQuad } }

        Canvas {
            id: sky
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const cw = root.cell, ch = root.cell, g = root.gap
                const pitchY = ch + g
                const bStride = root.bw * (cw + g) - g + root.bldgGap
                const rm = root.rooms
                const darkCss = String(root.colA(root.slate, 0.22))
                const litCss = String(root.colA(root.sodium, 1))
                const hotCss = String(root.colA(root.beacon, 1))

                // the dark elevations first, one fillStyle for the lot
                ctx.globalAlpha = 1
                ctx.fillStyle = darkCss
                for (let b = 0; b < root.bins; b++) {
                    const bx = b * bStride
                    for (let c = 0; c < root.bw; c++) {
                        const x = bx + c * (cw + g)
                        for (let f = 0; f < root.floors; f++) {
                            if (rm[(b * root.bw + c) * root.floors + f] > 0.02) continue
                            ctx.fillRect(x, (root.floors - 1 - f) * pitchY, cw, ch)
                        }
                    }
                }

                // then the lit rooms
                ctx.fillStyle = litCss
                for (let b = 0; b < root.bins; b++) {
                    const bx = b * bStride
                    for (let c = 0; c < root.bw; c++) {
                        const x = bx + c * (cw + g)
                        for (let f = 0; f < root.floors; f++) {
                            const v = rm[(b * root.bw + c) * root.floors + f]
                            if (v <= 0.02) continue
                            ctx.globalAlpha = Math.min(1, v)
                            ctx.fillRect(x, (root.floors - 1 - f) * pitchY, cw, ch)
                        }
                    }
                }

                // a building that peaks gets the tower beacon — the ONE red
                // light in a blue city, and only on the roof. Colouring the
                // whole tower would make red a second theme colour; it isn't.
                ctx.fillStyle = hotCss
                for (let b = 0; b < root.bins; b++) {
                    if (root.energy[b] <= 0.90) continue
                    const top = Math.min(root.floors - 1, Math.floor(root.energy[b] * root.floors))
                    const y = (root.floors - 1 - top) * pitchY
                    ctx.globalAlpha = Math.min(1, (root.energy[b] - 0.90) * 10)
                    for (let c = 0; c < root.bw; c++)
                        ctx.fillRect(b * bStride + c * (cw + g), y, cw, ch)
                }
                ctx.globalAlpha = 1
            }
        }

        // the street the district stands on
        Rectangle {
            anchors.top: parent.bottom
            anchors.topMargin: Math.round(6 * root.ui)
            width: parent.width
            height: 1
            color: root.colA(root.haze, 0.28)
        }
    }
}
