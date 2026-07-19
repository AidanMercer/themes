import QtQuick

// downpour: the words are finger-written on the fogged glass — STYLING ONLY,
// the engine (MPRIS clock, lyric fetch, per-word pacing) arrives as `engine`.
//
// The active line waits on the pane as the faintest ghost — the shape a
// finger left last time the glass fogged. As each word is sung the karaoke
// sweep writes it: a pale fingertip smear moves through the word and the
// letters surface behind it, light serif, lowercase night. A held note
// gathers a droplet beneath the word that stretches until the voice lets it
// go and it falls. When the line completes the glass takes it back — the
// writing re-mists to almost nothing before the next line is breathed on.
// Adlibs are written smaller and colder, in parentheses. Click-through.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color paneLight: pal.neon
    readonly property color skinLight: pal.cyan
    readonly property color warmth: pal.magenta
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property string serif: "Noto Serif"
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function paneA(a)  { return Qt.rgba(paneLight.r, paneLight.g, paneLight.b, a) }
    function skinA(a)  { return Qt.rgba(skinLight.r, skinLight.g, skinLight.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }

    // ---- pane geometry ------------------------------------------------------
    readonly property real lyricSize: Math.round(34 * pal.uiScale)
    readonly property real charW: lyricSize * 0.60          // generous advance —
                                                            // written words breathe
    readonly property real rowH: lyricSize * 1.8
    readonly property real boxW: Math.round(root.width * 0.56)
    readonly property real boxX: Math.round((root.width - boxW) / 2)
    readonly property real boxY: Math.round(root.height * 0.38)

    // words in centered rows — handwriting keeps its line
    function layoutLine(toks) {
        const n = toks.length
        if (n === 0) return []
        const gap = charW * 1.05
        const rows = []
        let cur = [], curW = 0
        for (let i = 0; i < n; i++) {
            const f = toks[i].bg ? 0.60 : 1.0
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

    // finished line: hold a moment, then the glass fogs back over it
    readonly property real lineHoldMs: 420
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // hard cut between lines so only one message is ever on the glass
    property bool gate: true
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() { root.gate = false; gateCut.restart() }
        function onOffsetNudged() { offsetOsd.flash() }
    }

    // ---- the writing --------------------------------------------------------
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
                                       : ({ x: 0, y: 0, size: root.lyricSize })
                readonly property real fill: Math.max(0, Math.min(1, st.fill))
                readonly property real wordW: word.length * wd.p.size * 0.60

                x: p.x
                y: p.y
                width: wordW
                height: root.rowH

                visible: root.gate && root.engine.tokens.length > 0
                opacity: root.lineExpired ? 0.14 : 1
                Behavior on opacity { NumberAnimation { duration: 1100; easing.type: Easing.InOutSine } }

                // the ghost the last fogging left — the line's shape, barely
                Text {
                    text: wd.word
                    textFormat: Text.PlainText
                    color: root.inkA(0.11)
                    font.family: root.serif
                    font.weight: Font.Light
                    font.italic: wd.bg
                    font.pixelSize: wd.p.size
                }

                // the written letters, surfacing behind the fingertip
                Item {
                    width: Math.max(0, wd.fill * wd.wordW)
                    height: wd.p.size * 1.5
                    clip: true
                    Text {
                        text: wd.word
                        textFormat: Text.PlainText
                        color: wd.bg ? root.skinA(0.85) : root.inkA(0.95)
                        font.family: root.serif
                        font.weight: Font.Light
                        font.italic: wd.bg
                        font.pixelSize: wd.p.size
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.35)
                    }
                }

                // the fingertip smear, mid-stroke
                Rectangle {
                    visible: wd.st.active === true && wd.fill > 0.02 && wd.fill < 0.98 && !root.lineExpired
                    x: wd.fill * wd.wordW - width / 2
                    y: -wd.p.size * 0.08
                    width: wd.p.size * 0.26
                    height: wd.p.size * 1.35
                    radius: width / 2
                    opacity: 0.6
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.inkA(0.0) }
                        GradientStop { position: 0.45; color: root.inkA(0.32) }
                        GradientStop { position: 1.0; color: root.inkA(0.0) }
                    }
                }

                // a held note gathers a droplet under the word
                Item {
                    x: wd.wordW * 0.5
                    y: wd.p.size * 1.32
                    Rectangle {
                        id: holdBead
                        x: -width / 2
                        width: 5.5
                        height: wd.st.sustain === true && !root.lineExpired ? 16 : 0
                        radius: 3
                        color: root.paneA(0.7)
                        Behavior on height { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }
                        Rectangle {
                            x: 1; y: 2
                            width: 1.6; height: 2.2; radius: 1
                            color: root.inkA(0.8)
                            visible: holdBead.height > 6
                        }
                    }
                }
            }
        }

        // status while a track plays but nothing is written
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            visible: root.engine.player !== null && root.engine.tokens.length === 0
            text: !root.engine.lyricsLoaded ? "listening through the rain…"
                  : !root.engine.lyricsSynced ? "no words for this one — just the rain"
                  : "· · ·"
            textFormat: Text.PlainText
            color: root.inkA(0.34)
            font.family: root.serif
            font.italic: true
            font.pixelSize: Math.round(root.lyricSize * 0.44)
            font.letterSpacing: 2
        }

        // live lyric-offset OSD, written small on a calibration nudge
        Text {
            id: offsetOsd
            function flash() { opacity = 1; osdHide.restart() }
            anchors.horizontalCenter: parent.horizontalCenter
            y: -root.lyricSize * 1.5
            opacity: 0
            text: "offset " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " ms"
            color: root.paneA(0.9)
            font.family: root.serif
            font.italic: true
            font.pixelSize: Math.round(root.lyricSize * 0.42)
            font.letterSpacing: 2
            Behavior on opacity { NumberAnimation { duration: 300 } }
            Timer { id: osdHide; interval: 1300; onTriggered: offsetOsd.opacity = 0 }
        }
    }
}
