import QtQuick

// pines: the lyric line is a SURVEY TRAVERSE plotted across the fog bank on
// the right of the sky — styling only, the engine does the machinery. Each
// word of the active line is a station on the ranger's plane table: upcoming
// words wait as barely-there pencil ghosts over their station ticks, and as
// the line is sung the pencil draws the traverse leg by leg — a thin silver
// line crawling from station to station, its pace set by the karaoke fill —
// while each word CONDENSES sharp as the pencil reaches it: kerosene amber
// while it's the living word, settling to fog-silver ink once sung. A tiny
// benchmark triangle lands under every completed station. Adlibs hang under
// the line as small italic field notes. When the line ends the whole
// traverse dissolves back into fog and the next line is plotted fresh.
//
// Engine surface: tokens, activeIndex, estMs, tokenState(i, est), lineDoneMs,
// player, lyricsLoaded, lyricsSynced, audioReady/audioSilent/audioPulse,
// offsetMs + offsetNudged().
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color lamp: pal.neon
    readonly property color fogSilver: pal.cyan
    readonly property color inkCol: pal.text
    readonly property string serif: "Noto Serif Display"
    readonly property string mono: pal.fontMono
    function lampA(a)   { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function silverA(a) { return Qt.rgba(fogSilver.r, fogSilver.g, fogSilver.b, a) }

    // ── the plotting box: the mid-right fog bank ────────────────────────────
    readonly property real aspect: root.height > 0 ? root.width / root.height : 1.78
    readonly property bool ultrawide: aspect > 2.4
    property real lyricSize: Math.round((ultrawide ? 46 : 36) * pal.uiScale)
    readonly property real boxW: Math.round(root.width * (ultrawide ? 0.26 : 0.40))
    readonly property real boxH: Math.round(root.height * 0.34)
    readonly property real boxX: Math.round(root.width * (ultrawide ? 0.96 : 0.94) - boxW)
    readonly property real boxY: Math.round(root.height * 0.26)

    function rng32(seed) {
        let a = seed >>> 0
        return function () {
            a = (a + 0x6D2B79F5) | 0
            let t = Math.imul(a ^ (a >>> 15), 1 | a)
            t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296
        }
    }

    // plot the traverse: every MAIN word gets a station {x, y, size, px, py}
    // (px/py = the previous main station, for its leg); adlibs anchor beneath
    // the station they follow. Seeded per line — every line plots fresh.
    function plot(seedIdx, tokens) {
        const n = tokens.length
        if (n === 0) return []
        const r = rng32((seedIdx + 1) * 2654435761)
        const out = []
        const gap = lyricSize * 0.55
        const rowH = lyricSize * 2.0
        let cx = r() * lyricSize * 0.6
        let rowY = lyricSize * 1.1
        let lastX = -1, lastY = -1
        let zig = r() * 6.28
        for (let i = 0; i < n; i++) {
            const tk = tokens[i]
            if (tk.bg) {
                // a field note under the last station
                out.push({ x: Math.max(0, lastX), y: (lastY < 0 ? rowY : lastY) + lyricSize * 0.85,
                           size: lyricSize * 0.5, px: -1, py: -1 })
                continue
            }
            const factor = r() < 0.22 ? (1.25 + r() * 0.35) : (0.85 + r() * 0.3)
            const fpx = lyricSize * factor
            const wPx = Math.max(fpx * 0.55, tk.text.length * fpx * 0.52)
            if (cx + wPx > boxW && lastX >= 0) {
                cx = r() * lyricSize * 1.2
                rowY += rowH * (0.95 + r() * 0.25)
            }
            zig += 1.1 + r() * 1.3
            const y = rowY + Math.sin(zig) * lyricSize * 0.42
            const x = cx + wPx / 2
            out.push({ x: x, y: y, size: fpx, px: lastX, py: lastY })
            lastX = x; lastY = y
            cx += wPx + gap
        }
        return out
    }

    readonly property var curLayout: plot(engine.activeIndex, engine.tokens)

    // clear a finished line early — the traverse doesn't linger in a gap
    readonly property real lineHoldMs: 350
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // a short blank cut on line change so one traverse is down before the
    // next is plotted
    property bool gate: true
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() { root.gate = false; gateCut.restart() }
        function onOffsetNudged() { offsetOsd.flash() }
    }

    Item {
        id: table
        x: root.boxX
        y: root.boxY
        width: root.boxW
        height: root.boxH
        // the whole traverse condenses/dissolves as one sheet
        opacity: (root.gate && !root.lineExpired && root.engine.tokens.length > 0) ? 1 : 0
        scale: (root.gate && !root.lineExpired) ? 1 : 1.03
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutQuad } }

        Repeater {
            model: root.engine.tokens
            delegate: Item {
                id: wd
                required property int index
                required property var modelData          // {text, bg, mainIdx, t, d}
                readonly property bool bg: modelData.bg
                // touch audioSilent so held-word releases re-evaluate promptly
                readonly property var st: (root.engine.audioSilent,
                                           root.engine.tokenState(index, root.engine.estMs))
                readonly property var p: root.curLayout[index]
                    ? root.curLayout[index]
                    : ({ x: 0, y: 0, size: root.lyricSize, px: -1, py: -1 })
                readonly property bool sung: st.fill >= 1 && !st.active
                readonly property bool reached: st.active || st.fill > 0 || sung
                readonly property real fill: Math.max(0, Math.min(1, st.fill))

                x: 0; y: 0
                width: table.width; height: table.height

                // ── the leg: the pencil line drawn toward this station ─────
                Item {
                    visible: !wd.bg && wd.p.px >= 0
                    x: wd.p.px
                    y: wd.p.py
                    Rectangle {
                        readonly property real dx: wd.p.x - wd.p.px
                        readonly property real dy: wd.p.y - wd.p.py
                        readonly property real len: Math.sqrt(dx * dx + dy * dy)
                        width: len * wd.fill
                        height: 1.2
                        antialiasing: true
                        color: wd.st.active ? root.lampA(0.85) : root.silverA(0.5)
                        transformOrigin: Item.Left
                        rotation: Math.atan2(dy, dx) * 180 / Math.PI
                    }
                }

                // ── the station tick / benchmark ───────────────────────────
                Item {
                    visible: !wd.bg
                    x: wd.p.x
                    y: wd.p.y
                    // waiting: a bare tick
                    Rectangle {
                        x: -0.5; y: 3
                        width: 1; height: 5
                        color: root.silverA(0.35)
                        visible: !wd.sung
                    }
                    // completed: the benchmark triangle lands
                    Canvas {
                        id: bench
                        x: -5; y: 3
                        width: 10; height: 8
                        visible: wd.sung
                        onVisibleChanged: if (visible) { requestPaint(); land.restart() }
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = String(root.silverA(0.75))
                            ctx.lineWidth = 1
                            ctx.beginPath()
                            ctx.moveTo(width / 2, 0.8)
                            ctx.lineTo(width - 0.8, height - 1)
                            ctx.lineTo(0.8, height - 1)
                            ctx.closePath()
                            ctx.stroke()
                        }
                        NumberAnimation { id: land; target: bench; property: "scale"; from: 1.6; to: 1; duration: 180; easing.type: Easing.OutCubic }
                    }
                }

                // ── the word above (or note below) its station ─────────────
                Text {
                    id: wt
                    x: wd.p.x - width / 2
                    y: wd.bg ? wd.p.y : wd.p.y - height + 2
                    text: wd.bg ? ("(" + wd.modelData.text + ")") : wd.modelData.text
                    textFormat: Text.PlainText
                    color: wd.bg ? root.silverA(0.6)
                         : wd.st.active ? root.lamp
                         : wd.sung ? root.silverA(0.8)
                         : root.silverA(0.35)
                    style: Text.Outline
                    styleColor: Qt.rgba(0.01, 0.04, 0.07, 0.55)
                    font.family: root.serif
                    font.pixelSize: wd.p.size
                    font.weight: wd.bg ? Font.Normal : (wd.st.active ? Font.Medium : Font.Light)
                    font.italic: wd.bg
                    font.letterSpacing: 1

                    // condensation: ghost-soft until the pencil reaches it
                    readonly property real cond: wd.bg
                        ? (wd.reached ? 1 : 0)
                        : (wd.st.active || wd.sung ? 1 : 0)
                    opacity: wd.bg ? (wd.reached ? 0.75 : 0)
                           : wd.st.active ? 1
                           : wd.sung ? 0.85
                           : 0.28
                    scale: (1.07 - 0.07 * cond)
                           + ((wd.st.active && !wd.bg && root.engine.audioReady)
                              ? root.engine.audioPulse * 0.05 : 0)
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutQuad } }
                }
                // fog ghost of the crisp word while it's still waiting
                Text {
                    visible: !wd.bg && !wd.st.active && !wd.sung
                    x: wd.p.x - wt.width / 2 - 3
                    y: wt.y - 2
                    text: wd.modelData.text
                    textFormat: Text.PlainText
                    color: root.silverA(0.12)
                    font.family: root.serif
                    font.pixelSize: wd.p.size
                    font.weight: Font.Light
                    font.letterSpacing: 1
                    scale: 1.10
                }
            }
        }
    }

    // status when a track's playing but there's nothing to plot
    Text {
        x: root.boxX
        y: root.boxY
        visible: root.engine.player !== null && root.engine.tokens.length === 0
        text: !root.engine.lyricsLoaded ? "searching…"
              : !root.engine.lyricsSynced ? "no synced lyrics"
              : "▵"
        color: root.silverA(0.7)
        style: Text.Outline
        styleColor: Qt.rgba(0.01, 0.04, 0.07, 0.5)
        font.family: root.mono
        font.pixelSize: Math.round(root.lyricSize * 0.34)
        font.letterSpacing: 4
    }

    // offset OSD — the calibration note
    Text {
        id: offsetOsd
        function flash() { opacity = 1; osdHide.restart() }
        x: root.boxX
        y: root.boxY - root.lyricSize * 1.1
        opacity: 0
        text: "offset " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " ms"
        color: root.lamp
        style: Text.Outline
        styleColor: Qt.rgba(0.01, 0.04, 0.07, 0.6)
        font.family: root.mono
        font.pixelSize: Math.round(root.lyricSize * 0.4)
        font.letterSpacing: 2
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
    }
}
