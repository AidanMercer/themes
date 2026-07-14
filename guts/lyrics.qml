import QtQuick

// guts: ink karaoke — STYLING ONLY, the engine lives in the shell.
//
// The active line is stamped word-by-word into the empty white sky on the
// left, below the clock: heavy brush-serif words, each landing with a
// stamp-down (scale snap + a breath of rotation), laid out in a flowing
// hand-set scatter seeded per line — some words cut large, all slightly
// off-baseline and off-angle like hand lettering. The karaoke sweep is
// blood bleeding through the ink left-to-right (engine.tokenState fill);
// held notes tremble like a straining grip; finished words spatter a
// fleck or two and dry from red to a dead gray. Adlibs are small gray
// whispers in parens. One line on screen, ever.
//
// Staging: a CHORUS is cut larger and claims the center of the paper, the
// sword falling across the stage as it enters. The blood throbs with the
// kick drum — the Brand hearing the battle. In instrumental breaks the
// quiet slash-mark waits, and three drops of blood dry one by one as the
// verse returns. No album-art tint here on purpose: this world is
// monochrome with a single drop of blood, and the drop stays blood.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color ink:   pal.text
    readonly property color blood: pal.neon
    readonly property color fresh: pal.magenta
    readonly property color dried: pal.amber
    readonly property color halft: pal.dim
    readonly property string serif: "Noto Serif Display"
    function inkA(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    // the sky under the clock — left half of the screen. A chorus (warcry)
    // is cut ~30% larger and claims the center of the paper; the layout is
    // per-line, so the gate's blank beat hides the move.
    readonly property bool warcry: engine.inChorus
    property real lyricSize: Math.round(46 * pal.uiScale)
    readonly property real boxX: Math.round(root.width * 0.055)
    readonly property real boxY: Math.round(root.height * 0.44)
    readonly property real boxW: Math.round(root.width * 0.38)
    readonly property real boxH: Math.round(root.height * 0.34)
    readonly property real boxXNow: warcry ? Math.round(root.width * 0.26) : boxX
    readonly property real boxYNow: warcry ? Math.round(root.height * 0.36) : boxY
    readonly property real boxWNow: warcry ? Math.round(root.width * 0.48) : boxW

    // the Brand throbs with the drum
    property real beatKick: 0
    NumberAnimation { id: beatKickAnim; target: root; property: "beatKick"; from: 1; to: 0; duration: 190; easing.type: Easing.OutQuad }

    // the sword falls on a chorus entry: one diagonal cut across the stage
    property real slashT: -1
    SequentialAnimation {
        id: slashAnim
        NumberAnimation { target: root; property: "slashT"; from: 0; to: 1; duration: 380; easing.type: Easing.OutCubic }
        PropertyAction { target: root; property: "slashT"; value: -1 }
    }

    function rng32(seed) {
        let a = seed >>> 0
        return function () {
            a = (a + 0x6D2B79F5) | 0
            let t = Math.imul(a ^ (a >>> 15), 1 | a)
            t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296
        }
    }

    // hand-set flow: words run left→right, wrap inside the box, each with its
    // own cut size, baseline drift and tilt. Seeded per line index. A warcry
    // line is set from a bigger base inside the wider center box.
    function handSet(seedIdx, words, cry) {
        const n = words.length
        if (n === 0) return []
        const r = rng32((seedIdx + 1) * 2654435761)
        const base = lyricSize * (cry ? 1.3 : 1)
        const bw = cry ? boxWNow : boxW
        const row = base * 1.22
        const out = []
        let x = 0, y = 0
        for (let i = 0; i < n; i++) {
            const big = r() < 0.18
            const factor = big ? (1.35 + r() * 0.4) : (0.88 + r() * 0.28)
            const fpx = base * factor
            const wPx = Math.max(fpx * 0.6, words[i].length * fpx * 0.56)
            if (x > 0 && x + wPx > bw) {
                x = r() * base * 0.5
                y += row * (0.95 + r() * 0.3)
            }
            out.push({
                x: x,
                y: y + (r() - 0.5) * base * 0.22,
                size: fpx,
                rot: (r() - 0.5) * 7,
                big: big
            })
            x += wPx + fpx * 0.30
        }
        return out
    }

    readonly property var curLayout:
        handSet(engine.activeIndex, engine.tokens.map(function (t) { return t.text }),
                engine.inChorus)

    // clear a finished line after a short hold instead of letting it linger
    readonly property real lineHoldMs: 350
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // a blank beat between lines so only one line ever shows
    property bool gate: true
    readonly property bool countdownOn:
        engine.player !== null && engine.lyricsSynced && engine.playing
        && engine.nextLineInMs >= 0 && engine.nextLineInMs < 3200
        && (engine.inInterlude || engine.activeIndex < 0)
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() {
            root.gate = false; gateCut.restart()
            if (root.engine.inChorus) slashAnim.restart()   // the sword falls
        }
        function onOffsetNudged() { offsetOsd.flash() }
        // the Brand throbs on the kick while words stand on the paper
        function onBeat() { if (root.gate && !root.lineExpired) beatKickAnim.restart() }
    }

    Item {
        anchors.fill: parent

        Repeater {
            model: root.engine.tokens
            delegate: Item {
                id: wd
                required property int index
                required property var modelData        // {text, bg, mainIdx, t, d}
                readonly property bool bg: modelData.bg
                // touch audioSilent so held releases re-evaluate on the flip
                readonly property var st: (root.engine.audioSilent,
                                           root.engine.tokenState(index, root.engine.estMs))
                readonly property bool shown: (st.active || st.fill >= 1) && !root.lineExpired && root.gate
                readonly property bool done: st.fill >= 1 && !st.active
                readonly property var p: root.curLayout[index]
                    ? root.curLayout[index] : ({ x: 0, y: 0, size: root.lyricSize, rot: 0, big: false })

                readonly property real sizePx: wd.bg ? wd.p.size * 0.58 : wd.p.size
                readonly property string shownText: wd.bg ? "(" + modelData.text + ")" : modelData.text

                x: root.boxXNow + p.x + trembleX
                y: root.boxYNow + p.y + (wd.bg ? wd.p.size * 0.30 : 0) + trembleY
                width: baseText.implicitWidth
                height: baseText.implicitHeight
                rotation: p.rot
                transformOrigin: Item.Center
                // the Brand's throb: the word being sung pulses on the kick
                transform: Scale {
                    origin.x: wd.width / 2
                    origin.y: wd.height / 2
                    xScale: 1 + (wd.st.active && !wd.bg ? root.beatKick * 0.045 : 0)
                    yScale: 1 + (wd.st.active && !wd.bg ? root.beatKick * 0.045 : 0)
                }

                // the stamp-down
                opacity: shown ? (wd.bg ? 0.62 : 1) : 0
                scale: shown ? 1 : 1.45
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                Behavior on scale  { NumberAnimation { duration: 190; easing.type: Easing.OutBack } }

                // straining-grip tremble on held notes
                readonly property bool trembling: st.active && st.sustain && !wd.bg
                property real phase: 0
                readonly property real trembleX: trembling ? Math.sin(phase * 12.7) * 1.5 : 0
                readonly property real trembleY: trembling ? Math.cos(phase * 16.3) * 1.2 : 0
                NumberAnimation on phase {
                    running: wd.trembling && wd.shown
                    from: 0; to: 6.2832; duration: 700; loops: Animation.Infinite
                }

                // ink base — dries to a dead gray once the word is spent
                Text {
                    id: baseText
                    text: wd.shownText
                    textFormat: Text.PlainText
                    color: wd.bg ? root.halft : (wd.done ? Qt.rgba(root.halft.r, root.halft.g, root.halft.b, 1) : root.ink)
                    font.family: root.serif
                    font.pixelSize: wd.sizePx
                    font.weight: wd.bg ? Font.DemiBold : Font.Black
                    font.italic: wd.bg
                    style: Text.Outline
                    styleColor: Qt.rgba(root.pal.glass.r, root.pal.glass.g, root.pal.glass.b, 0.55)
                    Behavior on color { ColorAnimation { duration: 700 } }
                }

                // the blood bleeding through, left to right
                Item {
                    clip: true
                    width: baseText.implicitWidth * Math.max(0, Math.min(1, wd.st.fill))
                    height: baseText.implicitHeight
                    visible: !wd.bg && wd.st.fill > 0.01
                    Text {
                        text: wd.shownText
                        textFormat: Text.PlainText
                        color: wd.done ? root.dried : root.fresh
                        font.family: root.serif
                        font.pixelSize: wd.sizePx
                        font.weight: Font.Black
                        Behavior on color { ColorAnimation { duration: 900 } }
                    }
                }

                // spatter as a big word lands done
                Repeater {
                    model: (wd.p.big && !wd.bg) ? 3 : 0
                    Rectangle {
                        required property int index
                        readonly property real sd: (index + 1) * 0.37
                        x: baseText.implicitWidth * (0.75 + sd * 0.4) % Math.max(1, baseText.implicitWidth)
                        y: -4 - index * 5
                        width: (2.5 - index * 0.5) * root.pal.uiScale
                        height: width
                        radius: width / 2
                        color: index === 0 ? root.fresh : root.ink
                        opacity: wd.done && wd.shown ? 0.7 - index * 0.15 : 0
                        Behavior on opacity { NumberAnimation { duration: 500 } }
                    }
                }
            }
        }

        // the cut itself — a diagonal blood line flashing across a chorus entry
        Rectangle {
            visible: root.slashT >= 0
            x: root.boxXNow + root.boxWNow * 0.5 - width / 2
            y: root.boxYNow + root.boxH * 0.30
            width: (root.boxWNow * 1.15) * Math.min(1, Math.max(0, root.slashT) * 1.6)
            height: Math.round(3 * root.pal.uiScale)
            rotation: -32
            transformOrigin: Item.Center
            color: root.fresh
            opacity: root.slashT >= 0 ? 0.85 * (1 - root.slashT) : 0
        }

        // quiet status caption when a track plays but no words are up — it also
        // keeps watch through instrumental breaks (tokens stay non-empty there,
        // so inInterlude is checked on its own)
        Row {
            x: root.boxX
            y: root.boxY
            spacing: Math.round(10 * root.pal.uiScale)
            visible: root.engine.player !== null && !root.countdownOn
                     && (root.engine.tokens.length === 0 || root.engine.inInterlude)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(16 * root.pal.uiScale); height: Math.round(2.5 * root.pal.uiScale)
                rotation: -32
                color: root.blood
            }
            Text {
                text: !root.engine.lyricsLoaded ? "seeking the words…"
                      : !root.engine.lyricsSynced ? "silence — no verse"
                      : "…"
                color: root.inkA(0.55)
                font.family: root.serif
                font.italic: true
                font.pixelSize: Math.round(root.lyricSize * 0.42)
                font.letterSpacing: 2
            }
        }

        // three drops of blood dry one by one — the verse returns
        Row {
            x: root.boxX
            y: root.boxY + Math.round(root.lyricSize * 0.2)
            spacing: Math.round(9 * root.pal.uiScale)
            visible: root.countdownOn
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    readonly property bool wet:
                        Math.ceil(root.engine.nextLineInMs / 1067) > index
                    width: Math.round(7 * root.pal.uiScale)
                    height: Math.round(9 * root.pal.uiScale)
                    radius: width / 2
                    color: wet ? root.fresh : root.halft
                    opacity: wet ? 0.9 : 0.25
                    Behavior on color { ColorAnimation { duration: 260 } }
                    Behavior on opacity { NumberAnimation { duration: 260 } }
                }
            }
        }

        // offset calibration OSD — a margin note that flashes on nudge
        Text {
            id: offsetOsd
            function flash() { opacity = 1; osdHide.restart() }
            x: root.boxX
            y: root.boxY - root.lyricSize * 0.9
            opacity: 0
            text: "offset " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " ms"
            color: root.blood
            font.family: root.serif
            font.italic: true
            font.pixelSize: Math.round(root.lyricSize * 0.38)
            font.letterSpacing: 2
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
        }
    }
}
