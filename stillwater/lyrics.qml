import QtQuick

// stillwater: the words surface on the mirror — STYLING ONLY, the engine
// (MPRIS clock, lyric fetch, per-word pacing) arrives as `engine`.
//
// The active line stands on the wallpaper's real horizon. Unsung words wait
// half-sunken — dim, water-tinted, sitting a little low in the surface. As
// the karaoke sweep reaches each word it RISES out of the seam: lifts level,
// turns crisp warm-white, and gains its reflection below the line — an
// inverted, squashed, dimmed double, deeper rows reflecting deeper, per the
// house law. A held note ripples its reflection side to side. When the line
// is done the water absorbs it: words and doubles sink back into the seam
// together. Adlibs are small twilight side-notes. Click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color lamp: pal.neon
    readonly property color sky: pal.cyan
    readonly property color rose: pal.magenta
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property string serif: "Noto Serif Display"
    readonly property string mono: pal.fontMono
    function lampA(a)  { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function skyA(a)   { return Qt.rgba(sky.r, sky.g, sky.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }

    // ---- geometry: the line the words stand on ------------------------------
    readonly property real lyricSize: Math.round(30 * pal.uiScale)
    readonly property real rowH: lyricSize * 1.55
    readonly property real boxW: Math.round(root.width * 0.52)
    readonly property real boxX: Math.round((root.width - boxW) / 2)
    readonly property real lineY: Math.round(root.height * 0.527)

    // words in centered rows; the LAST row stands on the waterline, earlier
    // rows stack above it (and reflect deeper). serif metrics ~0.5em advance.
    function layoutLine(toks) {
        const n = toks.length
        if (n === 0) return []
        const charW = lyricSize * 0.52
        const gap = charW * 1.1
        const rows = []
        let cur = [], curW = 0
        for (let i = 0; i < n; i++) {
            const f = toks[i].bg ? 0.6 : 1.0
            const chars = toks[i].text.length + (toks[i].bg ? 2 : 0)
            const wPx = Math.max(1, chars) * charW * f
            if (curW > 0 && curW + gap + wPx > boxW) {
                rows.push({ words: cur, w: curW })
                cur = []; curW = 0
            }
            cur.push({ i: i, w: wPx, f: f })
            curW += (curW > 0 ? gap : 0) + wPx
        }
        if (cur.length) rows.push({ words: cur, w: curW })
        const nRows = rows.length
        const out = new Array(n)
        for (let ri = 0; ri < nRows; ri++) {
            const row = rows[ri]
            let x = (boxW - row.w) / 2
            for (let k = 0; k < row.words.length; k++) {
                const wd = row.words[k]
                // dy: how far above the waterline this row stands
                out[wd.i] = { x: x, dy: (nRows - 1 - ri) * rowH, size: lyricSize * wd.f }
                x += wd.w + gap
            }
        }
        return out
    }

    readonly property var curLayout: layoutLine(engine.tokens)

    // finished line: hold briefly, then the water takes it
    readonly property real lineHoldMs: 400
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // hard cut between lines so only one line ever stands on the water
    property bool gate: true
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() { root.gate = false; gateCut.restart() }
        function onOffsetNudged() { offsetOsd.flash() }
    }

    // ---- the mirror stage ---------------------------------------------------
    Item {
        id: region
        x: root.boxX
        y: root.lineY - root.rowH * 3
        width: root.boxW
        height: root.rowH * 3
        // local y of the waterline
        readonly property real ly: root.rowH * 3

        // a faint waterline segment appears under a standing line of words
        Rectangle {
            y: region.ly
            x: -30
            width: region.width + 60
            height: 1
            opacity: (root.gate && root.engine.tokens.length > 0 && !root.lineExpired) ? 0.5 : 0
            Behavior on opacity { NumberAnimation { duration: 700 } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.25; color: root.skyA(0.4) }
                GradientStop { position: 0.75; color: root.skyA(0.4) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Repeater {
            model: root.engine.tokens
            delegate: Item {
                id: wd
                required property int index
                required property var modelData          // {text, bg, mainIdx, t, d}
                readonly property bool bg: modelData.bg
                readonly property string word: bg ? "(" + modelData.text + ")" : modelData.text
                // touch audioSilent so held-word releases re-evaluate promptly
                readonly property var st: (root.engine.audioSilent,
                                           root.engine.tokenState(index, root.engine.estMs))
                readonly property var p: root.curLayout[index] ? root.curLayout[index]
                                       : ({ x: 0, dy: 0, size: root.lyricSize })
                readonly property real fill: Math.max(0, Math.min(1, st.fill))
                // risen: how far out of the water this word is (leads the sweep)
                readonly property real risen: Math.min(1, fill * 2.5)
                // sinking depth while the line is absorbed
                property real sinkY: root.lineExpired ? root.rowH * 0.45 : 0
                Behavior on sinkY { NumberAnimation { duration: 1100; easing.type: Easing.InOutSine } }

                x: p.x
                width: base.width
                height: 1
                visible: root.gate && root.engine.tokens.length > 0
                opacity: root.lineExpired ? 0.0 : 1
                Behavior on opacity { NumberAnimation { duration: 1200; easing.type: Easing.InQuad } }

                // ── above the line: the word, half-sunken until sung ────────
                Text {
                    id: base
                    // feet on its row line; unsung words sit a little low
                    y: region.ly - wd.p.dy - height + (1 - wd.risen) * wd.p.size * 0.22 + wd.sinkY
                    text: wd.word
                    textFormat: Text.PlainText
                    color: root.skyA(0.55)
                    opacity: 0.5 + 0.5 * wd.risen
                    font.family: root.serif
                    font.pixelSize: wd.p.size
                    font.weight: wd.bg ? Font.Normal : Font.Light
                    font.italic: wd.bg
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.28)
                }
                // the crisp lit copy, revealed by the karaoke sweep
                Item {
                    y: base.y
                    width: base.width * wd.fill
                    height: base.height
                    clip: true
                    Text {
                        text: wd.word
                        textFormat: Text.PlainText
                        color: wd.bg ? root.skyA(0.95) : root.lamp
                        font: base.font
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.35)
                    }
                }

                // ── below the line: the reflection, earned by being sung ────
                Text {
                    id: refl
                    // a word dy above the line reflects dy below it
                    y: region.ly + wd.p.dy + 3 + wd.p.size * 0.85 - wd.sinkY * 0.6
                    x: rippleX.x
                    text: wd.word
                    textFormat: Text.PlainText
                    color: wd.bg ? root.skyA(0.8) : root.lampA(0.85)
                    opacity: wd.risen * (0.30 / (1 + wd.p.dy / root.rowH))
                    font: base.font
                    transform: Scale { origin.y: 0; yScale: -0.82 }
                    QtObject { id: rippleX; property real x: 0 }
                    // a held note ripples its double
                    SequentialAnimation {
                        running: wd.st.sustain === true && !root.lineExpired && wd.visible
                        loops: Animation.Infinite
                        onStopped: rippleX.x = 0
                        NumberAnimation { target: rippleX; property: "x"; to: 2.5; duration: 480; easing.type: Easing.InOutSine }
                        NumberAnimation { target: rippleX; property: "x"; to: -2.5; duration: 480; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        // status while a track plays but nothing stands on the water
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: region.ly - root.lyricSize * 1.1
            visible: root.engine.player !== null && root.engine.tokens.length === 0
            text: !root.engine.lyricsLoaded ? "◦ the water is listening"
                  : !root.engine.lyricsSynced ? "◦ no words tonight — just the water"
                  : "◦"
            textFormat: Text.PlainText
            color: root.skyA(0.7)
            font.family: root.mono
            font.pixelSize: Math.round(root.lyricSize * 0.36)
            font.letterSpacing: 4
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.4)
        }

        // live lyric-offset OSD, flashed on calibration nudges
        Text {
            id: offsetOsd
            function flash() { opacity = 1; osdHide.restart() }
            anchors.horizontalCenter: parent.horizontalCenter
            y: region.ly - root.rowH * 2.6
            opacity: 0
            text: "offset " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " ms"
            color: root.lamp
            font.family: root.mono
            font.pixelSize: Math.round(root.lyricSize * 0.42)
            font.letterSpacing: 2
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.5)
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
        }
    }
}
