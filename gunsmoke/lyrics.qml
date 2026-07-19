import QtQuick

// gunsmoke: the verses, set like wanted-poster type in the fog of the lower
// left — STYLING ONLY, the engine does the timing. Each line composes as
// centered rows of stamped capitals. A word doesn't fade in: it is STAMPED
// (hammer law — a fast slam from oversize with a one-frame flash) the moment
// it's sung, arriving as ghost type — hollow, ash-grey — and the karaoke
// sweep INKS it: a fill wipe turns the hollow letters solid bone as the
// syllables land. Held words smolder with the bass. When the line is done it
// leaves the way smoke does — a slow up-drift dissolve (smoke law). Adlibs
// are margin notes: small, italic, gunmetal, in their parens.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color bone: pal.neon
    readonly property color steel: pal.cyan
    readonly property color ash: pal.dim
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif"
    function boneA(a)  { return Qt.rgba(bone.r, bone.g, bone.b, a) }
    function steelA(a) { return Qt.rgba(steel.r, steel.g, steel.b, a) }
    function ashA(a)   { return Qt.rgba(ash.r, ash.g, ash.b, a) }

    // ---- poster layout ------------------------------------------------------
    readonly property real aspect: root.height > 0 ? root.width / root.height : 1.78
    readonly property bool ultrawide: aspect > 2.4
    property real lyricSize: Math.round((ultrawide ? 52 : 38) * pal.uiScale)
    readonly property real charW: lyricSize * 0.60 + 2   // mono advance + letterspacing

    // the box sits in the lower-left murk, clear of the clock (upper-left),
    // the fog-bank cava hugs the very bottom below it
    readonly property real boxW: Math.round(root.width * (ultrawide ? 0.26 : 0.40))
    readonly property real boxX: Math.round(root.width * 0.055)
    readonly property real boxY: Math.round(root.height * 0.50)

    // centered-row poster layout: [{x,y,size}] per token
    function compose(words, bgs) {
        const n = words.length
        if (n === 0) return []
        const out = []
        const rowH = lyricSize * 1.22
        let row = [], rows = []
        let cx = 0
        for (let i = 0; i < n; i++) {
            const f = bgs[i] ? 0.58 : 1
            const cw = (lyricSize * f) * 0.60 + 2
            const wPx = Math.max(cw, (words[i].length + (bgs[i] ? 2 : 0)) * cw)
            if (cx + wPx > boxW && row.length) { rows.push(row); row = []; cx = 0 }
            row.push({ i: i, w: wPx, f: f })
            cx += wPx + cw * 0.8
        }
        if (row.length) rows.push(row)
        for (let r = 0; r < rows.length; r++) {
            let total = 0
            for (const t of rows[r]) total += t.w
            total += (rows[r].length - 1) * charW * 0.8
            let x = (boxW - total) / 2
            for (const t of rows[r]) {
                out[t.i] = { x: x, y: r * rowH, size: lyricSize * t.f }
                x += t.w + charW * 0.8
            }
        }
        return out
    }

    readonly property var curLayout: compose(
        engine.tokens.map(function (t) { return t.text }),
        engine.tokens.map(function (t) { return t.bg === true }))

    // clear a finished line early — it shouldn't hang through the gap
    readonly property real lineHoldMs: 350
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // brief blank cut on line change so only one line ever shows
    property bool gate: true
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() { root.gate = false; gateCut.restart() }
        function onOffsetNudged() { offsetOsd.flash() }
    }

    Item {
        id: region
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
                readonly property var p: root.curLayout[index] ? root.curLayout[index] : ({ x: 0, y: 0, size: root.lyricSize })
                readonly property real fillFrac: st.active ? Math.max(0, Math.min(1, st.fill)) : (st.fill >= 1 ? 1 : 0)
                readonly property string word: bg ? "(" + modelData.text + ")" : modelData.text.toUpperCase()
                // held words smolder with the bass
                readonly property real smolder:
                    (st.active && st.sustain && !wd.bg && root.engine.audioReady)
                        ? root.engine.audioPulse * 0.05 : 0

                x: root.boxX + p.x
                y: root.boxY + p.y + (wd.bg ? p.size * 0.3 : 0) + (shown ? 0 : -14)
                width: ghost.implicitWidth
                height: ghost.implicitHeight
                transformOrigin: Item.Center

                // stamped in fast; dissipates upward slow (hammer in, smoke out)
                opacity: shown ? (wd.bg ? 0.65 : 1) : 0
                scale: shown ? (1 + smolder) : 1.3
                Behavior on opacity { NumberAnimation { duration: wd.shown ? 70 : 520; easing.type: Easing.OutQuad } }
                Behavior on scale   { NumberAnimation { duration: wd.shown ? 90 : 520; easing.type: Easing.OutQuad } }
                Behavior on y       { enabled: !wd.shown; NumberAnimation { duration: 520; easing.type: Easing.OutQuad } }

                // ghost type: hollow ash letters, waiting for ink
                Text {
                    id: ghost
                    text: wd.word
                    textFormat: Text.PlainText
                    color: "transparent"
                    style: Text.Outline
                    styleColor: wd.bg ? root.steelA(0.55) : root.ashA(0.9)
                    font.family: root.mono
                    font.pixelSize: wd.p.size
                    font.weight: wd.bg ? Font.DemiBold : Font.Black
                    font.italic: wd.bg
                    font.letterSpacing: 2
                }
                // the ink: solid bone, wiped on left-to-right by the sweep
                Item {
                    width: ghost.implicitWidth * wd.fillFrac
                    height: ghost.implicitHeight
                    clip: true
                    Text {
                        text: wd.word
                        textFormat: Text.PlainText
                        color: wd.bg ? root.steelA(0.8) : root.boneA(0.95)
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.5)
                        font.family: root.mono
                        font.pixelSize: wd.p.size
                        font.weight: wd.bg ? Font.DemiBold : Font.Black
                        font.italic: wd.bg
                        font.letterSpacing: 2
                    }
                }
                // the stamp flash: one frame of bone over the strike
                Rectangle {
                    id: stampFlash
                    anchors.fill: ghost
                    anchors.margins: -3
                    color: root.boneA(0.4)
                    opacity: 0
                }
                SequentialAnimation {
                    id: stampAnim
                    PropertyAction { target: stampFlash; property: "opacity"; value: 0.5 }
                    PauseAnimation { duration: 45 }
                    PropertyAction { target: stampFlash; property: "opacity"; value: 0 }
                }
                onShownChanged: if (shown && !wd.bg) stampAnim.restart()
            }
        }

        // status while a track plays but no verse is up
        Text {
            x: root.boxX
            y: root.boxY
            visible: root.engine.player !== null && root.engine.tokens.length === 0
            text: !root.engine.lyricsLoaded ? "SEARCHING THE LEDGER…"
                  : !root.engine.lyricsSynced ? "NO VERSES ON FILE"
                  : "♪"
            color: root.ashA(1)
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.5)
            font.family: root.serif
            font.pixelSize: Math.round(root.lyricSize * 0.42)
            font.weight: Font.Bold
            font.letterSpacing: 4
        }

        // sight-adjust OSD — flashes while calibrating the offset by ear
        Text {
            id: offsetOsd
            function flash() { opacity = 1; osdHide.restart() }
            x: root.boxX
            y: root.boxY - root.lyricSize * 1.1
            opacity: 0
            text: "SIGHT ADJUST " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " MS"
            color: root.boneA(0.9)
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.5)
            font.family: root.serif
            font.pixelSize: Math.round(root.lyricSize * 0.36)
            font.weight: Font.Bold
            font.letterSpacing: 3
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
        }
    }
}
