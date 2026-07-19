import QtQuick

// thicket: the words hide in the leaves — STYLING ONLY, the engine (MPRIS
// clock, lyric fetch, per-word pacing) arrives as `engine`.
//
// The whole line takes cover the moment it's posted: every word is on stage
// but pressed flat under a leaf silhouette, barely a shadow. As the karaoke
// sweep reaches a word its leaf DARTS aside — one quick flick, no fade — and
// the word stands lit: an ember sweep crosses it letter-width by letter-width
// while it's sung, a dapple of warm light pooling under the active word. Sung
// words settle back into shadow grey-green and hold still. A held note keeps
// its dapple burning, swelling on the bass. When the line ends the thicket
// closes: the whole line dims into the underbrush and the next one takes
// cover. Adlibs are whispers — small italic iris-blue asides. Click-through.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color ember: pal.neon
    readonly property color iris: pal.cyan
    readonly property color dapple: pal.amber
    readonly property color leaf: pal.dim
    readonly property color ink: pal.text
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    function emberA(a)  { return Qt.rgba(ember.r, ember.g, ember.b, a) }
    function irisA(a)   { return Qt.rgba(iris.r, iris.g, iris.b, a) }
    function dappleA(a) { return Qt.rgba(dapple.r, dapple.g, dapple.b, a) }
    function leafA(a)   { return Qt.rgba(leaf.r, leaf.g, leaf.b, a) }
    function inkA(a)    { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // ---- geometry -----------------------------------------------------------
    readonly property real lyricSize: Math.round(34 * pal.uiScale)
    readonly property real charW: lyricSize * 0.55       // nominal em — gaps only
    readonly property real rowH: lyricSize * 1.7
    // real advance widths, so wide words can't overlap their neighbours
    FontMetrics { id: fmMain; font.family: root.serif; font.pixelSize: root.lyricSize }
    FontMetrics { id: fmBg; font.family: root.serif; font.pixelSize: root.lyricSize * 0.6; font.italic: true }
    readonly property real boxW: Math.round(root.width * 0.54)
    readonly property real boxX: Math.round((root.width - boxW) / 2)
    readonly property real boxY: Math.round(root.height * 0.62)

    // words in centered rows — a clearing of text
    function layoutLine(toks) {
        const n = toks.length
        if (n === 0) return []
        const gap = charW * 0.9
        const rows = []
        let cur = [], curW = 0
        for (let i = 0; i < n; i++) {
            const f = toks[i].bg ? 0.6 : 1.0
            const word = toks[i].bg ? "(" + toks[i].text + ")" : toks[i].text
            const wPx = Math.max(1, toks[i].bg ? fmBg.advanceWidth(word)
                                              : fmMain.advanceWidth(word))
            if (curW > 0 && curW + gap + wPx > boxW) {
                rows.push({ words: cur, w: curW })
                cur = []; curW = 0
            }
            cur.push({ i: i, w: wPx, f: f })
            curW += (curW > 0 ? gap : 0) + wPx
        }
        if (cur.length) rows.push({ words: cur, w: curW })
        const out = new Array(n)
        for (let ri = 0; ri < rows.length; ri++) {
            const row = rows[ri]
            let x = (boxW - row.w) / 2
            for (let k = 0; k < row.words.length; k++) {
                const wd = row.words[k]
                out[wd.i] = { x: x, y: ri * rowH, size: lyricSize * wd.f, w: wd.w }
                x += wd.w + gap
            }
        }
        return out
    }

    readonly property var curLayout: layoutLine(engine.tokens)

    // finished line: hold, then the thicket closes over it
    readonly property real lineHoldMs: 380
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // hard cut between lines so only one line is ever out of cover
    property bool gate: true
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() { root.gate = false; gateCut.restart() }
        function onOffsetNudged() { offsetOsd.flash() }
    }

    // ---- the clearing -------------------------------------------------------
    Item {
        id: region
        x: root.boxX
        y: root.boxY
        width: root.boxW
        height: root.rowH * 3

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
                                       : ({ x: 0, y: 0, size: root.lyricSize, w: 40 })
                readonly property bool sung: st.fill >= 1 && st.active !== true
                readonly property bool uncovered: st.fill > 0.02 || st.active === true

                x: p.x
                y: p.y
                width: p.w
                height: root.rowH

                visible: root.gate && root.engine.tokens.length > 0
                opacity: root.lineExpired ? 0.22 : 1
                Behavior on opacity { NumberAnimation { duration: 650; easing.type: Easing.OutQuad } }

                // the dapple pooling under the word while it's sung; a held
                // note keeps it burning and it swells on the bass
                Rectangle {
                    anchors.centerIn: wordStack
                    width: wordStack.width + wd.p.size * 1.1
                    height: wd.p.size * 1.5
                    radius: height / 2
                    visible: wd.st.active === true && !root.lineExpired
                    color: "transparent"
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop {
                            position: 0.5
                            color: root.dappleA(0.13 + (root.engine.audioReady ? root.engine.audioPulse * 0.10 : 0)
                                                + (wd.st.sustain === true ? 0.06 : 0))
                        }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                Item {
                    id: wordStack
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: shadowText.implicitWidth
                    height: shadowText.implicitHeight

                    // the word in shadow — what's there before and after
                    Text {
                        id: shadowText
                        text: wd.word
                        textFormat: Text.PlainText
                        color: wd.sung ? root.leafA(1.0) : root.inkA(0.35)
                        font.family: root.serif
                        font.pixelSize: wd.p.size
                        font.italic: wd.bg
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.6)
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                    // the lit word, revealed by the ember sweep
                    Item {
                        clip: true
                        width: Math.round(shadowText.implicitWidth * Math.max(0, Math.min(1, wd.st.fill)))
                        height: shadowText.implicitHeight
                        Text {
                            text: wd.word
                            textFormat: Text.PlainText
                            color: wd.bg ? root.iris : root.ember
                            font.family: root.serif
                            font.pixelSize: wd.p.size
                            font.italic: wd.bg
                            style: Text.Raised
                            styleColor: Qt.rgba(0, 0, 0, 0.6)
                        }
                    }
                }

                // ── the leaf cover: pressed flat over the word, darts aside ──
                Canvas {
                    id: cover
                    anchors.centerIn: wordStack
                    width: wordStack.width + 14
                    height: wd.p.size * 1.1
                    property real t: 0    // 0 = covering, 1 = darted aside
                    visible: t < 1
                    opacity: Math.max(0, 1 - t * 1.6)
                    transform: [
                        Translate { x: -cover.t * cover.width * 0.5; y: -cover.t * cover.height * 0.35 },
                        Rotation { angle: -cover.t * 34; origin.x: 0; origin.y: cover.height / 2 }
                    ]
                    onWidthChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        if (width <= 0 || height <= 0) return
                        const L = width, W = height * 0.48
                        const teal = root.rnd(wd.index * 41 + 6) < 0.35
                        ctx.beginPath()
                        ctx.moveTo(0, height / 2)
                        ctx.quadraticCurveTo(L * 0.42, height / 2 - W, L, height / 2 - W * 0.1)
                        ctx.quadraticCurveTo(L * 0.46, height / 2 + W * 0.9, 0, height / 2)
                        ctx.closePath()
                        ctx.fillStyle = teal ? "rgba(26,48,42,0.94)" : "rgba(10,15,13,0.94)"
                        ctx.fill()
                        // midrib
                        ctx.strokeStyle = teal ? "rgba(70,110,98,0.5)" : String(root.leafA(0.5))
                        ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.moveTo(2, height / 2)
                        ctx.quadraticCurveTo(L * 0.5, height / 2 - W * 0.2, L - 2, height / 2 - W * 0.1)
                        ctx.stroke()
                    }
                    NumberAnimation {
                        id: coverDart
                        target: cover; property: "t"
                        from: 0; to: 1; duration: 210
                        easing.type: Easing.OutQuint
                    }
                }
                onUncoveredChanged: {
                    if (uncovered && !root.lineExpired) coverDart.restart()
                    else if (!uncovered) { coverDart.stop(); cover.t = 0 }
                }
            }
        }

        // status while a track plays but nothing is out of cover
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            visible: root.engine.player !== null && root.engine.tokens.length === 0
            text: !root.engine.lyricsLoaded ? "listening…"
                  : !root.engine.lyricsSynced ? "the brush keeps this one to itself"
                  : "·"
            textFormat: Text.PlainText
            color: root.leafA(1)
            font.family: root.serif
            font.italic: true
            font.pixelSize: Math.round(root.lyricSize * 0.45)
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.5)
        }

        // live lyric-offset OSD, flashed on calibration nudges
        Text {
            id: offsetOsd
            function flash() { opacity = 1; osdHide.restart() }
            anchors.horizontalCenter: parent.horizontalCenter
            y: -root.lyricSize * 1.4
            opacity: 0
            text: "OFFSET " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " MS"
            color: root.ember
            font.family: root.mono
            font.pixelSize: Math.round(root.lyricSize * 0.42)
            font.letterSpacing: 2
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.55)
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
        }
    }
}
