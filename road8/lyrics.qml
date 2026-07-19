import QtQuick

// road8: the variable-message sign over the road — STYLING ONLY, the engine
// (MPRIS clock, lyric fetch, per-word pacing) arrives as `engine`.
//
// The whole active line is posted on the sign the moment it begins, but
// unpowered: every letter sits there as a dark ghost segment, the way an LED
// road sign shows its unlit matrix. As the words are sung the karaoke sweep
// powers them up letter by letter — each one snaps from ghost-slate to city
// amber with a fast overbright flash, and a hard segment cursor burns under
// the word currently being written. A held note flashes its whole word like
// hazard lights, in hard steps, no easing. When the line completes a pair of
// taillight pixels dashes across the sign and the message dims to ghosts
// until the next one is posted. Adlibs are small starlight side-notes.
// Click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color amber: pal.neon
    readonly property color starlight: pal.cyan
    readonly property color tail: pal.magenta
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property string mono: pal.fontMono
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }

    // ---- sign geometry ------------------------------------------------------
    readonly property real lyricSize: Math.round(30 * pal.uiScale)
    readonly property real charW: lyricSize * 0.62          // mono advance
    readonly property real rowH: lyricSize * 1.75
    readonly property real boxW: Math.round(root.width * 0.58)
    readonly property real boxX: Math.round((root.width - boxW) / 2)
    readonly property real boxY: Math.round(root.height * 0.40)

    // words in orderly centered rows — a sign, not a scatter
    function layoutLine(toks) {
        const n = toks.length
        if (n === 0) return []
        const gap = charW * 1.0
        const rows = []
        let cur = [], curW = 0
        for (let i = 0; i < n; i++) {
            const f = toks[i].bg ? 0.62 : 1.0
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

    // finished line: hold briefly, then dim back to ghost segments
    readonly property real lineHoldMs: 350
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // hard cut between lines so only one message is ever posted
    property bool gate: true
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() { root.gate = false; gateCut.restart() }
        function onOffsetNudged() { offsetOsd.flash() }
    }

    // the line-complete taillight dash
    property real streakT: -1
    SequentialAnimation {
        id: streakAnim
        NumberAnimation { target: root; property: "streakT"; from: 0; to: 1; duration: 800; easing.type: Easing.InOutQuad }
        PropertyAction { target: root; property: "streakT"; value: -1 }
    }
    onLineExpiredChanged: if (lineExpired && gate && engine.tokens.length > 0) streakAnim.restart()

    // ---- the sign -----------------------------------------------------------
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
                readonly property int nCh: word.length
                // touch audioSilent so held-word releases re-evaluate promptly
                readonly property var st: (root.engine.audioSilent,
                                           root.engine.tokenState(index, root.engine.estMs))
                readonly property var p: root.curLayout[index] ? root.curLayout[index]
                                       : ({ x: 0, y: 0, size: root.lyricSize })
                readonly property real cw: p.size * 0.62
                readonly property int litCount: Math.max(0, Math.min(nCh, Math.round(st.fill * nCh)))

                x: p.x
                y: p.y
                width: nCh * cw
                height: root.rowH

                visible: root.gate && root.engine.tokens.length > 0
                opacity: root.lineExpired ? 0.30 : 1
                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutQuad } }

                // the letters: ghost segments that power up as they're swept
                Repeater {
                    model: wd.nCh
                    delegate: Item {
                        id: ch
                        required property int index
                        readonly property bool lit: index < wd.litCount
                        x: index * wd.cw
                        width: wd.cw
                        height: wd.p.size * 1.3

                        // overbright flash the instant a segment powers on
                        Text {
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter
                            text: ch.text_
                            textFormat: Text.PlainText
                            color: root.ink
                            font: seg.font
                            opacity: 0
                            SequentialAnimation on opacity {
                                id: flash
                                running: false
                                PropertyAction { value: 0.9 }
                                PauseAnimation { duration: 70 }
                                PropertyAction { value: 0 }
                            }
                        }
                        readonly property string text_: wd.word.charAt(index)
                        onLitChanged: if (lit && !root.lineExpired) flash.restart()

                        Text {
                            id: seg
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter
                            text: ch.text_
                            textFormat: Text.PlainText
                            color: ch.lit ? (wd.bg ? root.starlight : root.amber)
                                          : root.slateA(0.9)
                            opacity: ch.lit ? 1 : 0.38
                            font.family: root.mono
                            font.pixelSize: wd.p.size
                            font.weight: Font.Bold
                            font.italic: wd.bg
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.55)
                        }
                    }
                }

                // the segment cursor burning under the word being written
                Rectangle {
                    visible: wd.st.active === true && !root.lineExpired
                    x: 0
                    y: wd.p.size * 1.38
                    height: Math.max(2, wd.p.size * 0.10)
                    width: wd.litCount * wd.cw       // grows in whole segments
                    color: wd.bg ? root.starlight : root.amber
                }

                // a held note runs its hazards: hard on-off, no easing
                SequentialAnimation {
                    id: hazard
                    running: wd.st.sustain === true && !root.lineExpired
                    loops: Animation.Infinite
                    PropertyAction { target: wd; property: "hazardDim"; value: true }
                    PauseAnimation { duration: 300 }
                    PropertyAction { target: wd; property: "hazardDim"; value: false }
                    PauseAnimation { duration: 300 }
                    onStopped: wd.hazardDim = false
                }
                property bool hazardDim: false
                scale: hazardDim ? 0.985 : 1
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    z: -1
                    color: "transparent"
                    border.width: 2
                    border.color: root.amberA(wd.hazardDim ? 0.0 : 0.35)
                    visible: wd.st.sustain === true && !root.lineExpired
                }
            }
        }

        // the line-complete taillight pair, dashing across the sign
        Item {
            visible: root.streakT >= 0
            x: Math.round((-40 + (region.width + 80) * Math.max(0, root.streakT)) / 8) * 8
            y: region.height * 0.30
            Rectangle { x: 0; width: 6; height: 6; color: root.tail }
            Rectangle { x: 10; width: 6; height: 6; color: root.tail }
        }

        // status while a track plays but nothing is posted
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            visible: root.engine.player !== null && root.engine.tokens.length === 0
            text: !root.engine.lyricsLoaded ? "▪ TUNING…"
                  : !root.engine.lyricsSynced ? "▪ NO SIGNAL ON THIS ROAD"
                  : "▪"
            textFormat: Text.PlainText
            color: root.slateA(1)
            font.family: root.mono
            font.pixelSize: Math.round(root.lyricSize * 0.42)
            font.letterSpacing: 4
            style: Text.Outline
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
            color: root.amber
            font.family: root.mono
            font.pixelSize: Math.round(root.lyricSize * 0.5)
            font.letterSpacing: 2
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.55)
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
        }
    }
}
