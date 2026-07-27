import QtQuick

// nightshift: the lyric line is strung across the hillside as a RUN OF CABLE.
// Every word of the active line is a window somewhere out in the district —
// plotted at its own storey and its own distance (near windows big, far ones
// small) — and between one window and the next hangs a sagging span of wire.
// As the line is sung the current crawls that wire span by span, a bright bead
// running along the cable, and when it reaches the far end the room SNAPS on:
// sodium while it's the word being sung, cooling to haze blue once it's past.
// Words still coming are dark windows you can only just make out. When the
// line is over the run goes dark from the top down, storey by storey, on the
// theme's ripple — nothing tweens, and nothing goes out with anything else.
//
// Styling only — all timing lives in the shell's LyricsEngine, injected as
// `engine`: tokens, activeIndex, estMs, tokenState(i, est), lineDoneMs,
// player, lyricsLoaded, lyricsSynced, audioReady/audioSilent/audioPulse,
// offsetMs + offsetNudged().
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine

    readonly property color sodium: pal.neon
    readonly property color haze: pal.cyan
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property real ui: pal.uiScale
    readonly property string sans: "Noto Sans"
    readonly property string mono: pal.fontMono
    function sodiumA(a) { return Qt.rgba(sodium.r, sodium.g, sodium.b, a) }
    function hazeA(a)   { return Qt.rgba(haze.r, haze.g, haze.b, a) }
    function slateA(a)  { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function inkA(a)    { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    // ── the run: the haze band right of the figure ──────────────────────────
    readonly property real aspect: root.height > 0 ? root.width / root.height : 1.78
    readonly property bool ultrawide: aspect > 2.4
    readonly property real wordSize: Math.round((ultrawide ? 40 : 30) * ui)
    readonly property real boxW: Math.round(root.width * (ultrawide ? 0.26 : 0.44))
    readonly property real boxH: Math.round(root.height * 0.36)
    readonly property real boxX: Math.round(root.width * (ultrawide ? 0.955 : 0.94) - boxW)
    readonly property real boxY: Math.round(root.height * 0.40)

    // one storey — the vertical quantum every window on the run sits on. Two
    // storeys either side of the run's line, and the next row down the hill
    // clears the tallest of them plus a word's height.
    readonly property real floorH: Math.round(wordSize * 0.85)
    readonly property real rowH: Math.round(4 * floorH + wordSize * 1.6)

    function rng32(seed) {
        let a = seed >>> 0
        return function () {
            a = (a + 0x6D2B79F5) | 0
            let t = Math.imul(a ^ (a >>> 15), 1 | a)
            t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296
        }
    }

    // Plot the run: every MAIN word becomes a window {x, y, size, px, py} —
    // px/py is the window the cable comes FROM. Heights step by whole storeys
    // (the wire never slides, it steps), sizes quantize to three distances.
    // Adlibs hang under the window they follow, off the cable. Seeded per line,
    // so every line strings a fresh run.
    function plot(seedIdx, tokens) {
        const n = tokens.length
        if (n === 0) return []
        const r = rng32((seedIdx + 1) * 2654435761)
        const out = []
        const gap = wordSize * 0.62
        let cx = r() * wordSize * 0.6
        let rowY = wordSize * 1.5
        let lastX = -1, lastY = -1, lastSz = wordSize
        let storey = 0
        for (let i = 0; i < n; i++) {
            const tk = tokens[i]
            if (tk.bg) {
                out.push({ x: Math.max(0, lastX), y: (lastY < 0 ? rowY : lastY) + wordSize * 1.05,
                           size: Math.round(wordSize * 0.5), px: -1, py: -1, psz: lastSz })
                continue
            }
            // three distances: a window across the street, one down the hill,
            // one out on the far ridge
            const d = r()
            const fpx = Math.round(wordSize * (d < 0.18 ? 1.3 : d < 0.6 ? 1.0 : 0.76))
            const wPx = Math.max(fpx * 0.6, tk.text.length * fpx * 0.54)
            if (cx + wPx > boxW && lastX >= 0) {      // the run turns down the hill
                cx = r() * wordSize * 1.1
                rowY += rowH
                storey = r() < 0.5 ? -1 : 1
            }
            const step = (r() < 0.5 ? -1 : 1) * (r() < 0.28 ? 2 : 1)
            storey = Math.max(-2, Math.min(2, storey + step))
            const x = cx + wPx / 2
            const y = rowY + storey * floorH
            out.push({ x: x, y: y, size: fpx, px: lastX, py: lastY, psz: lastSz })
            lastX = x; lastY = y; lastSz = fpx
            cx += wPx + gap
        }
        return out
    }

    readonly property var curLayout: plot(engine.activeIndex, engine.tokens)

    // the run doesn't linger in the gap between lines
    readonly property real lineHoldMs: 420
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // a short blackout on line change so one run is down before the next is up
    property bool gate: true
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() { root.gate = false; gateCut.restart() }
        function onOffsetNudged() { osdShow.restart() }
    }

    Item {
        id: run
        x: root.boxX
        y: root.boxY
        width: root.boxW
        height: root.boxH

        readonly property bool up: root.gate && !root.lineExpired
                                   && root.engine.tokens.length > 0

        Repeater {
            model: root.engine.tokens
            delegate: Item {
                id: wd
                required property int index
                required property var modelData        // {text, bg, mainIdx, t, d}
                readonly property bool bg: modelData.bg
                // touching audioSilent makes a held word release the moment the
                // silence signal flips, even if estMs is momentarily static
                readonly property var st: (root.engine.audioSilent,
                                           root.engine.tokenState(index, root.engine.estMs))
                readonly property var p: root.curLayout[index]
                    ? root.curLayout[index]
                    : ({ x: 0, y: 0, size: root.wordSize, px: -1, py: -1, psz: root.wordSize })
                readonly property real fill: Math.max(0, Math.min(1, st.fill))
                readonly property bool sung: st.fill >= 1 && !st.active
                readonly property bool singing: st.active && !wd.sung
                // the room lights when the current ARRIVES — which for every
                // window but the first is the far end of its own cable span
                readonly property bool roomLit: wd.p.px < 0 ? (st.active || wd.sung)
                                                            : wd.fill >= 0.98

                x: 0; y: 0
                width: run.width; height: run.height

                // where a cable ties on: the sill of a window of this size
                function sillOff(sz) { return Math.max(5, Math.round(sz * 0.44)) / 2 + 1 }

                // ── the run goes dark from the top down ────────────────────
                // ripple, not a fade: the high windows go out first and each
                // one waits its own moment (law 2 — nothing switches together)
                readonly property real dusk: run.up ? 0
                    : Math.round((wd.p.y / Math.max(1, run.height)) * 240)
                      + ((wd.index * 7919) % 120)
                opacity: run.up ? 1 : 0
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: wd.dusk }
                        NumberAnimation { duration: run.up ? 120 : 190; easing.type: Easing.OutQuad }
                    }
                }

                // ── the cable span: a quadratic sag, cut into segments ──────
                // Segments are what the current is metered in: it fills them in
                // order, so the bead advances along the wire instead of a line
                // simply getting longer.
                readonly property var arc: {
                    if (wd.bg || wd.p.px < 0) return null
                    // the cable is bracketed to the sill of each window, not to
                    // the middle of the room
                    const ax = wd.p.px, ay = wd.p.py + wd.sillOff(wd.p.psz)
                    const bx = wd.p.x,  by = wd.p.y  + wd.sillOff(wd.p.size)
                    const dx = bx - ax, dy = by - ay
                    const len = Math.sqrt(dx * dx + dy * dy)
                    if (len < 1) return null
                    const sag = Math.min(22, len * 0.17)
                    // control point at mid + 2·sag puts the curve's belly exactly
                    // `sag` below the chord
                    return { ax: ax, ay: ay, bx: bx, by: by,
                             cx: (ax + bx) / 2, cy: (ay + by) / 2 + sag * 2,
                             n: Math.max(4, Math.min(16, Math.round(len / 20))) }
                }
                function arcPt(t) {
                    const a = wd.arc
                    if (!a) return Qt.point(0, 0)
                    const u = 1 - t
                    return Qt.point(u * u * a.ax + 2 * u * t * a.cx + t * t * a.bx,
                                    u * u * a.ay + 2 * u * t * a.cy + t * t * a.by)
                }
                readonly property var wire: {
                    const a = wd.arc
                    if (!a) return []
                    const out = []
                    let prev = null
                    for (let k = 0; k <= a.n; k++) {
                        const t = k / a.n, u = 1 - t
                        const px = u * u * a.ax + 2 * u * t * a.cx + t * t * a.bx
                        const py = u * u * a.ay + 2 * u * t * a.cy + t * t * a.by
                        if (prev) {
                            const dx = px - prev.x, dy = py - prev.y
                            out.push({ x: prev.x, y: prev.y,
                                       len: Math.sqrt(dx * dx + dy * dy),
                                       rot: Math.atan2(dy, dx) * 180 / Math.PI })
                        }
                        prev = { x: px, y: py }
                    }
                    return out
                }

                Repeater {
                    model: wd.wire
                    delegate: Rectangle {
                        id: seg
                        required property int index
                        required property var modelData
                        // how far the current has got into THIS segment
                        readonly property real prog:
                            Math.max(0, Math.min(1, wd.fill * wd.wire.length - index))
                        x: modelData.x
                        y: modelData.y
                        width: modelData.len * prog
                        height: 1.3
                        antialiasing: true
                        visible: width > 0.3
                        transformOrigin: Item.Left
                        rotation: modelData.rot
                        // live wire at the head, cooled cable behind it
                        color: (wd.singing && seg.prog < 1) ? root.sodiumA(0.9)
                             : wd.sung ? root.hazeA(0.5)
                             : root.hazeA(0.7)
                    }
                }

                // the bead of current riding the cable
                Rectangle {
                    readonly property point hp: wd.arcPt(wd.fill)
                    visible: wd.singing && wd.arc !== null && wd.fill > 0.01 && wd.fill < 0.995
                    x: hp.x - width / 2
                    y: hp.y - height / 2
                    width: 4; height: 4
                    color: root.sodium
                    Rectangle {                       // its little halo
                        anchors.centerIn: parent
                        width: 12; height: 12
                        radius: width / 2
                        color: root.sodiumA(0.18)
                        z: -1
                    }
                }

                // ── the window itself ──────────────────────────────────────
                // it doesn't fade up: somebody hits the switch, it overshoots
                // and settles — the same bloom every lit room in this theme has
                property real bloom: 0
                onRoomLitChanged: if (roomLit) blm.restart()
                SequentialAnimation {
                    id: blm
                    NumberAnimation { target: wd; property: "bloom"; to: 1; duration: 70; easing.type: Easing.OutQuad }
                    NumberAnimation { target: wd; property: "bloom"; to: 0; duration: 430; easing.type: Easing.OutCubic }
                }
                // a held note leaves the room guttering like a tired tube —
                // waits out the snap-on bloom so the two never fight over `bloom`
                SequentialAnimation {
                    running: wd.singing && wd.st.sustain === true && run.up && !blm.running
                    loops: Animation.Infinite
                    NumberAnimation { target: wd; property: "bloom"; to: 0.55; duration: 190 }
                    NumberAnimation { target: wd; property: "bloom"; to: 0.05; duration: 260 }
                }

                Item {
                    visible: !wd.bg
                    x: wd.p.x
                    y: wd.p.y
                    readonly property real rw: Math.max(4, Math.round(wd.p.size * 0.34))
                    readonly property real rh: Math.max(5, Math.round(wd.p.size * 0.44))

                    // the light thrown out of a lit room
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.rw * 5.5
                        height: parent.rw * 5.5
                        radius: width / 2
                        visible: wd.roomLit
                        color: wd.singing ? root.sodiumA(0.07 + 0.16 * wd.bloom)
                                          : root.hazeA(0.05 + 0.06 * wd.bloom)
                    }
                    // the sill the cable is bracketed to
                    Rectangle {
                        x: -parent.rw * 1.1
                        y: parent.rh / 2 + 1
                        width: parent.rw * 2.2
                        height: 1
                        color: wd.roomLit ? root.hazeA(0.45) : root.slateA(0.55)
                    }
                    Rectangle {
                        x: -parent.rw / 2
                        y: -parent.rh / 2
                        width: parent.rw
                        height: parent.rh
                        color: !wd.roomLit ? root.slateA(0.5)
                             : wd.singing ? root.sodium
                             : root.hazeA(0.85)
                        scale: 1 + 0.5 * wd.bloom
                        antialiasing: true
                    }
                }

                // ── the word over its window (adlibs hang below, off-cable) ──
                Text {
                    id: wt
                    x: wd.p.x - width / 2
                    y: wd.bg ? wd.p.y : wd.p.y - height - Math.round(9 * root.ui)
                    text: wd.bg ? ("(" + wd.modelData.text + ")") : wd.modelData.text
                    textFormat: Text.PlainText
                    font.family: root.sans
                    font.pixelSize: wd.p.size
                    font.weight: wd.bg ? Font.Normal
                               : wd.singing ? Font.DemiBold
                               : wd.sung ? Font.Medium : Font.Light
                    font.italic: wd.bg
                    font.letterSpacing: 0.6
                    color: wd.bg ? root.hazeA(0.7)
                         : wd.singing ? root.sodium
                         : wd.sung ? root.hazeA(0.95)
                         : root.hazeA(0.38)
                    // the words have to hold over the brightest video frame
                    style: Text.Outline
                    styleColor: Qt.rgba(0.012, 0.043, 0.086, 0.7)
                    // the word snaps to full the instant it's the one being sung
                    scale: wd.singing ? 1 + 0.04 * wd.bloom
                         + (root.engine.audioReady ? root.engine.audioPulse * 0.035 : 0) : 1
                }
            }
        }

        // status, only when there's nothing to sing
        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            visible: root.engine.player !== null && root.engine.tokens.length === 0
            text: !root.engine.lyricsLoaded ? "looking for words…"
                : !root.engine.lyricsSynced ? "no timed lyrics" : ""
            color: root.inkA(0.7)
            style: Text.Outline
            styleColor: Qt.rgba(0.012, 0.043, 0.086, 0.6)
            font.family: root.sans
            font.pixelSize: Math.round(14 * root.ui)
            font.letterSpacing: 1.4
        }
    }

    // ── offset calibration OSD ──────────────────────────────────────────────
    // shift+scroll on the bar's track strip nudges the sync; show what landed
    Rectangle {
        id: osd
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.80
        width: osdT.implicitWidth + Math.round(28 * root.ui)
        height: Math.round(34 * root.ui)
        radius: 2
        color: Qt.rgba(0.012, 0.043, 0.086, 0.92)
        border.width: 1
        border.color: root.hazeA(0.35)
        opacity: 0
        visible: opacity > 0.01

        Text {
            id: osdT
            anchors.centerIn: parent
            text: "lyric offset  " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " ms"
            color: root.inkA(0.95)
            font.family: root.mono
            font.pixelSize: Math.round(12 * root.ui)
        }

        SequentialAnimation {
            id: osdShow
            NumberAnimation { target: osd; property: "opacity"; to: 1; duration: 110 }
            PauseAnimation { duration: 1100 }
            NumberAnimation { target: osd; property: "opacity"; to: 0; duration: 420 }
        }
    }
}
