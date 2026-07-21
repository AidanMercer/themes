import QtQuick

// sakura: lyrics as a line strung under the canopy — STYLING ONLY, the engine
// (timing, fetch, karaoke clocks) lives in the shell and arrives as `engine`.
// One line at a time, centered high on the screen on a soft plum scrim. Each
// word arrives as a bud — small, dim — and blooms open as it's sung: a warm
// pink fill sweeps through it (the karaoke wipe), sustained notes glow and
// hold, adlibs sit smaller and skyward. When the line is done the words let
// go together, sinking a few pixels as they fade (law 2).
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color pink:  pal.neon
    readonly property color sky:   pal.cyan
    readonly property color cream: pal.text
    readonly property color plum:  pal.glass
    readonly property real ui: pal.uiScale
    readonly property string sans: "Noto Sans"
    function creamA(a) { return Qt.rgba(cream.r, cream.g, cream.b, a) }
    function pinkA(a)  { return Qt.rgba(pink.r, pink.g, pink.b, a) }
    function plumA(a)  { return Qt.rgba(plum.r, plum.g, plum.b, a) }

    readonly property real lyricSize: Math.round(34 * ui)
    readonly property real bandY: Math.round(root.height * 0.135)

    // the line fades out shortly after its last word is done
    readonly property real lineHoldMs: 420
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // brief cut on line change so only one line is ever up
    property bool gate: true
    Timer { id: gateCut; interval: 110; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() { root.gate = false; gateCut.restart() }
        function onOffsetNudged() { offsetOsd.flash() }
    }

    // soft plum scrim so the words read over bright petals; only up while words are
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.bandY - height * 0.32
        width: flow.width + 160 * root.ui
        height: Math.max(flow.height * 1.9, 90 * root.ui)
        radius: height / 2
        opacity: flow.anyShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutSine } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.plumA(0.0) }
            GradientStop { position: 0.25; color: root.plumA(0.42) }
            GradientStop { position: 0.75; color: root.plumA(0.42) }
            GradientStop { position: 1.0; color: root.plumA(0.0) }
        }
    }

    // invisible measure of the whole line so the Flow can shrink to fit and
    // sit truly centered when the line is a single row (the usual case)
    Text {
        id: measure
        visible: false
        text: root.engine.tokens.map(t => t.text).join(" ")
        textFormat: Text.PlainText
        font.family: root.sans
        font.weight: Font.Light
        font.pixelSize: root.lyricSize
        font.letterSpacing: 1.5
    }

    Flow {
        id: flow
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.bandY
        width: Math.min(Math.min(root.width * 0.56, 1400 * root.ui),
                        measure.implicitWidth + spacing * Math.max(0, root.engine.tokens.length - 1) + 4)
        spacing: Math.round(root.lyricSize * 0.34)
        readonly property bool anyShown: {
            const toks = root.engine.tokens
            if (!toks.length || !root.gate || root.lineExpired) return false
            const st = root.engine.tokenState(0, root.engine.estMs)
            return st.active || st.fill > 0
        }

        Repeater {
            model: root.engine.tokens
            delegate: Item {
                id: wd
                required property int index
                required property var modelData          // {text, bg, mainIdx, t, d}
                readonly property bool bg: modelData.bg
                // touch audioSilent so held-word releases re-evaluate promptly
                readonly property var st: (root.engine.audioSilent,
                                           root.engine.tokenState(index, root.engine.estMs))
                readonly property bool sung: st.active || st.fill >= 1
                readonly property bool shown: sung && !root.lineExpired && root.gate
                readonly property real sizePx: wd.bg ? root.lyricSize * 0.6 : root.lyricSize

                width: base.width
                height: base.height

                // bud → bloom: the word swells slightly open as it arrives,
                // lets go with a small sink when the line expires
                opacity: shown ? (wd.bg ? 0.7 : 1) : 0
                scale: shown ? 1 : 0.92
                transform: Translate {
                    y: root.lineExpired ? 10 : 0
                    Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.InSine } }
                }
                Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }
                Behavior on scale  { NumberAnimation { duration: 420; easing.type: Easing.OutSine } }

                // the word, unsung: petal-cream, readable on the scrim
                Text {
                    id: base
                    text: wd.bg ? "(" + wd.modelData.text + ")" : wd.modelData.text
                    textFormat: Text.PlainText
                    color: root.creamA(0.55)
                    font.family: root.sans
                    font.weight: wd.bg ? Font.Normal : Font.Light
                    font.italic: wd.bg
                    font.pixelSize: wd.sizePx
                    font.letterSpacing: 1.5
                    style: Text.Raised
                    styleColor: root.plumA(0.6)
                }
                // the karaoke wipe: warm pink sweeping through as it's sung
                Item {
                    clip: true
                    width: base.width * Math.max(0, Math.min(1, wd.st.fill))
                    height: base.height
                    Text {
                        text: base.text
                        textFormat: Text.PlainText
                        color: wd.bg ? root.sky : root.pink
                        font.family: root.sans
                        font.weight: wd.bg ? Font.Normal : Font.Light
                        font.italic: wd.bg
                        font.pixelSize: wd.sizePx
                        font.letterSpacing: 1.5
                        style: Text.Raised
                        styleColor: root.plumA(0.6)
                    }
                }
                // sustained notes glow softly — a held petal of light
                Rectangle {
                    visible: wd.st.sustain === true && wd.st.active
                    anchors.centerIn: parent
                    width: base.width + 26
                    height: base.height + 10
                    radius: height / 2
                    color: "transparent"
                    border.width: 0
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.pinkA(0.0) }
                        GradientStop { position: 0.5; color: root.pinkA(0.10) }
                        GradientStop { position: 1.0; color: root.pinkA(0.0) }
                    }
                }
            }
        }
    }

    // status while a track plays but no lyric word is up
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.bandY
        visible: root.engine.player !== null && root.engine.tokens.length === 0
        text: !root.engine.lyricsLoaded ? "❀ listening…"
              : !root.engine.lyricsSynced ? "❀ no lyrics on the wind"
              : "❀"
        color: root.pinkA(0.8)
        style: Text.Raised
        styleColor: root.plumA(0.7)
        font.family: root.sans
        font.pixelSize: Math.round(15 * root.ui)
        font.letterSpacing: 3
    }

    // live offset readout while calibrating by ear
    Text {
        id: offsetOsd
        function flash() { opacity = 1; osdHide.restart() }
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.bandY - root.lyricSize * 1.4
        opacity: 0
        text: "offset " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " ms"
        color: root.sky
        style: Text.Raised
        styleColor: root.plumA(0.7)
        font.family: root.sans
        font.pixelSize: Math.round(14 * root.ui)
        font.letterSpacing: 2
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
    }
}
