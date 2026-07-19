import QtQuick
import "chalk.js" as Chalk

// homeroom: the song, written on the air in chalk — STYLING ONLY, the engine
// (MPRIS clock, lyric fetch, per-word pacing) arrives as `engine`.
//
// When a line begins it's already there faintly — penciled in, the way a
// teacher lightly rules a phrase before writing it. As the words are sung
// the bright chalk goes over the sketch: each word fills left-to-right like
// a hand writing it, sitting a little crooked on its own baseline (seeded
// per word — a hand, not a typesetter), with a jittered chalk underline
// growing beneath the word being written. A held note sheds chalk dust. When
// the line completes THE ERASER takes it: a pale smudge sweeps across and
// the words fade behind it. Adlibs are small pink margin notes. The room's
// halo never appears here — chalk is chalk. Click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color chalk: pal.text
    readonly property color pink: pal.magenta
    readonly property color slate: pal.dim
    readonly property string mono: pal.fontMono
    readonly property string hand: "Adwaita Sans"
    function chalkA(a) { return Qt.rgba(chalk.r, chalk.g, chalk.b, a) }
    function pinkA(a)  { return Qt.rgba(pink.r, pink.g, pink.b, a) }

    // deterministic per-word hand: tilt and baseline drop
    function wobble(i, span) {
        let x = Math.imul((i + 13) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (((x >>> 0) / 4294967296) - 0.5) * 2 * span
    }

    // ---- board geometry ----------------------------------------------------
    readonly property real lyricSize: Math.round(34 * pal.uiScale)
    readonly property real rowH: lyricSize * 1.8
    readonly property real boxW: Math.round(root.width * 0.56)
    readonly property real boxX: Math.round((root.width - boxW) / 2)
    readonly property real boxY: Math.round(root.height * 0.34)

    // measure via FontMetrics.advanceWidth(str) — a method call, so the
    // layout binding picks up no spurious property dependencies
    FontMetrics {
        id: fm
        font.family: root.hand
        font.pixelSize: root.lyricSize
        font.weight: Font.Bold
    }
    function measure(word, size) {
        return fm.advanceWidth(word) * (size / lyricSize)
    }

    // words in centered rows, each on its own slightly-wrong baseline
    function layoutLine(toks) {
        const n = toks.length
        if (n === 0) return []
        const gap = lyricSize * 0.42
        const rows = []
        let cur = [], curW = 0
        for (let i = 0; i < n; i++) {
            const f = toks[i].bg ? 0.58 : 1.0
            const word = toks[i].bg ? "(" + toks[i].text + ")" : toks[i].text
            const wPx = measure(word, lyricSize * f)
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
                out[wd.i] = { x: x, y: ri * rowH + wobble(wd.i, 3), size: lyricSize * wd.f,
                              w: wd.w, tilt: wobble(wd.i * 7 + 3, 2.0) }
                x += wd.w + gap
            }
        }
        return out
    }

    readonly property var curLayout: layoutLine(engine.tokens)

    // finished line: hold a breath, then the eraser takes it
    readonly property real lineHoldMs: 380
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // hard cut between lines so only one line is ever on the air
    property bool gate: true
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() { root.gate = false; gateCut.restart() }
        function onOffsetNudged() { offsetOsd.flash() }
    }

    // the eraser sweep on line completion
    property real wipeT: -1
    SequentialAnimation {
        id: wipeAnim
        NumberAnimation { target: root; property: "wipeT"; from: 0; to: 1; duration: 700; easing.type: Easing.InOutQuad }
        PropertyAction { target: root; property: "wipeT"; value: -1 }
    }
    onLineExpiredChanged: if (lineExpired && gate && engine.tokens.length > 0) wipeAnim.restart()

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
                                       : ({ x: 0, y: 0, size: root.lyricSize, w: 40, tilt: 0 })
                readonly property real fill: Math.max(0, Math.min(1, st.fill))

                x: p.x
                y: p.y
                width: p.w
                height: p.size * 1.5
                rotation: p.tilt
                transformOrigin: Item.BottomLeft

                visible: root.gate && root.engine.tokens.length > 0
                opacity: root.lineExpired
                    ? Math.max(0, 1 - Math.max(0, (root.wipeT >= 0 ? root.wipeT : 1) * 1.25 - (p.x / root.boxW) * 0.4))
                    : 1
                Behavior on opacity { enabled: root.wipeT < 0; NumberAnimation { duration: 500 } }

                // penciled-in ghost — the whole word, faint, from the start
                Text {
                    id: ghostText
                    text: wd.word
                    textFormat: Text.PlainText
                    color: wd.bg ? root.pinkA(0.30) : root.chalkA(0.26)
                    font.family: root.hand
                    font.pixelSize: wd.p.size
                    font.weight: Font.Bold
                    font.italic: wd.bg
                }
                // the bright chalk going over it, left to right — being written
                Item {
                    clip: true
                    width: wd.width * wd.fill
                    height: wd.height
                    Text {
                        text: wd.word
                        textFormat: Text.PlainText
                        color: wd.bg ? root.pinkA(0.95) : root.chalkA(0.96)
                        font.family: root.hand
                        font.pixelSize: wd.p.size
                        font.weight: Font.Bold
                        font.italic: wd.bg
                        style: Text.Raised
                        styleColor: root.chalkA(0.18)
                    }
                }

                // the chalk underline growing under the word being written —
                // drawn jittered once, revealed by the clip
                Item {
                    visible: wd.st.active === true && !root.lineExpired
                    y: wd.p.size * 1.18
                    width: wd.width * wd.fill
                    height: 6
                    clip: true
                    Canvas {
                        width: wd.width
                        height: 6
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            Chalk.strokePath(ctx, [[1, 3], [width - 1, 2.4]], {
                                seed: wd.index * 17 + 5,
                                color: String(wd.bg ? root.pinkA(1) : root.chalkA(1)),
                                alpha: 0.8, width: 2.4, dust: 0.10
                            })
                        }
                        Component.onCompleted: requestPaint()
                    }
                }

                // a held note sheds chalk dust
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        id: mote
                        required property int index
                        width: 2; height: 2
                        radius: 1
                        color: root.chalkA(0.7)
                        x: wd.width * (0.25 + index * 0.28)
                        visible: dustAnim.running
                        SequentialAnimation {
                            id: dustAnim
                            running: wd.st.sustain === true && !root.lineExpired && wd.visible
                            loops: Animation.Infinite
                            PropertyAction { target: mote; property: "y"; value: wd.p.size * 1.25 }
                            PropertyAction { target: mote; property: "opacity"; value: 0.8 }
                            ParallelAnimation {
                                NumberAnimation { target: mote; property: "y"; to: wd.p.size * 1.25 + 26; duration: 900 + mote.index * 260; easing.type: Easing.InQuad }
                                NumberAnimation { target: mote; property: "opacity"; to: 0; duration: 900 + mote.index * 260 }
                            }
                        }
                    }
                }
            }
        }

        // the eraser itself, sweeping the board
        Item {
            visible: root.wipeT >= 0
            x: -60 + (region.width + 120) * Math.max(0, root.wipeT)
            y: 0
            height: region.height
            // a dry smear travelling with the eraser
            Rectangle {
                x: -46
                y: root.rowH * 0.1
                width: 90
                height: root.rowH * 1.3
                radius: height / 2
                rotation: -8
                color: root.chalkA(0.09)
            }
            Rectangle {
                x: -30
                y: root.rowH * 0.35
                width: 60
                height: root.rowH * 0.7
                radius: height / 2
                rotation: -8
                color: root.chalkA(0.07)
            }
            // the felt block
            Rectangle {
                x: -14
                y: root.rowH * 0.5
                width: 34; height: 15
                radius: 2
                rotation: -8
                color: root.slate
                Rectangle { width: parent.width; height: 5; radius: 2; color: root.chalkA(0.5) }
            }
        }

        // status while a track plays but nothing is written yet
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            visible: root.engine.player !== null && root.engine.tokens.length === 0
            text: !root.engine.lyricsLoaded ? "…sharpening the chalk"
                  : !root.engine.lyricsSynced ? "nothing on the board for this one"
                  : "·"
            textFormat: Text.PlainText
            color: root.chalkA(0.4)
            font.family: root.hand
            font.pixelSize: Math.round(root.lyricSize * 0.42)
            font.letterSpacing: 2
        }

        // live lyric-offset OSD, flashed on calibration nudges
        Text {
            id: offsetOsd
            function flash() { opacity = 1; osdHide.restart() }
            anchors.horizontalCenter: parent.horizontalCenter
            y: -root.lyricSize * 1.4
            opacity: 0
            text: "offset " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " ms"
            color: root.chalkA(0.85)
            font.family: root.mono
            font.pixelSize: Math.round(root.lyricSize * 0.42)
            font.letterSpacing: 2
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
        }
    }
}
