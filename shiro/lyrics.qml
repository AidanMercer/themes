import QtQuick

// shiro: desktop lyrics — the poem writes itself.
//
// Styling only; the timing brains live in the shell's LyricsEngine (injected
// as `engine`). Top-left, above the clock, like the top of a hanging scroll:
// the active line appears as faint pencil ghosts, then each word inks in
// left→right on its onset — wet wisteria that dries to ink violet. Held notes
// breathe (and swell with the bass), adlibs whisper in blush italics above
// the line, a hairline sweeps underneath with the line's progress, and the
// pen flicks a tiny ink fleck when the line completes.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property var eng: engine

    readonly property color ink:      pal.text
    readonly property color wisteria: pal.neon
    readonly property color blush:    pal.cyan
    readonly property string serif:   "Noto Serif Display"
    function inkA(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    readonly property real lyricSize: Math.round(30 * pal.uiScale)
    readonly property real blockX: Math.round(root.width * 0.05)
    readonly property real blockY: Math.round(root.height * 0.09)
    readonly property real blockW: Math.min(Math.round(560 * pal.uiScale), Math.round(root.width * 0.26))

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

    // one shared breath for held notes + the quiet dot (only while playing)
    property real breath: 0
    SequentialAnimation on breath {
        running: root.eng.playing
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 1000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 1000; easing.type: Easing.InOutSine }
    }

    // the pen lifts: a fleck flicks off the end of the rule as the line clears
    onLineExpiredChanged: if (lineExpired) fleckAnim.restart()
    Rectangle {
        id: fleck
        width: 3; height: 3; radius: 1.5
        color: root.ink
        opacity: 0
    }
    ParallelAnimation {
        id: fleckAnim
        NumberAnimation { target: fleck; property: "x"; from: block.x + rule.width; to: block.x + rule.width + 22; duration: 480; easing.type: Easing.OutQuad }
        SequentialAnimation {
            NumberAnimation { target: fleck; property: "y"; from: block.y + rule.y; to: block.y + rule.y - 10; duration: 200; easing.type: Easing.OutQuad }
            NumberAnimation { target: fleck; property: "y"; to: block.y + rule.y + 4; duration: 280; easing.type: Easing.InQuad }
        }
        SequentialAnimation {
            NumberAnimation { target: fleck; property: "opacity"; to: 0.6; duration: 60 }
            NumberAnimation { target: fleck; property: "opacity"; to: 0; duration: 420 }
        }
    }

    // ---- the written line ----------------------------------------------------
    Item {
        id: block
        x: root.blockX
        y: root.blockY + (root.lineShown ? 0 : -8)
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

                    width: ghost.implicitWidth
                    height: Math.round(root.lyricSize * 1.3)
                    // the active word swells gently with the bass (no-op without cava)
                    scale: (st.active && !st.sustain && !wd.bg && root.eng.audioReady)
                           ? 1 + root.eng.audioPulse * 0.05 : 1
                    transformOrigin: Item.Center

                    // pencil ghost — the words waiting to be written
                    Text {
                        id: ghost
                        y: wd.bg ? -Math.round(wd.sizePx * 0.28) + 4 : 4
                        text: wd.word
                        color: root.inkA(0.15)
                        font.family: root.serif
                        font.pixelSize: wd.sizePx
                        font.italic: wd.bg
                    }

                    // the ink, revealed left→right as the word is sung; wet
                    // wisteria (blush for adlibs) while writing, dries to ink
                    Item {
                        clip: true
                        width: Math.round(wd.st.fill * ghost.implicitWidth)
                        height: parent.height
                        Behavior on width { NumberAnimation { duration: 90 } }

                        Text {
                            y: ghost.y
                            text: wd.word
                            color: wd.st.active ? (wd.bg ? root.blush : root.wisteria)
                                                : (wd.bg ? Qt.rgba(root.blush.r, root.blush.g, root.blush.b, 0.75)
                                                         : root.inkA(0.88))
                            Behavior on color { ColorAnimation { duration: 500 } }
                            opacity: wd.st.sustain ? 0.72 + 0.28 * root.breath : 1
                            font.family: root.serif
                            font.pixelSize: wd.sizePx
                            font.italic: wd.bg
                        }
                    }
                }
            }
        }

        // hairline under the line, wisteria sweep paced to the line's span
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
            height: 2

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 1
                color: root.inkA(0.12)
            }
            Rectangle {
                width: 34 * pal.uiScale; height: 2; radius: 1
                x: Math.round((parent.width - width) * rule.prog)
                color: root.wisteria
                opacity: 0.8
            }
        }

    }

    // ---- quiet states: one small dot ------------------------------------------
    // wisteria while fetching, blush heartbeat through instrumentals; nothing
    // when a track simply has no lyrics
    Rectangle {
        x: root.blockX
        y: root.blockY + Math.round(root.lyricSize * 0.5)
        width: 6; height: 6; radius: 3
        visible: root.eng.player !== null && !root.lineShown
                 && (!root.eng.lyricsLoaded || (root.eng.lyricsSynced && root.eng.playing))
        color: root.eng.lyricsLoaded ? root.blush : root.wisteria
        opacity: 0.35 + 0.65 * root.breath
        SequentialAnimation on scale {
            running: visible
            loops: Animation.Infinite
            NumberAnimation { to: 1.25; duration: 1000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
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
        color: root.wisteria
        font.family: root.serif
        font.pixelSize: Math.round(root.lyricSize * 0.42)
        font.italic: true
        font.letterSpacing: 2
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
    }
}
