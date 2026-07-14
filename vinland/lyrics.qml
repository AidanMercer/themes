import QtQuick

// vinland: desktop lyrics — words spoken into cold air. Lower-left over the
// snowfield: the line waits as faint frost, each word fills with starlit ice
// on its onset and settles to snow. Held notes shimmer like breath, adlibs
// whisper in gold italics, and a small north star rides the carved stave
// under the line. When a line clears, a snowflake settles off its end.
// Styling only — the timing brains live in the shell's LyricsEngine.
//
// Staging: a CHORUS is carved deeper — the line swells and goes bold under an
// aurora flare that breathes with the mix, and the north star glints on the
// kick drum. In instrumental breaks snow drifts down through the words' place,
// and three carved notches fade one by one as a countdown to the next verse.
// The starlit ice is graded toward each song's album art.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property var eng: engine

    readonly property color snow: pal.text
    readonly property color ice:  pal.neon
    readonly property color gold: pal.cyan
    readonly property string serif: "Noto Serif Display"
    function snowA(a) { return Qt.rgba(snow.r, snow.g, snow.b, a) }
    function iceA(a)  { return Qt.rgba(ice.r, ice.g, ice.b, a) }
    function goldA(a) { return Qt.rgba(gold.r, gold.g, gold.b, a) }

    // the starlight takes each song's own cast (fail-open: identity until the
    // album-art palette lands; the touches re-evaluate the binding when it does)
    readonly property color iceLive: (eng.trackPaletteReady, eng.trackVivid,
                                      eng.trackTint(ice, 0.28))
    function iceLiveA(a) { return Qt.rgba(iceLive.r, iceLive.g, iceLive.b, a) }

    // the chorus is carved deeper
    readonly property bool carved: eng.inChorus
    property real beatKick: 0
    NumberAnimation { id: beatKickAnim; target: root; property: "beatKick"; from: 1; to: 0; duration: 200; easing.type: Easing.OutQuad }

    readonly property real lyricSize: Math.round(30 * pal.uiScale)
    readonly property real blockX: Math.round(root.width * 0.055)
    readonly property real blockY: Math.round(root.height * 0.64)
    readonly property real blockW: Math.min(Math.round(560 * pal.uiScale), Math.round(root.width * 0.27))

    // ---- line lifecycle (render-side): brief cut between lines, early fade ---
    readonly property bool lineExpired:
        eng.activeIndex >= 0 && eng.estMs > eng.lineDoneMs + 300
    property bool gate: true
    Connections {
        target: root.eng
        function onActiveIndexChanged() { root.gate = false; gateCut.restart() }
        function onOffsetNudged() { offsetOsd.flash() }
        // the north star glints on the kick drum
        function onBeat() { if (root.lineShown) beatKickAnim.restart() }
    }
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }

    readonly property bool lineShown: eng.tokens.length > 0 && gate && !lineExpired

    // one shared breath for held notes + the quiet star (only while playing)
    property real breath: 0
    SequentialAnimation on breath {
        running: root.eng.playing
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 1100; easing.type: Easing.InOutSine }
    }

    // night scrim so frost-faint words read over the pale snow
    Canvas {
        id: scrim
        x: block.x + block.width / 2 - width / 2
        y: block.y + Math.round(root.lyricSize * 1.2) - height / 2
        width: block.width * 1.9
        height: Math.round(root.lyricSize * 8)
        opacity: root.eng.player !== null ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const g = ctx.createRadialGradient(width / 2, height / 2, 0,
                                               width / 2, height / 2, Math.min(width, height) / 1.6)
            g.addColorStop(0, Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.55))
            g.addColorStop(1, Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0))
            ctx.fillStyle = g
            ctx.fillRect(0, 0, width, height)
        }
        Connections {
            target: root.pal
            function onGlassChanged() { scrim.requestPaint() }
        }
    }

    // a snowflake settles off the stave's end as the line clears
    onLineExpiredChanged: if (lineExpired) flakeAnim.restart()
    Rectangle {
        id: flake
        width: 4; height: 4; radius: 2
        color: root.snowA(0.9)
        opacity: 0
    }
    ParallelAnimation {
        id: flakeAnim
        NumberAnimation { target: flake; property: "y"; from: block.y + rule.y; to: block.y + rule.y + 46; duration: 1400; easing.type: Easing.InQuad }
        SequentialAnimation {
            NumberAnimation { target: flake; property: "x"; from: block.x + rule.width; to: block.x + rule.width - 12; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { target: flake; property: "x"; to: block.x + rule.width + 6; duration: 700; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            NumberAnimation { target: flake; property: "opacity"; to: 0.8; duration: 120 }
            PauseAnimation { duration: 700 }
            NumberAnimation { target: flake; property: "opacity"; to: 0; duration: 580 }
        }
    }

    // ---- chorus aurora: a flare hanging over the carved line -------------------
    Rectangle {
        x: block.x - root.lyricSize * 1.2
        y: block.y - root.lyricSize * 2.6
        width: Math.min(flow.childrenRect.width, flow.width) + root.lyricSize * 2.4
        height: root.lyricSize * 2.2
        rotation: -2
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.72; color: root.iceLiveA(0.13) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        // breathes with the mix when the feed is live (audioLift rests at 1 without it)
        opacity: root.carved && root.lineShown
                 ? 0.75 + (root.eng.audioReady ? Math.max(-0.25, Math.min(0.25, (root.eng.audioLift - 1) * 0.6)) : 0)
                 : 0
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutQuad } }
    }

    // ---- the frosted line -------------------------------------------------------
    Item {
        id: block
        x: root.blockX
        y: root.blockY + (root.lineShown ? 0 : 8)
        width: root.blockW
        opacity: root.lineShown ? 1 : 0
        // the chorus swells, carved a size deeper into the night
        scale: root.carved ? 1.12 : 1
        transformOrigin: Item.TopLeft
        Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutQuad } }

        Flow {
            id: flow
            width: parent.width
            spacing: Math.round(root.lyricSize * 0.32)

            Repeater {
                model: root.eng.tokens
                delegate: Item {
                    id: wd
                    required property int index
                    required property var modelData      // {text, bg, mainIdx, t, d}
                    readonly property bool bg: modelData.bg
                    // touch audioSilent so a held-word release re-evaluates the
                    // instant the silence signal flips
                    readonly property var st: (root.eng.audioSilent,
                                               root.eng.tokenState(index, root.eng.estMs))
                    readonly property real sizePx: wd.bg ? root.lyricSize * 0.58 : root.lyricSize
                    readonly property string word: wd.bg ? "(" + modelData.text + ")" : modelData.text

                    width: shade.implicitWidth
                    height: Math.round(root.lyricSize * 1.3)
                    // the active word swells gently with the bass (no-op without cava)
                    scale: (st.active && !st.sustain && !wd.bg && root.eng.audioReady)
                           ? 1 + root.eng.audioPulse * 0.05 : 1
                    transformOrigin: Item.Center

                    // the words waiting as frost
                    Text {
                        id: shade
                        y: wd.bg ? -Math.round(wd.sizePx * 0.28) + 4 : 4
                        text: wd.word
                        textFormat: Text.PlainText
                        color: root.iceA(0.18)
                        font.family: root.serif
                        font.pixelSize: wd.sizePx
                        font.weight: root.carved && !wd.bg ? Font.Bold : Font.Medium
                        font.italic: wd.bg
                    }

                    // starlight sweeping left→right as the word is sung — ice
                    // while lit (gold for adlibs), settling to snow
                    Item {
                        clip: true
                        width: Math.round(wd.st.fill * shade.implicitWidth)
                        height: parent.height
                        Behavior on width { NumberAnimation { duration: 90 } }

                        Text {
                            y: shade.y
                            text: wd.word
                            textFormat: Text.PlainText
                            color: wd.st.active ? (wd.bg ? root.gold : root.iceLive)
                                                : (wd.bg ? root.goldA(0.75) : root.snowA(0.94))
                            Behavior on color { ColorAnimation { duration: 500 } }
                            opacity: wd.st.sustain ? 0.70 + 0.30 * root.breath : 1
                            font.family: root.serif
                            font.pixelSize: wd.sizePx
                            font.weight: root.carved && !wd.bg ? Font.Bold : Font.Medium
                            font.italic: wd.bg
                        }
                    }
                }
            }
        }

        // carved stave under the line, the north star riding its progress
        Item {
            id: rule
            readonly property real lineStart:
                (root.eng.activeIndex >= 0 && root.eng.lines[root.eng.activeIndex])
                    ? root.eng.lines[root.eng.activeIndex].t : 0
            readonly property real prog: {
                const span = root.eng.lineDoneMs - lineStart
                if (span <= 0) return 0
                return Math.max(0, Math.min(1, (root.eng.estMs - lineStart) / span))
            }
            y: flow.childrenRect.height + Math.round(root.lyricSize * 0.35)
            width: Math.min(flow.childrenRect.width, flow.width)
            height: 11

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 1
                color: root.iceA(0.28)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width * 0.5
                width: 1; height: 5
                rotation: 20
                color: root.iceA(0.28)
            }
            Canvas {
                id: prgStar
                width: 11; height: 11
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) * rule.prog)
                // the glint: a transform-only kick on each beat, no repaint
                scale: 1 + root.beatKick * 0.4
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const c = width / 2, R = width / 2
                    ctx.beginPath()
                    ctx.moveTo(c, c - R)
                    ctx.quadraticCurveTo(c, c, c + R, c)
                    ctx.quadraticCurveTo(c, c, c, c + R)
                    ctx.quadraticCurveTo(c, c, c - R, c)
                    ctx.quadraticCurveTo(c, c, c, c - R)
                    ctx.closePath()
                    ctx.fillStyle = Qt.rgba(root.gold.r, root.gold.g, root.gold.b, 0.95)
                    ctx.fill()
                }
                Connections {
                    target: root.pal
                    function onCyanChanged() { prgStar.requestPaint() }
                }
            }
        }
    }

    // ---- interlude: snow drifting through the words' place ---------------------
    Repeater {
        model: 6
        Rectangle {
            id: drift
            required property int index
            readonly property real seed: (index * 0.618 + 0.11) % 1
            readonly property bool on: root.eng.inInterlude && root.eng.playing
            width: (2.5 + seed * 2.5) * pal.uiScale
            height: width
            radius: width / 2
            color: root.snowA(0.75)
            visible: on
            opacity: 0
            x: root.blockX + root.blockW * ((index * 0.19 + 0.03) % 1)
            SequentialAnimation {
                running: drift.on
                loops: Animation.Infinite
                ParallelAnimation {
                    NumberAnimation {
                        target: drift; property: "y"
                        from: root.blockY - root.lyricSize * (1.5 + drift.seed)
                        to: root.blockY + root.lyricSize * (2 + drift.seed * 1.5)
                        duration: 4000 + drift.seed * 2600
                        easing.type: Easing.InOutSine
                    }
                    SequentialAnimation {
                        NumberAnimation { target: drift; property: "opacity"; from: 0; to: 0.7; duration: 500 }
                        NumberAnimation { target: drift; property: "opacity"; to: 0; duration: 3500 + drift.seed * 2600 }
                    }
                }
            }
        }
    }

    // ---- quiet states: one small star ------------------------------------------
    // ice while fetching, gold heartbeat through instrumentals; nothing when a
    // track simply has no lyrics. The final ~3s hand over to the notch countdown.
    readonly property bool countdownOn:
        eng.player !== null && !lineShown && eng.lyricsSynced && eng.playing
        && eng.nextLineInMs >= 0 && eng.nextLineInMs < 3200
    Rectangle {
        x: root.blockX
        y: root.blockY + Math.round(root.lyricSize * 0.5)
        width: 6; height: 6
        rotation: 45
        visible: root.eng.player !== null && !root.lineShown && !root.countdownOn
                 && (!root.eng.lyricsLoaded || (root.eng.lyricsSynced && root.eng.playing))
        color: root.eng.lyricsLoaded ? root.gold : root.ice
        opacity: 0.35 + 0.65 * root.breath
        SequentialAnimation on scale {
            running: visible
            loops: Animation.Infinite
            NumberAnimation { to: 1.25; duration: 1100; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
        }
    }

    // three carved notches fade one by one — the next verse approaches
    Row {
        x: root.blockX
        y: root.blockY + Math.round(root.lyricSize * 0.4)
        spacing: 10
        visible: root.countdownOn
        Repeater {
            model: 3
            Rectangle {
                required property int index
                readonly property bool held: Math.ceil(root.eng.nextLineInMs / 1067) > index
                width: 2; height: 9
                rotation: 20
                color: root.iceLive
                opacity: held ? 0.85 : 0.1
                Behavior on opacity { NumberAnimation { duration: 220 } }
            }
        }
    }

    // ---- live offset readout ---------------------------------------------------
    Text {
        id: offsetOsd
        function flash() { opacity = 1; osdHide.restart() }
        x: root.blockX
        y: root.blockY - Math.round(root.lyricSize * 0.9)
        opacity: 0
        text: "offset " + (root.eng.offsetMs > 0 ? "+" : "") + root.eng.offsetMs + " ms"
        color: root.ice
        font.family: root.serif
        font.pixelSize: Math.round(root.lyricSize * 0.42)
        font.italic: true
        font.weight: Font.Medium
        font.letterSpacing: 2
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
    }
}
