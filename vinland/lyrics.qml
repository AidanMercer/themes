import QtQuick

// vinland: desktop lyrics — words spoken into cold air. Lower-left over the
// snowfield: the line waits as faint frost, each word fills with starlit ice
// on its onset and settles to snow. Held notes shimmer like breath, adlibs
// whisper in gold italics, and a small north star rides the carved stave
// under the line. When a line clears, a snowflake settles off its end.
// Styling only — the timing brains live in the shell's LyricsEngine.
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

    // ---- the frosted line -------------------------------------------------------
    Item {
        id: block
        x: root.blockX
        y: root.blockY + (root.lineShown ? 0 : 8)
        width: root.blockW
        opacity: root.lineShown ? 1 : 0
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
                        color: root.iceA(0.18)
                        font.family: root.serif
                        font.pixelSize: wd.sizePx
                        font.weight: Font.Medium
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
                            color: wd.st.active ? (wd.bg ? root.gold : root.ice)
                                                : (wd.bg ? root.goldA(0.75) : root.snowA(0.94))
                            Behavior on color { ColorAnimation { duration: 500 } }
                            opacity: wd.st.sustain ? 0.70 + 0.30 * root.breath : 1
                            font.family: root.serif
                            font.pixelSize: wd.sizePx
                            font.weight: Font.Medium
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

    // ---- quiet states: one small star ------------------------------------------
    // ice while fetching, gold heartbeat through instrumentals; nothing when a
    // track simply has no lyrics
    Rectangle {
        x: root.blockX
        y: root.blockY + Math.round(root.lyricSize * 0.5)
        width: 6; height: 6
        rotation: 45
        visible: root.eng.player !== null && !root.lineShown
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
