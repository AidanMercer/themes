import QtQuick

// lonely-train: the in-car announcement board — STYLING ONLY, the engine
// (MPRIS clock, lyric fetch, per-word karaoke pacing) arrives as `engine`.
// The active line types itself across a lower-left announcement strip: each
// word flaps in on its own dark slat as it's sung, an amber tape-head
// sweep crossing the slat with the word's karaoke fill; sung words settle
// amber, the held last note glows. Adlibs float above the strip in small
// italic dusk-blue, off the slats. One line at a time, like the board over
// the train doors.
//
// Staging: a CHORUS is a station moment — the board stages center-screen,
// bigger, a platform light sweeping across it as the train pulls in. The car
// sways a little on each track-clack (kick drum). Instrumental breaks send
// scenery lights drifting past the window, and three signal lamps go out one
// by one — the last burning tail-light red — as the verse comes back. The
// amber is graded toward each song's album art.
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

    // the sodium amber takes each song's own cast (fail-open: identity until
    // the album-art palette lands; the touches re-evaluate the binding then)
    readonly property color amberLive: (engine.trackPaletteReady, engine.trackVivid,
                                        engine.trackTint(amber, 0.30))
    function amberLiveA(a) { return Qt.rgba(amberLive.r, amberLive.g, amberLive.b, a) }

    // station moment: the chorus stages the board center-screen, bigger
    readonly property bool station: engine.inChorus
    readonly property real stageSize: Math.round(lyricSize * (station ? 1.25 : 1))

    // the track-clack: the whole car nudges on each kick drum
    property real clack: 0
    NumberAnimation { id: clackAnim; target: root; property: "clack"; from: 1; to: 0; duration: 170; easing.type: Easing.OutQuad }

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

    // sequential wrap layout: [{x,y,w}] per token in SCREEN coords (adlibs
    // narrower, no slat). A chorus line (`big`) stages a wider board dead
    // center at door height — the line-change cut hides the relocation.
    function layoutTokens(tokens, big) {
        const out = []
        const sz = Math.round(lyricSize * (big ? 1.25 : 1))
        const cw = sz * 0.6
        const px = sz * 0.38
        const rH = sz * 1.75
        const bw = big ? Math.round(root.width * 0.5) : boxW
        const ox = big ? Math.round((root.width - bw) / 2) : boxX
        const oy = big ? Math.round(root.height * 0.4) : boxY
        let cx = 0, cy = 0
        const gap = sz * 0.3
        for (let i = 0; i < tokens.length; i++) {
            const t = tokens[i]
            const scale = t.bg ? 0.55 : 1
            const w = t.text.length * cw * scale + (t.bg ? 0 : px * 2)
            if (cx + w > bw && cx > 0) { cx = 0; cy += rH }
            out.push({ x: ox + cx, y: oy + cy, w: w })
            cx += w + gap
        }
        return out
    }
    readonly property var curLayout: layoutTokens(engine.tokens, engine.inChorus)

    // fade a finished line out after a short hold instead of lingering
    readonly property real lineHoldMs: 350
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // brief cut on line change so lines never overlap
    property bool gate: true
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() {
            root.gate = false; gateCut.restart()
            // the platform light sweeps the board as the chorus pulls in
            if (root.engine.inChorus && !root.wasStation) stationSweep.restart()
            root.wasStation = root.engine.inChorus
        }
        function onOffsetNudged() { offsetOsd.flash() }
        // quantized: the car's nudge lands on the kick drum
        function onBeat() { if (root.gate && !root.lineExpired && root.engine.tokens.length > 0) clackAnim.restart() }
    }
    property bool wasStation: false

    property real sweepT: -1
    SequentialAnimation {
        id: stationSweep
        NumberAnimation { target: root; property: "sweepT"; from: 0; to: 1; duration: 550; easing.type: Easing.OutQuad }
        PropertyAction { target: root; property: "sweepT"; value: -1 }
    }

    // the doors are about to open — countdown lamps above the board
    readonly property bool countdownOn:
        engine.player !== null && engine.lyricsSynced && engine.playing
        && engine.nextLineInMs >= 0 && engine.nextLineInMs < 3200
        && (engine.inInterlude || engine.activeIndex < 0)

    Item {
        anchors.fill: parent
        // the track-clack sway
        transform: Translate { y: root.clack * 2.5 }

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

                x: p.x
                y: p.y + (wd.bg ? -root.stageSize * 0.9 : 0)
                width: p.w
                height: root.stageSize * 1.5

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
                        color: root.amberLiveA(wd.st.sustain ? 0.28 : 0.16)
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
                        color: root.amberLive
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: wd.bg ? ("(" + wd.modelData.text + ")") : wd.modelData.text.toUpperCase()
                    textFormat: Text.PlainText
                    color: wd.bg ? root.duskA(0.9)
                         : wd.sung ? root.amberLiveA(0.95)
                         : root.inkA(0.96)
                    Behavior on color { ColorAnimation { duration: 250 } }
                    font.family: root.mono
                    font.pixelSize: wd.bg ? Math.round(root.stageSize * 0.55) : root.stageSize
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

        // the platform light sweeping the board as the chorus pulls in
        Rectangle {
            readonly property real bw: Math.round(root.width * 0.5)
            visible: root.sweepT >= 0
            x: (root.width - bw) / 2 + bw * Math.max(0, root.sweepT) - width / 2
            y: Math.round(root.height * 0.4) - root.stageSize * 0.5
            width: root.stageSize * 2.4
            height: root.stageSize * 1.75 * 2 + root.stageSize
            opacity: 0.75 * (1 - Math.max(0, root.sweepT))
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: root.amberLiveA(0.20) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // interlude: scenery lights drifting past the window
        Repeater {
            model: 4
            Rectangle {
                id: glim
                required property int index
                readonly property real seed: (index * 0.618 + 0.13) % 1
                readonly property bool on: root.engine.inInterlude && root.engine.playing
                width: Math.round((3 + seed * 4) * pal.uiScale)
                height: width
                radius: width / 2
                color: index % 3 === 0 ? root.duskA(0.8) : root.amberLiveA(0.75)
                visible: on
                opacity: 0
                y: root.boxY + root.rowH * (0.2 + seed * 1.3)
                SequentialAnimation {
                    running: glim.on
                    loops: Animation.Infinite
                    PauseAnimation { duration: glim.index * 800 }
                    ParallelAnimation {
                        NumberAnimation {
                            target: glim; property: "x"
                            from: root.width * 1.02; to: -root.width * 0.03
                            duration: 2800 + glim.seed * 1800
                        }
                        SequentialAnimation {
                            NumberAnimation { target: glim; property: "opacity"; to: 0.85; duration: 400 }
                            PauseAnimation { duration: 1500 + glim.seed * 1400 }
                            NumberAnimation { target: glim; property: "opacity"; to: 0; duration: 700 }
                        }
                    }
                }
            }
        }

        // three signal lamps go out one by one — the last burns tail-light red
        Row {
            x: root.boxX
            y: root.boxY - root.lyricSize * 0.9
            spacing: Math.round(9 * pal.uiScale)
            visible: root.countdownOn
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    readonly property int lampsLeft:
                        Math.max(0, Math.min(3, Math.ceil(root.engine.nextLineInMs / 1067)))
                    readonly property bool lit: lampsLeft > index
                    width: Math.round(8 * pal.uiScale)
                    height: width
                    radius: width / 2
                    color: lit && lampsLeft === 1 ? pal.magenta : root.amberLive
                    opacity: lit ? 0.9 : 0.15
                    border.width: 1
                    border.color: root.inkA(0.25)
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }
        }

        // status chip when a track plays but no lyric is up
        Row {
            x: root.boxX
            y: root.boxY
            visible: root.engine.player !== null && root.engine.tokens.length === 0
                     && !root.countdownOn
            spacing: 8
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3
                color: root.amber
                opacity: 0.8
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: !root.engine.lyricsLoaded ? "TUNING…"
                      : !root.engine.lyricsSynced ? "NO ANNOUNCEMENT"
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
            text: "SIGNAL OFFSET " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " ms"
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
