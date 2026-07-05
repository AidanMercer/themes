import QtQuick

// Cyberpunk: Edgerunners kinetic lyrics for the "moon" wallpaper — STYLING ONLY.
//
// All the machinery (MPRIS clock, lyric fetch/cache, per-word karaoke timing,
// silence detection, offset calibration) lives in the shell's LyricsEngine and
// arrives here as `engine`; this file only decides how the words LOOK: the
// active line's words form a tight scattered bunch that jumps around a fixed
// top-right box (clear of the top bar and the mid-left clock), seeded per line
// so each line lands in a fresh arrangement. Active words are full-strength
// neon, adlibs italic cyan, '?' words ripple per-letter.
//
// Engine surface used here: tokens, activeIndex, estMs, tokenState(i, est),
// lineDoneMs, player, lyricsLoaded, lyricsSynced, audioReady/audioSilent/
// audioPulse, offsetMs (+ offsetNudged() for the calibration OSD).
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color neon: pal.neon
    readonly property color cyan: pal.cyan
    readonly property string mono: "Noto Sans Mono"

    // ---- scatter layout (Edgerunners kinetic text) -------------------------
    // Mono font → word width = chars * charW (exact layout). Big + bold.
    property real lyricSize: Math.round((ultrawide ? 58 : 40) * pal.uiScale)
    readonly property real charW: lyricSize * 0.58           // Noto Sans Mono advance

    // fixed bunch box, top-right (clear of the top bar and the mid-left clock).
    // On a 32:9 ultrawide (Samsung G9, aspect ~3.56) a 0.45-wide box spans a huge
    // horizontal stretch, so the scatter sprawls back toward the centre. Detect the
    // ultrawide by aspect ratio (vs a 16:9 laptop ~1.78) and use a narrower box so
    // the words cluster hard against the right edge. The scatter wraps to extra rows
    // when a word exceeds boxW, so a narrower box just stacks taller — safe.
    readonly property real aspect: root.height > 0 ? root.width / root.height : 1.78
    readonly property bool ultrawide: aspect > 2.4
    readonly property real boxW: Math.round(root.width * (ultrawide ? 0.24 : 0.45))
    readonly property real boxH: Math.round(root.height * (ultrawide ? 0.42 : 0.27))
    readonly property real boxX: Math.round(root.width * (ultrawide ? 0.95 : 0.965) - boxW)
    readonly property real boxY: Math.round(root.height * 0.07)

    function rng32(seed) {
        let a = seed >>> 0
        return function () {
            a = (a + 0x6D2B79F5) | 0
            let t = Math.imul(a ^ (a >>> 15), 1 | a)
            t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296
        }
    }

    function collides(rects, x, y, w, h) {
        for (let i = 0; i < rects.length; i++) {
            const o = rects[i]
            if (x < o.x + o.w && x + w > o.x && y < o.y + o.h && y + h > o.y) return true
        }
        return false
    }

    // [{x,y,size}] within the box — a jumping scatter where every word gets its
    // own size (some big, some small) and NO two words overlap: each word prefers
    // its jumping-path spot, then gets pushed clear of the already-placed words.
    // Seeded per line so each line lands in a fresh arrangement.
    function scatter(seedIdx, words) {
        const n = words.length
        if (n === 0) return []
        const r = rng32((seedIdx + 1) * 2654435761)
        const row = lyricSize * 1.15
        let out = [], placed = [], cx = 0, cy = 0
        for (let i = 0; i < n; i++) {
            const factor = r() < 0.25 ? (1.35 + r() * 0.5) : (0.9 + r() * 0.3)   // some words bigger
            const fpx = lyricSize * factor
            const cw = fpx * 0.58
            const wPx = Math.max(cw, words[i].length * cw)
            const hPx = fpx * 1.1
            const pad = 6
            if (cx + wPx > boxW) { cx = r() * boxW * 0.1; cy += row * (0.9 + r() * 0.4) }
            let px = Math.max(0, cx + (r() - 0.5) * cw * 0.5)
            let py = Math.max(0, cy + (r() - 0.5) * row * 0.3)
            let tries = 0
            while (tries < 80 && collides(placed, px - pad, py - pad, wPx + pad * 2, hPx + pad * 2)) {
                py += row * 0.45
                if (py + hPx > boxH) { py = r() * row * 0.4; px += wPx * 0.5 + cw }  // off the bottom → shift right
                tries++
            }
            out.push({ x: px, y: py, size: fpx })
            placed.push({ x: px, y: py, w: wPx, h: hPx })
            cx = px + wPx + cw * (0.6 + r() * 0.8)
            cy = py
            if (r() < 0.2) { cy += row * (0.6 + r() * 0.5); cx = r() * boxW * 0.2 }  // occasional jump down
        }
        return out
    }

    readonly property var curLayout:
        scatter(engine.activeIndex, engine.tokens.map(function (t) { return t.text }))

    // clear a finished line early: once its last word is done plus a short hold,
    // the line fades out instead of lingering through a long gap to the next line.
    readonly property real lineHoldMs: 300
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // brief blank "cut" on each line change so the old line is fully gone before
    // the new one appears — guarantees only one line shows at a time.
    property bool gate: true
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() { root.gate = false; gateCut.restart() }
        function onOffsetNudged() { offsetOsd.flash() }
    }

    // ---- lyric display (one line at a time, scattered top-right) ------------
    // The active line builds up word-by-word as a tight bunch in the top-right box,
    // full-strength neon, big & bold. On a line change it clears and the next line
    // appears in a fresh arrangement. Only ever one line on screen.
    Item {
        id: region
        anchors.fill: parent

        Repeater {
            model: root.engine.tokens
            delegate: Item {
                id: wd
                required property int index
                required property var modelData          // {text, bg, mainIdx, t, d}
                readonly property bool bg: modelData.bg
                // touch audioSilent so a held-word release re-evaluates the instant
                // the silence signal flips, even if estMs is momentarily static.
                readonly property var st: (root.engine.audioSilent,
                                           root.engine.tokenState(index, root.engine.estMs))
                readonly property bool shown: (st.active || st.fill >= 1) && !root.lineExpired && root.gate
                readonly property var p: root.curLayout[index] ? root.curLayout[index] : ({ x: 0, y: 0, size: root.lyricSize })
                readonly property bool ripple: !wd.bg && modelData.text.indexOf("?") !== -1   // ? words ripple
                property real phase: 0

                // adlibs render smaller, dimmer, italic cyan and sit a touch lower,
                // so the main vocal line still scans cleanly above the backing chatter.
                readonly property real sizePx: wd.bg ? wd.p.size * 0.62 : wd.p.size
                readonly property color baseCol: wd.bg ? root.cyan : root.neon
                readonly property real maxOpacity: wd.bg ? 0.7 : 1
                // subtle bass-driven swell on the active main word (no-op without cava)
                readonly property real pulseBoost:
                    (st.active && !st.sustain && !wd.bg && root.engine.audioReady)
                        ? root.engine.audioPulse * 0.06 : 0

                x: root.boxX + p.x
                y: root.boxY + p.y + (wd.bg ? wd.p.size * 0.22 : 0)
                width: wd.ripple ? rippleRow.width : wt.width
                height: wd.ripple ? rippleRow.height : wt.height
                transformOrigin: Item.Center

                // words appear one-by-one as sung; the whole line fades out once
                // it's done (lineExpired) instead of lingering until the next line
                opacity: shown ? wd.maxOpacity : 0
                scale: shown ? (1 + pulseBoost) : 0.85
                Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }
                Behavior on scale  { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                // ripple driver — only for words containing '?'
                NumberAnimation on phase {
                    running: wd.ripple && wd.shown
                    from: 0; to: 6.2832; duration: 1100; loops: Animation.Infinite
                }

                // plain word (also the size reference for the delegate); adlibs keep
                // their parens so they read as backing vocals
                Text {
                    id: wt
                    visible: !wd.ripple
                    text: wd.bg ? ("(" + wd.modelData.text + ")") : wd.modelData.text.toUpperCase()
                    color: wd.baseCol
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                    font.family: root.mono
                    font.pixelSize: wd.sizePx
                    font.weight: wd.bg ? Font.DemiBold : Font.Black
                    font.italic: wd.bg
                    font.letterSpacing: 1
                }
                // rippling word — per-letter travelling sine wave
                Row {
                    id: rippleRow
                    visible: wd.ripple
                    Repeater {
                        model: wd.ripple ? wd.modelData.text.toUpperCase().split("") : []
                        delegate: Text {
                            required property int index
                            required property string modelData
                            text: modelData
                            y: Math.sin(wd.phase + index * 0.6) * (wd.sizePx * 0.18)
                            color: wd.baseCol
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.6)
                            font.family: root.mono
                            font.pixelSize: wd.sizePx
                            font.weight: Font.Black
                            font.letterSpacing: 1
                        }
                    }
                }
            }
        }

        // small status when a track's playing but there's no active lyric word
        Text {
            x: root.boxX
            y: root.boxY
            visible: root.engine.player !== null && root.engine.tokens.length === 0
            text: !root.engine.lyricsLoaded ? "// SYNC…"
                  : !root.engine.lyricsSynced ? "// NO LYRICS"
                  : "♪"
            color: root.neon
            opacity: 0.85
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.6)
            font.family: root.mono
            font.pixelSize: Math.round(root.lyricSize * 0.6)
            font.weight: Font.Black
            font.letterSpacing: 3
        }

        // live offset readout — flashes above the box as you calibrate by ear,
        // then auto-hides. Shown on every monitor since all watch the same offset.
        Text {
            id: offsetOsd
            function flash() { opacity = 1; osdHide.restart() }
            x: root.boxX
            y: root.boxY - root.lyricSize * 0.9
            opacity: 0
            text: "LYRIC OFFSET " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " ms"
            color: root.neon
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.6)
            font.family: root.mono
            font.pixelSize: Math.round(root.lyricSize * 0.45)
            font.weight: Font.Black
            font.letterSpacing: 2
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
        }
    }
}
