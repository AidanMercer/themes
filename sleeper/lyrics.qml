import QtQuick

// sleeper: the words hang in the window glass — STYLING ONLY, the engine
// (MPRIS clock, lyric fetch, per-word pacing) arrives as `engine`.
//
// The active line is posted in the lower half of the window as unlit ghost
// letters, the murky green of the city outside. As the words are sung, a
// warm lamp passes across them: the karaoke fill is a band of tea-amber
// light crossing each word left to right (a streetlight sweeping the
// compartment), and what the lamp has touched keeps a low amber afterglow
// that slowly cools back toward the glass. A held note is the lamp
// lingering — the glow breathes, rocking with the carriage. The whole line
// sways on the shared bogie rhythm while the music plays. When the line is
// done the light moves on and the words sink back into the window's dark.
// Adlibs are small moon-pale asides. Click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color green: pal.neon
    readonly property color moonpale: pal.cyan
    readonly property color tea: pal.amber
    readonly property color wood: pal.dim
    readonly property color linen: pal.text
    readonly property string mono: pal.fontMono
    function colA(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // ── the bogie clock (shared wall-time phase — see DESIGN.md) ───────────
    readonly property real swayPeriod: 4200
    property real swayPhase: 0
    property real swayAmp: engine.playing ? 1 : 0
    Behavior on swayAmp { NumberAnimation { duration: 1400; easing.type: Easing.InOutSine } }
    Timer {
        interval: 50; repeat: true
        running: root.engine.playing === true || root.swayAmp > 0.01
        onTriggered: root.swayPhase = ((Date.now() % root.swayPeriod) / root.swayPeriod) * 2 * Math.PI
    }
    readonly property real rock: Math.sin(swayPhase) * swayAmp
    readonly property real heave: Math.sin(swayPhase * 2 + 0.7) * swayAmp

    // ---- window geometry ---------------------------------------------------
    readonly property real lyricSize: Math.round(28 * pal.uiScale)
    readonly property real charW: lyricSize * 0.62          // mono advance
    readonly property real rowH: lyricSize * 1.7
    readonly property real boxW: Math.round(root.width * 0.44)
    readonly property real boxX: Math.round(root.width * 0.455 - boxW / 2)
    readonly property real boxY: Math.round(root.height * 0.56)

    // words in orderly centered rows, hanging in the glass
    function layoutLine(toks) {
        const n = toks.length
        if (n === 0) return []
        const gap = charW * 1.0
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

    // finished line: the lamp moves on, the words cool back into the glass
    readonly property real lineHoldMs: 420
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // hard cut between lines so only one is ever in the glass
    property bool gate: true
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() { root.gate = false; gateCut.restart() }
        function onOffsetNudged() { offsetOsd.flash() }
    }

    // ---- the window --------------------------------------------------------
    Item {
        id: region
        x: root.boxX
        y: root.boxY + root.heave * 2
        width: root.boxW
        height: root.rowH * 3
        rotation: root.rock * 0.4
        transformOrigin: Item.Center

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
                readonly property real fillW: Math.max(0, Math.min(1, st.fill)) * width
                readonly property bool sung: st.fill >= 1 && st.active !== true

                x: p.x
                y: p.y
                width: word.length * p.size * 0.62
                height: root.rowH

                visible: root.gate && root.engine.tokens.length > 0
                opacity: root.lineExpired ? 0.22 : 1
                Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.OutQuad } }

                // ghost letters — the unlit word, city-green in the glass
                Text {
                    id: ghost
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: wd.word
                    textFormat: Text.PlainText
                    color: root.colA(root.green, 0.42)
                    font.family: root.mono
                    font.pixelSize: wd.p.size
                    font.weight: Font.Light
                    font.italic: wd.bg
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.45)
                }

                // what the lamp has touched — clipped to the karaoke fill
                Item {
                    width: wd.fillW
                    height: parent.height
                    clip: true
                    Text {
                        width: wd.width
                        horizontalAlignment: Text.AlignHCenter
                        text: wd.word
                        textFormat: Text.PlainText
                        color: wd.bg ? root.colA(root.moonpale, 0.9)
                             : wd.sung ? root.colA(root.tea, 0.62)   // cooled afterglow
                                       : root.colA(root.tea, 0.98)
                        Behavior on color { ColorAnimation { duration: 1400 } }
                        font.family: root.mono
                        font.pixelSize: wd.p.size
                        font.weight: Font.Normal
                        font.italic: wd.bg
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.5)
                    }
                }

                // the lamp itself: a narrow warm band at the fill's leading edge
                Rectangle {
                    visible: wd.st.active === true && !root.lineExpired
                    x: wd.fillW - width / 2
                    y: -wd.p.size * 0.25
                    width: wd.p.size * 1.1
                    height: wd.p.size * 1.7
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.colA(root.tea, 0) }
                        GradientStop { position: 0.5; color: root.colA(root.tea, 0.22) }
                        GradientStop { position: 1.0; color: root.colA(root.tea, 0) }
                    }
                }

                // a held note: the lamp lingers and breathes — rocking, not bouncing
                Rectangle {
                    id: linger
                    visible: wd.st.sustain === true && !root.lineExpired
                    anchors.centerIn: parent
                    width: parent.width + wd.p.size * 1.2
                    height: wd.p.size * 2
                    radius: height / 2
                    color: "transparent"
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.colA(root.tea, 0) }
                        GradientStop { position: 0.5; color: root.colA(root.tea, 0.10) }
                        GradientStop { position: 1.0; color: root.colA(root.tea, 0) }
                    }
                    SequentialAnimation on opacity {
                        running: linger.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.45; duration: 1000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        // status while a track plays but nothing is in the glass
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            visible: root.engine.player !== null && root.engine.tokens.length === 0
            text: !root.engine.lyricsLoaded ? "· finding lyrics ·"
                  : !root.engine.lyricsSynced ? "· no synced lyrics ·"
                  : "·"
            textFormat: Text.PlainText
            color: root.colA(root.green, 0.5)
            font.family: root.mono
            font.pixelSize: Math.round(root.lyricSize * 0.4)
            font.letterSpacing: 3
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.5)
        }

        // live lyric-offset OSD, flashed on calibration nudges
        Text {
            id: offsetOsd
            function flash() { opacity = 1; osdHide.restart() }
            anchors.horizontalCenter: parent.horizontalCenter
            y: -root.lyricSize * 1.5
            opacity: 0
            text: "· " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " ms ·"
            color: root.tea
            font.family: root.mono
            font.pixelSize: Math.round(root.lyricSize * 0.45)
            font.letterSpacing: 2
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.55)
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
        }
    }
}
