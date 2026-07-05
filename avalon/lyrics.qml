import QtQuick

// avalon: desktop lyrics — words catch the light. Top-left against the dark
// canopy: the line waits as faint cream shade, and each word fills buttercup
// on its onset like sun through the leaves, settling to warm cream. Held
// notes breathe with the bass, adlibs whisper in moss-green italics above
// the line, and a gold diamond rides the rule underneath. Styling only —
// the timing brains live in the shell's LyricsEngine.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property var eng: engine

    readonly property color ivory: pal.text
    readonly property color leaf:  pal.neon
    readonly property color gold:  pal.cyan
    readonly property string serif: "Noto Serif Display"
    function ivoryA(a) { return Qt.rgba(ivory.r, ivory.g, ivory.b, a) }
    function goldA(a)  { return Qt.rgba(gold.r, gold.g, gold.b, a) }

    readonly property real lyricSize: Math.round(30 * pal.uiScale)
    readonly property real blockX: Math.round(root.width * 0.055)
    readonly property real blockY: Math.round(root.height * 0.13)
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

    // one shared breath for held notes + the quiet dot (only while playing)
    property real breath: 0
    SequentialAnimation on breath {
        running: root.eng.playing
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 1000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 1000; easing.type: Easing.InOutSine }
    }

    // a petal lets go from the rule's end as the line clears
    onLineExpiredChanged: if (lineExpired) petalAnim.restart()
    Rectangle {
        id: petal
        width: 5; height: 5
        rotation: 45
        color: root.gold
        opacity: 0
    }
    ParallelAnimation {
        id: petalAnim
        NumberAnimation { target: petal; property: "x"; from: block.x + rule.width; to: block.x + rule.width + 26; duration: 520; easing.type: Easing.OutQuad }
        NumberAnimation { target: petal; property: "rotation"; from: 45; to: 160; duration: 520 }
        SequentialAnimation {
            NumberAnimation { target: petal; property: "y"; from: block.y + rule.y; to: block.y + rule.y - 12; duration: 210; easing.type: Easing.OutQuad }
            NumberAnimation { target: petal; property: "y"; to: block.y + rule.y + 8; duration: 310; easing.type: Easing.InQuad }
        }
        SequentialAnimation {
            NumberAnimation { target: petal; property: "opacity"; to: 0.75; duration: 60 }
            NumberAnimation { target: petal; property: "opacity"; to: 0; duration: 460 }
        }
    }

    // ---- the lit line ----------------------------------------------------------
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

                    width: shade.implicitWidth
                    height: Math.round(root.lyricSize * 1.3)
                    // the active word swells gently with the bass (no-op without cava)
                    scale: (st.active && !st.sustain && !wd.bg && root.eng.audioReady)
                           ? 1 + root.eng.audioPulse * 0.05 : 1
                    transformOrigin: Item.Center

                    // the words waiting in shade
                    Text {
                        id: shade
                        y: wd.bg ? -Math.round(wd.sizePx * 0.28) + 4 : 4
                        text: wd.word
                        color: root.ivoryA(0.16)
                        font.family: root.serif
                        font.pixelSize: wd.sizePx
                        font.italic: wd.bg
                    }

                    // the light, sweeping left→right as the word is sung — gold
                    // while lit (leaf for adlibs), settling to warm ivory
                    Item {
                        clip: true
                        width: Math.round(wd.st.fill * shade.implicitWidth)
                        height: parent.height
                        Behavior on width { NumberAnimation { duration: 90 } }

                        Text {
                            y: shade.y
                            text: wd.word
                            color: wd.st.active ? (wd.bg ? root.leaf : root.gold)
                                                : (wd.bg ? Qt.rgba(root.leaf.r, root.leaf.g, root.leaf.b, 0.75)
                                                         : root.ivoryA(0.92))
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

        // gold hairline under the line, a diamond riding the line's progress
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
            height: 5

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 1
                color: root.goldA(0.30)
            }
            Rectangle {
                width: 5; height: 5
                rotation: 45
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) * rule.prog)
                color: root.gold
            }
        }
    }

    // ---- quiet states: one small bud -------------------------------------------
    // leaf while fetching, gold heartbeat through instrumentals; nothing when a
    // track simply has no lyrics
    Rectangle {
        x: root.blockX
        y: root.blockY + Math.round(root.lyricSize * 0.5)
        width: 6; height: 6; radius: 3
        visible: root.eng.player !== null && !root.lineShown
                 && (!root.eng.lyricsLoaded || (root.eng.lyricsSynced && root.eng.playing))
        color: root.eng.lyricsLoaded ? root.gold : root.leaf
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
        color: root.gold
        font.family: root.serif
        font.pixelSize: Math.round(root.lyricSize * 0.42)
        font.italic: true
        font.letterSpacing: 2
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
    }
}
