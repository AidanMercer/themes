import QtQuick

// sailing: words surface through the rain — lyrics for "THROUGH SILENCE".
//
// STYLING ONLY: the engine (MPRIS clock, fetch, karaoke timing, silence
// detection) is injected as `engine`. The active line hangs low over the
// open water, left of the girl. Upcoming words wait as fog — dim, soft, a
// swollen mist-ghost behind each one; as a word is sung the ghost burns off
// and a rain-streak wipe runs DOWN through the letters (the karaoke fill),
// a pale front line with droplets trailing beneath it. Held words breathe
// with a faint ripple. When the line finishes it sinks back into the mist
// and drifts astern — sliding slowly left as the ferry carries on.
//
// Staging: a CHORUS is full sail — the line rides larger over the water and
// its sung words take the lifebuoy warmth (the one warm loud thing on board,
// graded toward each song's album art), while the deck lifts a breath on
// each kick of the swell. In instrumental breaks the crossing carries on:
// rain drifts through the empty stage, and three deck lamps go dark one by
// one as the words come back from shore.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color dusk:  pal.cyan
    readonly property color slate: pal.dim
    readonly property color pale:  pal.text
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"
    readonly property string mono: pal.fontMono
    function paleA(a)  { return Qt.rgba(pale.r, pale.g, pale.b, a) }
    function duskA(a)  { return Qt.rgba(dusk.r, dusk.g, dusk.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }

    // the lifebuoy warmth, saved for the chorus — graded toward the album
    // art's vivid swatch (identity until the palette lands; the touches make
    // the binding re-evaluate when it does)
    readonly property color buoyLive: (engine.trackPaletteReady, engine.trackVivid,
                                       engine.trackTint(pal.neon, 0.30))
    function buoyLiveA(a) { return Qt.rgba(buoyLive.r, buoyLive.g, buoyLive.b, a) }

    // full sail: the chorus rides larger over the water
    readonly property bool fullSail: engine.inChorus

    // the deck lifts a breath on each kick of the swell
    property real swellKick: 0
    NumberAnimation { id: swellKickAnim; target: root; property: "swellKick"; from: 1; to: 0; duration: 260; easing.type: Easing.OutQuad }

    // the line hangs over the water, below the horizon, above the swell
    readonly property real lineX: Math.round(root.width * 0.05)
    readonly property real lineY: Math.round(root.height * 0.435)
    readonly property real lineW: Math.round(root.width * 0.40)
    readonly property real lyricSize: Math.round(34 * ui)

    // a finished line lingers briefly, then sinks back into the mist
    readonly property real lineHoldMs: 450
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // ── the line that came before drifts astern ─────────────────────────────
    // watch the joined line text; when it changes, the old one is still in
    // _prevJoined — hand it to the departing ghost before updating.
    readonly property string joined: engine.tokens.map(function (t) { return t.text }).join(" ")
    property string _prevJoined: ""
    onJoinedChanged: {
        if (_prevJoined !== "" && joined !== _prevJoined) departing.launch(_prevJoined)
        _prevJoined = joined
    }

    Text {
        id: departing
        function launch(t) {
            driftAway.stop()
            text = t
            driftAway.restart()
        }
        x: root.lineX
        y: root.lineY
        width: root.lineW
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        opacity: 0
        color: root.duskA(0.7)
        font.family: root.serif
        font.pixelSize: Math.round(root.lyricSize * 0.85)
        font.weight: Font.Light
        font.letterSpacing: 2

        ParallelAnimation {
            id: driftAway
            NumberAnimation { target: departing; property: "opacity"; from: 0.55; to: 0; duration: 1900; easing.type: Easing.InQuad }
            NumberAnimation { target: departing; property: "x"; from: root.lineX; to: root.lineX - 90; duration: 1900; easing.type: Easing.OutQuad }
            NumberAnimation { target: departing; property: "y"; from: root.lineY; to: root.lineY + 10; duration: 1900; easing.type: Easing.OutQuad }
            NumberAnimation { target: departing; property: "scale"; from: 1.0; to: 1.05; duration: 1900 }
        }
    }

    // ── the active line ─────────────────────────────────────────────────────
    Item {
        id: lineBox
        x: root.lineX
        y: root.lineY
        width: root.lineW
        height: flow.height
        opacity: root.lineExpired ? 0 : 1
        // full sail on the chorus; the swell kick rides its own transform so
        // it can't fight the scale Behavior
        scale: root.fullSail ? 1.14 : 1
        transformOrigin: Item.TopLeft
        transform: Translate { y: -3 * root.swellKick * root.ui }
        Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutQuad } }
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InQuad } }

        Flow {
            id: flow
            width: parent.width
            spacing: Math.round(root.lyricSize * 0.34)

            Repeater {
                model: root.engine.tokens
                delegate: Item {
                    id: wd
                    required property int index
                    required property var modelData        // {text, bg, mainIdx, t, d}
                    readonly property bool adlib: modelData.bg
                    // touch audioSilent so held-word releases re-evaluate on the
                    // silence flip even while estMs is static
                    readonly property var st: (root.engine.audioSilent,
                                               root.engine.tokenState(index, root.engine.estMs))
                    // 0 = still fog, 1 = surfaced (active or sung)
                    readonly property real reveal: (st.active || st.fill > 0) ? 1 : 0
                    // deterministic per-word jitter for the rain streaks
                    readonly property real seed: ((index * 73) % 17) / 17

                    readonly property real sizePx: root.lyricSize * (adlib ? 0.6 : 1)
                    width: base.implicitWidth
                    height: base.implicitHeight

                    // the mist ghost — a swollen soft double that burns off as
                    // the word surfaces (fog → focus, no per-word blur effects)
                    Text {
                        anchors.centerIn: parent
                        text: base.text
                        textFormat: Text.PlainText
                        color: root.duskA(0.4)
                        scale: 1.10 + 0.12 * (1 - wd.reveal)
                        opacity: 0.4 * (1 - wd.reveal)
                        Behavior on opacity { NumberAnimation { duration: 420 } }
                        Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutQuad } }
                        font.family: root.serif
                        font.pixelSize: wd.sizePx
                        font.weight: Font.Light
                        font.italic: wd.adlib
                        font.letterSpacing: 2
                    }

                    // the word waiting in the fog
                    Text {
                        id: base
                        text: wd.adlib ? "(" + wd.modelData.text + ")" : wd.modelData.text
                        textFormat: Text.PlainText
                        color: root.duskA(0.55)
                        opacity: 0.34 + 0.30 * wd.reveal
                        Behavior on opacity { NumberAnimation { duration: 320 } }
                        font.family: root.serif
                        font.pixelSize: wd.sizePx
                        font.weight: Font.Light
                        font.italic: wd.adlib
                        font.letterSpacing: 2
                    }

                    // the rain-wipe: the sung part, revealed top-down. On a
                    // chorus the surfaced words take the lifebuoy warmth.
                    Item {
                        id: wipe
                        width: parent.width
                        height: base.implicitHeight * wd.st.fill
                        clip: true
                        Text {
                            text: base.text
                            textFormat: Text.PlainText
                            color: wd.adlib ? root.duskA(0.9)
                                            : (root.fullSail ? root.buoyLive : root.paleA(0.96))
                            font.family: root.serif
                            font.pixelSize: wd.sizePx
                            font.weight: wd.adlib ? Font.Light : Font.Normal
                            font.italic: wd.adlib
                            font.letterSpacing: 2
                        }
                    }

                    // the wipe front: a pale rain line with droplets beneath,
                    // riding down the word while it's being sung
                    Item {
                        visible: wd.st.active && wd.st.fill < 1
                        y: wipe.height
                        width: parent.width
                        height: 8

                        Rectangle {
                            id: front
                            width: parent.width
                            height: 1
                            color: root.paleA(0.9)
                            // held words: the rain line breathes — a faint ripple
                            SequentialAnimation on opacity {
                                running: wd.st.sustain
                                loops: Animation.Infinite
                                alwaysRunToEnd: true
                                NumberAnimation { to: 0.35; duration: 650; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0.9; duration: 650; easing.type: Easing.InOutSine }
                            }
                        }
                        Rectangle {
                            x: parent.width * (0.2 + wd.seed * 0.3)
                            y: 1
                            width: 1
                            height: 4 + wd.seed * 3
                            color: root.paleA(0.55)
                        }
                        Rectangle {
                            x: parent.width * (0.6 + wd.seed * 0.35)
                            y: 1
                            width: 1
                            height: 3 + (1 - wd.seed) * 3
                            color: root.paleA(0.4)
                        }
                    }
                }
            }
        }
    }

    // ── interlude: the crossing carries on — rain through the empty stage ───
    Repeater {
        model: 6
        Rectangle {
            id: drop
            required property int index
            readonly property real seed: ((index * 41) % 13) / 13
            readonly property bool on: root.engine.inInterlude && root.engine.playing
            visible: on
            opacity: 0
            x: root.lineX + root.lineW * ((index * 0.17 + seed * 0.1) % 1)
            width: 1
            height: (10 + seed * 12) * root.ui
            color: root.paleA(0.35)
            SequentialAnimation {
                running: drop.on
                loops: Animation.Infinite
                ParallelAnimation {
                    NumberAnimation {
                        target: drop; property: "y"
                        from: root.lineY - root.lyricSize * (1.5 + drop.seed)
                        to: root.lineY + root.lyricSize * (1.2 + drop.seed * 0.6)
                        duration: 1400 + drop.seed * 900
                        easing.type: Easing.InQuad
                    }
                    SequentialAnimation {
                        NumberAnimation { target: drop; property: "opacity"; from: 0; to: 0.55; duration: 250 }
                        NumberAnimation { target: drop; property: "opacity"; to: 0; duration: 1100 + drop.seed * 900 }
                    }
                }
            }
        }
    }

    // ── three deck lamps go dark one by one: words coming back from shore ───
    readonly property bool countdownOn:
        engine.player !== null && engine.lyricsSynced && engine.playing
        && engine.nextLineInMs >= 0 && engine.nextLineInMs < 3200
        && (engine.inInterlude || engine.activeIndex < 0)
    Row {
        x: root.lineX
        y: root.lineY + Math.round(root.lyricSize * 0.35)
        spacing: Math.round(9 * root.ui)
        visible: root.countdownOn
        Repeater {
            model: 3
            Rectangle {
                required property int index
                readonly property bool lit: Math.ceil(root.engine.nextLineInMs / 1067) > index
                width: 6 * root.ui
                height: width
                radius: width / 2
                color: root.buoyLiveA(0.9)
                border.width: 1
                border.color: root.slateA(0.8)
                opacity: lit ? 0.9 : 0.15
                Behavior on opacity { NumberAnimation { duration: 240 } }
            }
        }
    }

    // ── status: the radio room, when there's nothing to sing ────────────────
    Text {
        x: root.lineX
        y: root.lineY + 6
        visible: root.engine.player !== null && root.engine.tokens.length === 0
                 && !root.countdownOn
        text: !root.engine.lyricsLoaded ? "· TUNING ·"
              : !root.engine.lyricsSynced ? "· NO WORDS FROM SHORE ·"
              : "· · —"
        textFormat: Text.PlainText
        color: root.duskA(0.55)
        font.family: root.mono
        font.pixelSize: Math.round(12 * root.ui)
        font.letterSpacing: 5
    }

    // ── offset OSD: the radio operator retunes ──────────────────────────────
    Text {
        id: offsetOsd
        function flash() { opacity = 0.9; osdHide.restart() }
        x: root.lineX
        y: root.lineY - Math.round(26 * root.ui)
        opacity: 0
        text: "RX OFFSET " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " MS"
        color: root.pale
        font.family: root.mono
        font.pixelSize: Math.round(11 * root.ui)
        font.letterSpacing: 4
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Timer { id: osdHide; interval: 1300; onTriggered: offsetOsd.opacity = 0 }
    }

    Connections {
        target: root.engine
        function onOffsetNudged() { offsetOsd.flash() }
        // the swell only kicks when the engine actually hears a beat, and only
        // while a line is up — quantized to the music, absent without cava
        function onBeat() { if (!root.lineExpired && root.engine.tokens.length > 0) swellKickAnim.restart() }
    }
}
