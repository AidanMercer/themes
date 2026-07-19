import QtQuick

// encore: the PIANO ROLL — the diva's part, printed as the vocal-synth roll
// it was sung from. STYLING ONLY; all machinery lives in the shell's
// LyricsEngine and arrives as `engine`.
//
// The active line becomes a bar of note blocks on eight ruled lanes: each
// word is a block whose lane is its pitch (a seeded melodic walk — the same
// line always sings the same shape), whose x/width are its real onset and
// duration inside the line. The karaoke sweep is the PLAYHEAD: a vertical
// cue line with a follow-spot head that crosses the roll in time; blocks
// sit dark until the playhead reaches them, LIGHT as they're sung (the fill
// is the lit length of the note), and the block under the head lifts into
// the warm spot-white "now" (law 4). Adlibs are ghost-notes: short magenta
// blocks floating in the two lanes above the melody — the crowd answering.
// Beneath the roll the lyric sheet prints the same words as text, lit
// word-by-word. Line changes are a blackout cut, never a crossfade (law 2).
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine

    readonly property color teal: pal.neon
    readonly property color lacquer: pal.cyan
    readonly property color crowd: pal.magenta
    readonly property color spot: pal.amber
    readonly property color rest: pal.dim
    readonly property color ink: pal.text
    readonly property string mono: pal.fontMono
    function tealA(a) { return Qt.rgba(teal.r, teal.g, teal.b, a) }
    function restA(a) { return Qt.rgba(rest.r, rest.g, rest.b, a) }
    function inkA(a)  { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    readonly property real ui: pal.uiScale

    // ── the roll's geometry: lower-left, above the glowstick sea ────────────
    readonly property real rollW: Math.round(root.width * 0.46)
    readonly property int mainLanes: 8
    readonly property int adlibLanes: 2
    readonly property real laneH: Math.round(24 * ui)
    readonly property real rollH: (mainLanes + adlibLanes) * laneH
    readonly property real rollX: Math.round(root.width * 0.055)
    readonly property real rollY: Math.round(root.height * 0.70) - rollH

    // ── timing map: the line's span, its beat count, each token's slot ──────
    readonly property var tokens: engine.tokens
    readonly property real lineT0: {
        if (!tokens.length) return 0
        let t0 = -1
        for (let i = 0; i < tokens.length; i++)
            if (tokens[i].t !== undefined && tokens[i].t >= 0) { t0 = tokens[i].t; break }
        return t0 < 0 ? 0 : t0
    }
    readonly property real lineT1: Math.max(engine.lineDoneMs, lineT0 + 800)
    readonly property real span: lineT1 - lineT0

    // deterministic hash — the same word lands on the same pitch every pass
    function hash(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }
    function wordSeed(s) {
        let h = 0
        for (let i = 0; i < s.length; i++) h = (Math.imul(h, 31) + s.charCodeAt(i)) | 0
        return h
    }

    // [{x, w, lane}] per token, in roll pixels. Melody walks lane-to-lane in
    // steps of ±1..2 (a seeded contour, not noise); adlibs float on top lanes.
    readonly property var layout: {
        const out = []
        const n = tokens.length
        if (n === 0 || span <= 0) return out
        let lane = 3 + Math.floor(hash((engine.activeIndex + 1) * 2654435761) * 3)   // start mid-roll
        for (let i = 0; i < n; i++) {
            const tk = tokens[i]
            const t = (tk.t !== undefined && tk.t >= 0) ? tk.t : (lineT0 + span * i / n)
            const d = (tk.d !== undefined && tk.d > 0) ? tk.d : span / (n + 1)
            const x = Math.max(0, Math.min(1, (t - lineT0) / span)) * rollW
            const w = Math.max(14 * ui, Math.min(1, d / span) * rollW - 3 * ui)
            if (tk.bg) {
                out.push({ x: x, w: w * 0.7, lane: wordSeed(tk.text) % adlibLanes })
            } else {
                const step = Math.floor(hash(wordSeed(tk.text)) * 5) - 2      // -2..+2
                lane = Math.max(0, Math.min(mainLanes - 1, lane + (step === 0 ? 1 : step)))
                out.push({ x: x, w: w, lane: adlibLanes + lane })
            }
        }
        return out
    }

    // playhead progress across the roll, 0..1
    readonly property real ph: span > 0 ? Math.max(0, Math.min(1, (engine.estMs - lineT0) / span)) : 0

    // clear a finished line early; blackout gate on every line change
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + 350
    property bool gate: true
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() { root.gate = false; gateCut.restart() }
        function onOffsetNudged() { offsetOsd.flash() }
    }
    readonly property bool rollUp: tokens.length > 0 && gate && !lineExpired

    // ── the roll ────────────────────────────────────────────────────────────
    Item {
        id: roll
        x: root.rollX
        y: root.rollY
        width: root.rollW
        height: root.rollH
        opacity: root.rollUp ? 1 : 0          // hard cut — blackout, not fade
        visible: opacity > 0

        // lane rules: eight melody lanes + two ghost lanes above, faint
        Repeater {
            model: root.mainLanes + root.adlibLanes
            Rectangle {
                required property int index
                readonly property bool ghost: index < root.adlibLanes
                y: index * root.laneH + root.laneH - 1
                width: roll.width
                height: 1
                color: ghost ? Qt.rgba(root.crowd.r, root.crowd.g, root.crowd.b, 0.10)
                             : root.restA(0.22)
            }
        }
        // left rule — the barline the roll scrolls from
        Rectangle { width: 2; height: roll.height; color: root.restA(0.4) }

        // the beat grid: one tick per 500ms of the line, whole beats only
        Repeater {
            model: Math.max(0, Math.min(64, Math.floor(root.span / 500)))
            Rectangle {
                required property int index
                x: Math.round(((index + 1) * 500 / root.span) * roll.width)
                width: 1
                height: roll.height
                color: root.restA((index + 1) % 4 === 0 ? 0.28 : 0.13)
            }
        }

        // ── the note blocks ────────────────────────────────────────────────
        Repeater {
            model: root.tokens
            delegate: Item {
                id: note
                required property int index
                required property var modelData
                readonly property bool bg: modelData.bg
                // touch audioSilent so held releases re-evaluate at silence
                readonly property var st: (root.engine.audioSilent,
                                           root.engine.tokenState(index, root.engine.estMs))
                readonly property var p: root.layout[index]
                                         ? root.layout[index] : ({ x: 0, w: 20, lane: 3 })
                readonly property bool sung: st.fill >= 1
                readonly property bool now: st.active && !sung

                x: p.x
                y: p.lane * root.laneH + (bg ? 7 * root.ui : 4 * root.ui)
                       - (now && !bg ? 2 * root.ui : 0)          // the lift under the spot
                width: p.w
                height: root.laneH - (bg ? 13 : 8) * root.ui

                // unlit block: the note is printed on the roll, waiting
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: note.bg ? Qt.rgba(root.crowd.r, root.crowd.g, root.crowd.b, 0.4)
                                          : root.restA(0.65)
                }
                // the lit length — exactly as much of the note as has been sung
                Rectangle {
                    x: 0
                    width: Math.max(0, Math.min(1, note.st.fill)) * parent.width
                    height: parent.height
                    radius: height / 2
                    color: note.bg ? Qt.rgba(root.crowd.r, root.crowd.g, root.crowd.b, 0.75)
                         : note.now ? root.spot
                         : root.tealA(0.9)
                }
                // sustain shimmer: a held note breathes at the tip, on the beat
                Rectangle {
                    visible: note.st.sustain === true && note.now
                    x: Math.max(0, Math.min(1, note.st.fill) * parent.width - height)
                    width: height
                    height: parent.height
                    radius: height / 2
                    color: root.spot
                    property bool tick: true
                    opacity: tick ? 0.9 : 0.35
                    Timer {
                        interval: 250; repeat: true
                        running: note.st.sustain === true && note.now && root.rollUp
                        onTriggered: parent.tick = !parent.tick
                    }
                }
            }
        }

        // ── the playhead: the cue line + its follow-spot head ──────────────
        Item {
            id: playhead
            x: Math.round(root.ph * roll.width)
            visible: root.engine.activeIndex >= 0
            Rectangle {
                x: -1
                width: 2
                height: roll.height
                color: root.spot
                opacity: 0.85
            }
            // the head: a warm glow that swells with the bass (fail-open)
            Rectangle {
                readonly property real swell:
                    root.engine.audioReady ? root.engine.audioPulse * 0.5 : 0
                x: -width / 2 + 1
                y: -height / 2
                width: (10 + 8 * swell) * root.ui
                height: width
                radius: width / 2
                color: Qt.rgba(root.spot.r, root.spot.g, root.spot.b, 0.30)
            }
        }
    }

    // ── the lyric sheet: the same line as printed text, lit word by word ────
    Flow {
        id: sheet
        x: root.rollX
        y: root.rollY + root.rollH + Math.round(14 * root.ui)
        width: root.rollW
        spacing: Math.round(9 * root.ui)
        opacity: root.rollUp ? 1 : 0          // same blackout as the roll
        visible: opacity > 0

        Repeater {
            model: root.tokens
            delegate: Text {
                required property int index
                required property var modelData
                readonly property var st: (root.engine.audioSilent,
                                           root.engine.tokenState(index, root.engine.estMs))
                readonly property bool bg: modelData.bg
                text: bg ? "(" + modelData.text + ")" : modelData.text
                textFormat: Text.PlainText
                color: bg ? root.crowd
                     : (st.active && st.fill < 1) ? root.spot
                     : st.fill >= 1 ? root.teal
                     : root.inkA(0.4)
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.55)
                font.family: root.mono
                font.pixelSize: Math.round((bg ? 15 : 21) * root.ui)
                font.weight: st.active ? Font.Black : Font.DemiBold
                font.italic: bg
            }
        }
    }

    // ── status: the rig between lines / without a score ─────────────────────
    Text {
        x: root.rollX
        y: root.rollY + root.rollH + Math.round(14 * root.ui)
        visible: root.engine.player !== null && root.tokens.length === 0
        text: !root.engine.lyricsLoaded ? "TUNING…"
              : !root.engine.lyricsSynced ? "INSTRUMENTAL — NO SCORE"
              : "♪"
        color: root.tealA(0.7)
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.5)
        font.family: root.mono
        font.pixelSize: Math.round(14 * root.ui)
        font.letterSpacing: 5
    }

    // ── calibration OSD: the monitor engineer's nudge readout ───────────────
    Text {
        id: offsetOsd
        function flash() { opacity = 1; osdHide.restart() }
        x: root.rollX
        y: root.rollY - Math.round(26 * root.ui)
        opacity: 0
        text: "MONITOR DELAY " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " MS"
        color: root.spot
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.55)
        font.family: root.mono
        font.pixelSize: Math.round(13 * root.ui)
        font.letterSpacing: 3
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
    }
}
