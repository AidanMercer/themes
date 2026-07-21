import QtQuick

// lonely-train: the in-car announcement board — STYLING ONLY, the engine
// (MPRIS clock, lyric fetch, per-word karaoke pacing) arrives as `engine`.
// The active line types itself across a lower-left announcement strip: each
// word flaps in on its own dark slat as it's sung, an amber tape-head
// sweep crossing the slat with the word's karaoke fill; sung words settle
// amber, the held last note glows. Adlibs float above the strip in small
// italic dusk-blue, off the slats. One line at a time, like the board over
// the train doors.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color amber: pal.neon
    readonly property color dusk:  pal.cyan
    readonly property color ink:   pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function duskA(a)  { return Qt.rgba(dusk.r, dusk.g, dusk.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    // board geometry: lower-left, clear of the girl (right third) and the
    // bottom bar; wraps upward-growing rows would be odd, so rows run down
    // from a fixed top.
    property real lyricSize: Math.round(30 * pal.uiScale)
    readonly property real charW: lyricSize * 0.6          // mono advance
    readonly property real padX: lyricSize * 0.38          // slat side padding
    readonly property real rowH: lyricSize * 1.75
    readonly property real boxW: Math.round(root.width * 0.44)
    readonly property real boxX: Math.round(root.width * 0.05)
    readonly property real boxY: Math.round(root.height * 0.56)

    // sequential wrap layout: [{x,y,w}] per token (adlibs narrower, no slat)
    function layoutTokens(tokens) {
        const out = []
        let cx = 0, cy = 0
        const gap = lyricSize * 0.3
        for (let i = 0; i < tokens.length; i++) {
            const t = tokens[i]
            const scale = t.bg ? 0.55 : 1
            const w = t.text.length * charW * scale + (t.bg ? 0 : padX * 2)
            if (cx + w > boxW && cx > 0) { cx = 0; cy += rowH }
            out.push({ x: cx, y: cy, w: w })
            cx += w + gap
        }
        return out
    }
    readonly property var curLayout: layoutTokens(engine.tokens)

    // fade a finished line out after a short hold instead of lingering
    readonly property real lineHoldMs: 350
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // brief cut on line change so lines never overlap
    property bool gate: true
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() { root.gate = false; gateCut.restart() }
        function onOffsetNudged() { offsetOsd.flash() }
    }

    Item {
        anchors.fill: parent

        Repeater {
            model: root.engine.tokens
            delegate: Item {
                id: wd
                required property int index
                required property var modelData          // {text, bg, mainIdx, t, d}
                readonly property bool bg: modelData.bg
                // touch audioSilent so held-word releases re-evaluate on the flip
                readonly property var st: (root.engine.audioSilent,
                                           root.engine.tokenState(index, root.engine.estMs))
                readonly property bool shown: (st.active || st.fill >= 1) && !root.lineExpired && root.gate
                readonly property bool sung: st.fill >= 1 && !st.active
                readonly property var p: root.curLayout[index] ? root.curLayout[index] : ({ x: 0, y: 0, w: 40 })

                x: root.boxX + p.x
                y: root.boxY + p.y + (wd.bg ? -root.lyricSize * 0.9 : 0)
                width: p.w
                height: root.lyricSize * 1.5

                opacity: shown ? (wd.bg ? 0.75 : 1) : 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                // the slat flaps open around its middle as the word arrives
                transform: Scale {
                    origin.y: wd.height / 2
                    yScale: wd.shown ? 1 : 0.1
                    Behavior on yScale { NumberAnimation { duration: 170; easing.type: Easing.OutBack } }
                }

                // slat (main words only)
                Rectangle {
                    visible: !wd.bg
                    anchors.fill: parent
                    radius: Math.round(5 * pal.uiScale)
                    color: root.glassA(0.85)
                    border.width: 1
                    border.color: root.inkA(0.08)
                    clip: true

                    // the tape-head sweep: karaoke fill crossing the slat
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * Math.max(0, Math.min(1, wd.st.fill))
                        color: root.amberA(wd.st.sustain ? 0.28 : 0.16)
                    }
                    // seam across the middle — split-flap kinship with the clock
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 1
                        color: Qt.rgba(0, 0, 0, 0.4)
                    }
                    // amber footer rail fills with the word
                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        anchors.leftMargin: 3
                        height: 2
                        radius: 1
                        width: Math.max(0, (parent.width - 6) * Math.max(0, Math.min(1, wd.st.fill)))
                        color: root.amber
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: wd.bg ? ("(" + wd.modelData.text + ")") : wd.modelData.text.toUpperCase()
                    textFormat: Text.PlainText
                    color: wd.bg ? root.duskA(0.9)
                         : wd.sung ? root.amberA(0.95)
                         : root.inkA(0.96)
                    Behavior on color { ColorAnimation { duration: 250 } }
                    font.family: root.mono
                    font.pixelSize: wd.bg ? Math.round(root.lyricSize * 0.55) : root.lyricSize
                    font.weight: wd.bg ? Font.DemiBold : Font.Bold
                    font.italic: wd.bg
                    style: wd.bg ? Text.Outline : Text.Normal
                    styleColor: Qt.rgba(0, 0, 0, 0.5)
                    // the held note breathes
                    scale: wd.st.sustain ? 1.05 + (root.engine.audioReady ? root.engine.audioPulse * 0.05 : 0) : 1
                    Behavior on scale { NumberAnimation { duration: 200 } }
                }
            }
        }

        // status chip when a track plays but no lyric is up
        Row {
            x: root.boxX
            y: root.boxY
            visible: root.engine.player !== null && root.engine.tokens.length === 0
            spacing: 8
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3
                color: root.amber
                opacity: 0.8
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: !root.engine.lyricsLoaded ? "LOADING…"
                      : !root.engine.lyricsSynced ? "NO SYNCED LYRICS"
                      : "♪"
                textFormat: Text.PlainText
                color: root.duskA(0.8)
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.5)
                font.family: root.mono
                font.pixelSize: Math.round(root.lyricSize * 0.45)
                font.letterSpacing: 4
            }
        }

        // offset calibration OSD
        Text {
            id: offsetOsd
            function flash() { opacity = 1; osdHide.restart() }
            x: root.boxX
            y: root.boxY - root.lyricSize * 1.3
            opacity: 0
            text: "OFFSET " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " ms"
            color: root.amber
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.6)
            font.family: root.mono
            font.pixelSize: Math.round(root.lyricSize * 0.42)
            font.weight: Font.Bold
            font.letterSpacing: 2
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
        }
    }
}
