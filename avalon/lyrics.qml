import QtQuick

// avalon: desktop lyrics — words catch the light. Top-left against the dark
// canopy: the line waits as faint cream shade, and each word fills buttercup
// on its onset like sun through the leaves, settling to warm cream. Held
// notes breathe with the bass, adlibs whisper in moss-green italics above
// the line, and a gold diamond rides the rule underneath. Styling only —
// the timing brains live in the shell's LyricsEngine.
//
// Staging: a CHORUS floods the clearing — the block swells inside a gold
// radiance that pulses on the kick drum, and a gust of petals lifts past the
// line. In instrumental breaks petals drift down through the shade, and three
// gold petals lift away one by one as a countdown to the verse coming back.
// The buttercup light is graded toward each song's album art.
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

    // the sunlight takes each song's own warmth (fail-open: identity until the
    // album-art palette lands; the touches re-evaluate the binding when it does)
    readonly property color goldLive: (eng.trackPaletteReady, eng.trackVivid,
                                       eng.trackTint(gold, 0.30))
    function goldLiveA(a) { return Qt.rgba(goldLive.r, goldLive.g, goldLive.b, a) }

    // the chorus floods the clearing
    readonly property bool sunlit: eng.inChorus
    property real beatKick: 0
    NumberAnimation { id: beatKickAnim; target: root; property: "beatKick"; from: 1; to: 0; duration: 180; easing.type: Easing.OutQuad }

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
        // the radiance pulses on the kick drum while the clearing is lit
        function onBeat() { if (root.sunlit && !root.lineExpired) beatKickAnim.restart() }
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

    // ---- chorus radiance: sun flooding the clearing behind the line -----------
    Rectangle {
        x: block.x - root.lyricSize * 0.9
        y: block.y - root.lyricSize * 0.5
        width: Math.min(flow.childrenRect.width, flow.width) + root.lyricSize * 1.8
        height: flow.childrenRect.height + root.lyricSize * 1.35
        radius: height / 2
        color: root.goldLiveA(0.09)
        opacity: root.sunlit && root.lineShown ? 1 : 0
        scale: (root.sunlit && root.lineShown ? 1 : 0.86) + root.beatKick * 0.05
        transformOrigin: Item.Left
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
    }

    // ---- chorus gust: petals lifting past the line -----------------------------
    Repeater {
        model: 6
        Rectangle {
            id: gustPetal
            required property int index
            readonly property real seed: (index * 0.618 + 0.13) % 1
            readonly property bool on: root.sunlit && root.lineShown && root.eng.playing
            x: root.blockX + root.blockW * ((seed + index * 0.17) % 1)
            width: (4 + seed * 3) * pal.uiScale
            height: width
            rotation: 45 + seed * 60
            color: index % 2 ? root.goldLiveA(0.8)
                             : Qt.rgba(root.leaf.r, root.leaf.g, root.leaf.b, 0.6)
            visible: on
            opacity: 0
            SequentialAnimation {
                running: gustPetal.on
                loops: Animation.Infinite
                ParallelAnimation {
                    NumberAnimation {
                        target: gustPetal; property: "y"
                        from: root.blockY + root.lyricSize * 2.2
                        to: root.blockY - root.lyricSize * (1.5 + gustPetal.seed * 2)
                        duration: 2400 + gustPetal.seed * 1600
                    }
                    NumberAnimation {
                        target: gustPetal; property: "rotation"
                        from: 45 + gustPetal.seed * 60; to: 200 + gustPetal.seed * 120
                        duration: 2400 + gustPetal.seed * 1600
                    }
                    SequentialAnimation {
                        NumberAnimation { target: gustPetal; property: "opacity"; from: 0; to: 0.8; duration: 320 }
                        NumberAnimation { target: gustPetal; property: "opacity"; to: 0; duration: 2100 + gustPetal.seed * 1600 }
                    }
                }
            }
        }
    }

    // ---- the lit line ----------------------------------------------------------
    Item {
        id: block
        x: root.blockX
        y: root.blockY + (root.lineShown ? 0 : -8)
        width: root.blockW
        opacity: root.lineShown ? 1 : 0
        // the chorus swells the whole line in the flood of light
        scale: root.sunlit ? 1.12 : 1
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

                    // the words waiting in shade
                    Text {
                        id: shade
                        y: wd.bg ? -Math.round(wd.sizePx * 0.28) + 4 : 4
                        text: wd.word
                        textFormat: Text.PlainText
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
                            textFormat: Text.PlainText
                            color: wd.st.active ? (wd.bg ? root.leaf : root.goldLive)
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
                color: root.goldLive
            }
        }
    }

    // ---- interlude: petals drifting down through the shade ---------------------
    Repeater {
        model: 5
        Rectangle {
            id: driftPetal
            required property int index
            readonly property real seed: (index * 0.618 + 0.29) % 1
            readonly property bool on: root.eng.inInterlude && root.eng.playing
            width: (3.5 + seed * 3) * pal.uiScale
            height: width
            color: index % 2 ? root.goldLiveA(0.55)
                             : Qt.rgba(root.leaf.r, root.leaf.g, root.leaf.b, 0.45)
            visible: on
            opacity: 0
            x: root.blockX + root.blockW * ((index * 0.21 + 0.04) % 1)
            SequentialAnimation {
                running: driftPetal.on
                loops: Animation.Infinite
                ParallelAnimation {
                    NumberAnimation {
                        target: driftPetal; property: "y"
                        from: root.blockY - root.lyricSize * (1 + driftPetal.seed)
                        to: root.blockY + root.lyricSize * (2.5 + driftPetal.seed * 1.5)
                        duration: 3600 + driftPetal.seed * 2400
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: driftPetal; property: "rotation"
                        from: driftPetal.seed * 90; to: 160 + driftPetal.seed * 120
                        duration: 3600 + driftPetal.seed * 2400
                    }
                    SequentialAnimation {
                        NumberAnimation { target: driftPetal; property: "opacity"; from: 0; to: 0.7; duration: 500 }
                        NumberAnimation { target: driftPetal; property: "opacity"; to: 0; duration: 3100 + driftPetal.seed * 2400 }
                    }
                }
            }
        }
    }

    // ---- quiet states: one small bud -------------------------------------------
    // leaf while fetching, gold heartbeat through instrumentals; nothing when a
    // track simply has no lyrics. The final ~3s hand over to the petal countdown.
    readonly property bool countdownOn:
        eng.player !== null && !lineShown && eng.lyricsSynced && eng.playing
        && eng.nextLineInMs >= 0 && eng.nextLineInMs < 3200
    Rectangle {
        x: root.blockX
        y: root.blockY + Math.round(root.lyricSize * 0.5)
        width: 6; height: 6; radius: 3
        visible: root.eng.player !== null && !root.lineShown && !root.countdownOn
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

    // three gold petals lift away one by one — the verse is coming back
    Row {
        x: root.blockX
        y: root.blockY + Math.round(root.lyricSize * 0.5)
        spacing: 9
        visible: root.countdownOn
        Repeater {
            model: 3
            Rectangle {
                required property int index
                readonly property bool resting: Math.ceil(root.eng.nextLineInMs / 1067) > index
                width: 6; height: 6
                rotation: 45
                color: root.goldLive
                opacity: resting ? 0.8 : 0
                scale: resting ? 1 : 1.8
                Behavior on opacity { NumberAnimation { duration: 220 } }
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutQuad } }
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
        color: root.gold
        font.family: root.serif
        font.pixelSize: Math.round(root.lyricSize * 0.42)
        font.italic: true
        font.letterSpacing: 2
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
    }
}
