import QtQuick

// nature — "golden hour" desktop lyrics: the line grows like a flower bed.
//
// STYLING ONLY — all timing/fetch machinery lives in the shell's LyricsEngine
// and arrives as `engine`. The active line is planted as a row of closed buds
// (one per word); as each word is sung its bud BURSTS and the word blooms in
// (unfolds with an OutBack petal-pop and a pollen glow), while a warm gold
// light sweeps through the letters (karaoke fill). A held note swells with a
// slow radiance and sheds drifting pollen motes. When a line finishes it
// detaches and settles like a falling petal while the next bed is planted.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color gold:  pal.neon
    readonly property color leaf:  pal.cyan
    readonly property color rose:  pal.magenta
    readonly property color cream: pal.text
    readonly property color pine:  pal.glass
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"
    function goldA(a) { return Qt.rgba(gold.r, gold.g, gold.b, a) }
    function pineA(a) { return Qt.rgba(pine.r, pine.g, pine.b, a) }

    readonly property real lyricSize: Math.round(38 * ui)
    readonly property real bedW: Math.round(root.width * 0.56)
    readonly property real bedX: Math.round((root.width - bedW) / 2)
    readonly property real bedY: Math.round(root.height * 0.60)

    // fade a finished line out instead of lingering through the gap
    readonly property real lineHoldMs: 420
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // falling-petal ghost of the previous line
    property string prevLineText: ""
    Connections {
        target: root.engine
        function onActiveIndexChanged() {
            const old = root.curLineJoined
            if (old.length > 0) {
                ghost.text = old
                ghostFall.restart()
            }
            root.curLineJoined = root.joinTokens()
        }
        function onOffsetNudged() { offsetOsd.flash() }
    }
    property string curLineJoined: ""
    function joinTokens() {
        const t = engine.tokens
        let out = []
        for (let i = 0; i < t.length; i++) out.push(t[i].bg ? "(" + t[i].text + ")" : t[i].text)
        return out.join(" ")
    }

    // ── the flower bed: current line, blooming word by word ────────────────
    Flow {
        id: bed
        x: root.bedX
        y: root.bedY
        width: root.bedW
        spacing: Math.round(13 * root.ui)
        opacity: root.lineExpired ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

        Repeater {
            id: flowRepeater
            model: root.engine.tokens
            delegate: Item {
                id: wd
                required property int index
                required property var modelData        // {text, bg, mainIdx, t, d}
                readonly property bool bg: modelData.bg
                // touch audioSilent so held releases re-evaluate the instant it flips
                readonly property var st: (root.engine.audioSilent,
                                           root.engine.tokenState(index, root.engine.estMs))
                readonly property bool shown: st.active || st.fill >= 1
                readonly property real sizePx: wd.bg ? root.lyricSize * 0.55 : root.lyricSize

                width: base.width
                height: root.lyricSize * 1.25

                // an organic hand-planted stagger, without disturbing the Flow
                transform: Translate { y: Math.sin(wd.index * 1.7 + 0.6) * 4 * root.ui }

                // the closed bud waiting where the word will bloom
                Rectangle {
                    anchors.centerIn: parent
                    width: 7 * root.ui
                    height: 10 * root.ui
                    radius: width / 2
                    color: root.goldA(0.75)
                    border.width: 1
                    border.color: Qt.rgba(root.leaf.r, root.leaf.g, root.leaf.b, 0.9)
                    opacity: wd.shown ? 0 : 0.5
                    scale: wd.shown ? 1.8 : 1
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                }

                // everything that blooms
                Item {
                    id: flower
                    anchors.fill: parent
                    opacity: wd.shown ? (wd.bg ? 0.75 : 1) : 0
                    scale: wd.shown ? 1 : 0.55
                    rotation: wd.shown ? 0 : -8
                    transformOrigin: Item.Bottom
                    Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutQuad } }
                    Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutBack } }
                    Behavior on rotation { NumberAnimation { duration: 340; easing.type: Easing.OutBack } }
                    // the held-note swell rides its own transform so it can't
                    // fight the bloom Behavior above
                    transform: Scale {
                        origin.x: flower.width / 2
                        origin.y: flower.height
                        xScale: 1 + swell.k
                        yScale: 1 + swell.k
                    }

                    // pollen glow — a soft gold aura while the word is being sung
                    Text {
                        anchors.centerIn: base
                        text: base.text
                        textFormat: Text.PlainText
                        font: base.font
                        color: root.gold
                        scale: 1.07
                        opacity: wd.st.active ? 0.32 : 0
                        Behavior on opacity { NumberAnimation { duration: 260 } }
                    }

                    // the word itself, cream on a pine shadow
                    Text {
                        id: base
                        anchors.verticalCenter: parent.verticalCenter
                        text: wd.bg ? "(" + wd.modelData.text + ")" : wd.modelData.text
                        textFormat: Text.PlainText
                        color: Qt.rgba(root.cream.r, root.cream.g, root.cream.b, 0.92)
                        style: Text.Raised
                        styleColor: root.pineA(0.85)
                        font.family: root.serif
                        font.pixelSize: wd.sizePx
                        font.weight: wd.bg ? Font.Medium : Font.Bold
                        font.italic: wd.bg
                        font.letterSpacing: 1
                    }

                    // warm gold light sweeping through the letters (karaoke fill)
                    Item {
                        anchors.left: base.left
                        anchors.top: base.top
                        width: base.width * Math.max(0, Math.min(1, wd.st.fill))
                        height: base.height
                        clip: true
                        Text {
                            text: base.text
                            textFormat: Text.PlainText
                            color: root.gold
                            style: Text.Raised
                            styleColor: root.pineA(0.85)
                            font: base.font
                        }
                    }

                    // held-note radiance: slow swell + pollen motes drifting up
                    SequentialAnimation {
                        id: swell
                        property real k: 0
                        running: wd.st.sustain && root.engine.playing
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) k = 0
                        NumberAnimation { target: swell; property: "k"; to: 0.09; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { target: swell; property: "k"; to: 0.02; duration: 900; easing.type: Easing.InOutSine }
                    }
                    Repeater {
                        model: 3
                        Rectangle {
                            id: mote
                            required property int index
                            readonly property real seed: (index * 0.618 + wd.index * 0.37) % 1
                            width: (2.5 + seed * 2) * root.ui
                            height: width
                            radius: width / 2
                            color: mote.index === 1 ? root.goldA(0.9)
                                : Qt.rgba(root.cream.r, root.cream.g, root.cream.b, 0.8)
                            x: base.width * (0.15 + seed * 0.7)
                            visible: wd.st.sustain && root.engine.playing
                            SequentialAnimation {
                                running: wd.st.sustain && root.engine.playing
                                loops: Animation.Infinite
                                ParallelAnimation {
                                    NumberAnimation {
                                        target: mote; property: "y"
                                        from: wd.height * 0.4; to: -wd.height * (0.5 + mote.seed * 0.5)
                                        duration: 1300 + mote.seed * 900
                                    }
                                    SequentialAnimation {
                                        NumberAnimation { target: mote; property: "opacity"; from: 0; to: 0.9; duration: 250 }
                                        NumberAnimation { target: mote; property: "opacity"; to: 0; duration: 1000 + mote.seed * 900 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── the previous line, settling like a falling petal ───────────────────
    Text {
        id: ghost
        x: root.bedX
        y: root.bedY
        width: root.bedW
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        opacity: 0
        color: Qt.rgba(root.cream.r, root.cream.g, root.cream.b, 0.9)
        style: Text.Raised
        styleColor: root.pineA(0.8)
        font.family: root.serif
        font.pixelSize: Math.round(root.lyricSize * 0.9)
        font.letterSpacing: 1
        font.weight: Font.Medium
        transformOrigin: Item.Left

        ParallelAnimation {
            id: ghostFall
            // clear the bed fast first — the next line blooms at bedY, so a
            // slow-starting fall leaves the two lines overlapped
            SequentialAnimation {
                NumberAnimation { target: ghost; property: "y"; from: root.bedY; to: root.bedY + root.lyricSize * 1.6; duration: 220; easing.type: Easing.OutQuad }
                NumberAnimation { target: ghost; property: "y"; to: root.bedY + root.lyricSize * 1.6 + 40 * root.ui; duration: 1080; easing.type: Easing.InOutSine }
            }
            NumberAnimation { target: ghost; property: "x"; from: root.bedX; to: root.bedX + 36 * root.ui; duration: 1300; easing.type: Easing.InOutSine }
            NumberAnimation { target: ghost; property: "rotation"; from: 0; to: 2.5; duration: 1300 }
            SequentialAnimation {
                NumberAnimation { target: ghost; property: "opacity"; from: 0.55; to: 0.55; duration: 100 }
                NumberAnimation { target: ghost; property: "opacity"; to: 0; duration: 1200; easing.type: Easing.InQuad }
            }
        }
    }

    // ── status whisper when a track plays but no words are up ──────────────
    Text {
        x: root.bedX
        y: root.bedY + root.lyricSize * 0.3
        visible: root.engine.player !== null && root.engine.tokens.length === 0
        text: !root.engine.lyricsLoaded ? "gathering seeds…"
              : !root.engine.lyricsSynced ? "no lyrics on this breeze"
              : "❀"
        textFormat: Text.PlainText
        color: root.goldA(0.8)
        style: Text.Raised
        styleColor: root.pineA(0.8)
        font.family: root.serif
        font.italic: true
        font.weight: Font.Medium
        font.pixelSize: Math.round(root.lyricSize * 0.5)
        font.letterSpacing: 2
    }

    // ── live offset readout while calibrating by ear ───────────────────────
    Text {
        id: offsetOsd
        function flash() { opacity = 1; osdHide.restart() }
        x: root.bedX
        y: root.bedY - root.lyricSize * 1.1
        opacity: 0
        text: "breeze offset  " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " ms"
        color: root.goldA(0.95)
        style: Text.Raised
        styleColor: root.pineA(0.85)
        font.family: root.serif
        font.italic: true
        font.weight: Font.Medium
        font.pixelSize: Math.round(root.lyricSize * 0.45)
        font.letterSpacing: 2
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
    }
}
