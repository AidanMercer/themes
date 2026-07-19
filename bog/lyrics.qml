import QtQuick

// bog: the song floats by on the water — STYLING ONLY, the engine (MPRIS
// clock, lyric fetch, per-word pacing) arrives as `engine`.
//
// The active line is laid on the pond as a row of half-sunken words: each
// word waits as a dark waterlogged ghost, low in the water. As it is sung it
// SURFACES — rises a few pixels, and the sunlight wipes across it (karaoke
// fill) until the whole word sits dry and warm on the line, bobbing faintly,
// with its upside-down reflection wavering beneath it (the house rule: what
// floats casts a ghost). A held note pushes slow ripple rings out around its
// word. When the line is done the words take on water and settle back under,
// and a ring blooms where they went down. Adlibs are small moss-green
// murmurs in parens. Folktale pace throughout. Click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color sun: pal.neon
    readonly property color moss: pal.cyan
    readonly property color rust: pal.magenta
    readonly property color reed: pal.dim
    readonly property color straw: pal.text
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"
    readonly property string mono: pal.fontMono
    function sunA(a)   { return Qt.rgba(sun.r, sun.g, sun.b, a) }
    function strawA(a) { return Qt.rgba(straw.r, straw.g, straw.b, a) }
    function reedA(a)  { return Qt.rgba(reed.r, reed.g, reed.b, a) }

    // slow the estimate sweep a touch — nothing hurries here
    Component.onCompleted: engine.perSyllableMs = 250

    // ---- water geometry -----------------------------------------------------
    readonly property real lyricSize: Math.round(34 * ui)
    readonly property real charW: lyricSize * 0.55        // serif estimate
    readonly property real rowH: lyricSize * 1.95
    readonly property real boxW: Math.round(root.width * 0.56)
    readonly property real boxX: Math.round((root.width - boxW) / 2)
    readonly property real boxY: Math.round(root.height * 0.40)

    // words in centered rows — driftwood gathered mid-pond
    function layoutLine(toks) {
        const n = toks.length
        if (n === 0) return []
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
        const out = new Array(n)
        for (let ri = 0; ri < rows.length; ri++) {
            const row = rows[ri]
            let x = (boxW - row.w) / 2
            for (let k = 0; k < row.words.length; k++) {
                const wd = row.words[k]
                out[wd.i] = { x: x, y: ri * rowH, size: lyricSize * wd.f }
                x += wd.w + gap
            }
        }
        return out
    }

    readonly property var curLayout: layoutLine(engine.tokens)

    // finished line: hold a moment, then the words take on water
    readonly property real lineHoldMs: 450
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // hard cut between lines so only one raft of words is ever afloat
    property bool gate: true
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() { root.gate = false; gateCut.restart() }
        function onOffsetNudged() { offsetOsd.flash() }
    }

    // the ring that blooms where a finished line went down
    Canvas {
        id: sinkRing
        property real t: -1
        visible: t >= 0
        width: root.boxW * 0.5
        height: root.rowH
        x: root.boxX + root.boxW * 0.25
        y: root.boxY + root.rowH * 0.2
        onTChanged: requestPaint()
        NumberAnimation {
            id: sinkAnim
            target: sinkRing; property: "t"
            from: 0; to: 1; duration: 2100; easing.type: Easing.OutSine
            onStopped: sinkRing.t = -1
        }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (t < 0) return
            for (let k = 0; k < 3; k++) {
                const tt = (t - k * 0.18) / (1 - k * 0.18)
                if (tt <= 0 || tt >= 1) continue
                const r = (width / 2) * (0.1 + 0.9 * tt)
                ctx.save()
                ctx.translate(width / 2, height / 2)
                ctx.scale(1, 0.22)
                ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
                ctx.restore()
                ctx.strokeStyle = String(root.sunA(0.35 * (1 - tt)))
                ctx.lineWidth = Math.max(0.8, 2 * (1 - tt))
                ctx.stroke()
            }
        }
    }
    onLineExpiredChanged: if (lineExpired && gate && engine.tokens.length > 0) sinkAnim.restart()

    // ---- the water -----------------------------------------------------------
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
                readonly property real fill: Math.max(0, Math.min(1, st.fill || 0))
                readonly property var p: root.curLayout[index] ? root.curLayout[index]
                                       : ({ x: 0, y: 0, size: root.lyricSize })
                readonly property bool sung: fill >= 1

                x: p.x
                y: p.y + (root.lineExpired ? 14 : (1 - fill) * 8)
                Behavior on y { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }
                width: Math.max(1, ghost.implicitWidth)
                height: root.rowH

                visible: root.gate && root.engine.tokens.length > 0
                opacity: root.lineExpired ? 0.22 : 1
                Behavior on opacity { NumberAnimation { duration: 1100; easing.type: Easing.InOutSine } }

                // the surfaced word bobs, gently, only while its line is live
                property real bobY: 0
                SequentialAnimation on bobY {
                    running: wd.sung && !root.lineExpired && wd.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: (wd.index * 733) % 1500 }
                    NumberAnimation { to: 1.6; duration: 2600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -1.6; duration: 2600; easing.type: Easing.InOutSine }
                }

                Item {
                    id: body
                    width: parent.width
                    height: wd.p.size * 1.35
                    transform: Translate { y: wd.bobY }

                    // the waterlogged ghost, waiting to be sung
                    Text {
                        id: ghost
                        text: wd.word
                        textFormat: Text.PlainText
                        color: root.reedA(0.95)
                        opacity: 0.5
                        font.family: root.serif
                        font.italic: wd.bg
                        font.weight: wd.bg ? Font.Normal : Font.Medium
                        font.pixelSize: wd.p.size
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.5)
                    }
                    // the sunlight wipes across as the word is sung
                    Item {
                        clip: true
                        width: Math.round(ghost.implicitWidth * wd.fill)
                        height: body.height
                        Text {
                            text: wd.word
                            textFormat: Text.PlainText
                            color: wd.bg ? root.moss : root.strawA(0.97)
                            font: ghost.font
                            style: Text.Raised
                            styleColor: Qt.rgba(0, 0, 0, 0.55)
                        }
                    }

                    // the reflection: the word upside down beneath its waterline
                    Text {
                        y: body.height + 1
                        text: wd.word
                        textFormat: Text.PlainText
                        color: wd.bg ? root.moss : root.strawA(0.97)
                        font: ghost.font
                        opacity: 0.13 * wd.fill
                        transform: Scale { origin.y: 0; yScale: -1 }
                    }
                }

                // a held note pushes slow rings out around its word
                Canvas {
                    id: holdRing
                    anchors.horizontalCenter: body.horizontalCenter
                    y: wd.p.size * 0.55
                    width: Math.max(40, body.width * 1.4)
                    height: wd.p.size * 1.1
                    property real t: 0
                    visible: wd.st.sustain === true && !root.lineExpired
                    onTChanged: requestPaint()
                    NumberAnimation on t {
                        from: 0; to: 1; duration: 1700
                        loops: Animation.Infinite
                        running: holdRing.visible
                    }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        if (!visible) return
                        for (let k = 0; k < 2; k++) {
                            const tt = (t + k * 0.5) % 1
                            const r = (width / 2) * (0.2 + 0.8 * tt)
                            ctx.save()
                            ctx.translate(width / 2, height / 2)
                            ctx.scale(1, 0.26)
                            ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
                            ctx.restore()
                            ctx.strokeStyle = String(root.sunA(0.30 * (1 - tt)))
                            ctx.lineWidth = 1.2
                            ctx.stroke()
                        }
                    }
                }
            }
        }

        // status while a track plays but nothing is afloat
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            visible: root.engine.player !== null && root.engine.tokens.length === 0
            text: !root.engine.lyricsLoaded ? "≈ the pond is listening"
                  : !root.engine.lyricsSynced ? "≈ no words on this water"
                  : "≈"
            textFormat: Text.PlainText
            color: root.reedA(1)
            font.family: root.serif
            font.italic: true
            font.pixelSize: Math.round(root.lyricSize * 0.45)
            font.letterSpacing: 2
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
            text: "the current runs " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " ms"
            color: root.sun
            font.family: root.serif
            font.italic: true
            font.pixelSize: Math.round(root.lyricSize * 0.5)
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.55)
            Behavior on opacity { NumberAnimation { duration: 300 } }
            Timer { id: osdHide; interval: 1400; onTriggered: offsetOsd.opacity = 0 }
        }
    }
}
