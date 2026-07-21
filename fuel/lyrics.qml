import QtQuick
import QtQuick.Effects

// fuel: neon-sign karaoke, hung in the empty upper-right night sky — the
// station's second sign. The WHOLE active line is there from the start as
// unpowered glass tubes (cold gray outlines); as each word is sung its tube
// powers ON left-to-right with the karaoke fill, stuttering like a starter
// before holding steady. The word being sung right now buzzes with a soft
// halo; a held last note hums brighter, its halo breathing with the actual
// bass (engine.audioPulse). A bent-corner neon underline — the canopy
// stripe — draws beneath the line as it completes. Released lines power
// down to dead glass and fade. Adlibs are small icy-cyan side tubes.
// Styling only — all timing lives in the shell's LyricsEngine.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color neon:  pal.neon
    readonly property color ice:   pal.cyan
    readonly property color amber: pal.amber
    readonly property color ink:   pal.text
    readonly property string mono: pal.fontMono
    function neonA(a) { return Qt.rgba(neon.r, neon.g, neon.b, a) }
    function iceA(a)  { return Qt.rgba(ice.r, ice.g, ice.b, a) }
    function inkA(a)  { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    // unpowered tube glass: cold desaturated gray-blue
    readonly property color glassTube: Qt.rgba(0.42, 0.46, 0.50, 1)

    // ---- sign geometry: upper-right box, clear of clock (left) and bar -----
    readonly property real aspect: root.height > 0 ? root.width / root.height : 1.78
    readonly property bool ultrawide: aspect > 2.4
    property real lyricSize: Math.round((ultrawide ? 46 : 38) * pal.uiScale)
    readonly property real charW: lyricSize * 0.62          // mono advance + tracking
    readonly property real rowH: lyricSize * 1.5
    readonly property real boxW: Math.min(Math.round((ultrawide ? 760 : 640) * pal.uiScale),
                                          Math.round(root.width * 0.40))
    readonly property real boxX: Math.round(root.width * 0.955) - boxW
    readonly property real boxY: Math.round(root.height * 0.075)

    // sequential wrap layout: [{x,y,w,scale}] per token
    function layoutTokens(tokens) {
        const out = []
        let cx = 0, cy = 0
        const gap = charW * 0.9
        for (let i = 0; i < tokens.length; i++) {
            const t = tokens[i]
            const scale = t.bg ? 0.5 : 1
            const w = Math.max(1, t.text.length) * charW * scale
            if (cx + w > boxW && cx > 0) { cx = 0; cy += rowH }
            out.push({ x: cx, y: cy, w: w, scale: scale })
            cx += w + gap * scale
        }
        return out
    }
    readonly property var curLayout: layoutTokens(engine.tokens)
    readonly property real lineH: curLayout.length > 0
        ? curLayout[curLayout.length - 1].y + rowH : rowH

    // ---- line lifecycle ----------------------------------------------------
    readonly property real lineHoldMs: 350
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs
    property bool gate: true
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() { root.gate = false; gateCut.restart() }
        function onOffsetNudged() { offsetOsd.flash() }
    }
    readonly property bool lineShown: engine.tokens.length > 0 && gate && !lineExpired

    // line-level progress for the bent underline (0..1 across the line's span)
    readonly property real lineT: {
        const toks = engine.tokens
        if (toks.length === 0) return 0
        const t0 = toks[0].t
        const t1 = engine.lineDoneMs
        if (t1 <= t0) return 0
        return Math.max(0, Math.min(1, (engine.estMs - t0) / (t1 - t0)))
    }

    // ---- the sign ------------------------------------------------------------
    Item {
        id: region
        x: root.boxX
        y: root.boxY
        width: root.boxW
        height: root.lineH + root.rowH

        opacity: root.lineShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

        Repeater {
            model: root.engine.tokens
            delegate: Item {
                id: wd
                required property int index
                required property var modelData          // {text, bg, mainIdx, t, d}
                readonly property bool bg: modelData.bg
                // touch audioSilent so held-word releases re-evaluate instantly
                readonly property var st: (root.engine.audioSilent,
                                           root.engine.tokenState(index, root.engine.estMs))
                readonly property var p: root.curLayout[index]
                    ? root.curLayout[index] : ({ x: 0, y: 0, w: 0, scale: 1 })
                readonly property real sizePx: root.lyricSize * p.scale
                readonly property string shown: wd.bg
                    ? "(" + modelData.text + ")" : modelData.text.toUpperCase()
                readonly property color litCol: wd.bg ? root.ice : root.neon

                // buzz-in: when the word first goes active, stutter like a
                // starter; powerT multiplies the lit tube's strength
                property real powerT: 1
                readonly property bool isOn: st.active || st.fill > 0
                onIsOnChanged: if (isOn) buzz.restart()
                SequentialAnimation {
                    id: buzz
                    NumberAnimation { target: wd; property: "powerT"; to: 0.35; duration: 40 }
                    NumberAnimation { target: wd; property: "powerT"; to: 0.9;  duration: 45 }
                    NumberAnimation { target: wd; property: "powerT"; to: 0.5;  duration: 50 }
                    NumberAnimation { target: wd; property: "powerT"; to: 1.0;  duration: 80 }
                }

                x: p.x
                y: p.y + (wd.bg ? sizePx * 0.5 : 0)
                width: p.w
                height: sizePx * 1.3

                // dead glass tube: the whole word, always there while the line shows
                Text {
                    id: tube
                    text: wd.shown
                    textFormat: Text.PlainText
                    color: root.glassTube
                    opacity: 0.38
                    font.family: root.mono
                    font.weight: Font.Bold
                    font.italic: wd.bg
                    font.pixelSize: wd.sizePx
                    font.letterSpacing: wd.sizePx * 0.04
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.45)
                }

                // lit tube, clipped to the karaoke fill sweeping left→right
                Item {
                    id: litClip
                    clip: true
                    width: tube.width * wd.st.fill
                    height: tube.height
                    Behavior on width { NumberAnimation { duration: 70 } }

                    // halo: two soft scaled copies behind the core
                    Text {
                        anchors.centerIn: core
                        text: wd.shown
                        textFormat: Text.PlainText
                        color: wd.litCol
                        opacity: 0.30 * wd.powerT
                        scale: 1.10
                        font: core.font
                    }
                    Text {
                        anchors.centerIn: core
                        text: wd.shown
                        textFormat: Text.PlainText
                        color: wd.litCol
                        opacity: 0.55 * wd.powerT
                        scale: 1.04
                        font: core.font
                    }
                    // crisp tube core: hot near-white center of the neon
                    Text {
                        id: core
                        text: wd.shown
                        textFormat: Text.PlainText
                        color: Qt.rgba(
                            wd.litCol.r + (1 - wd.litCol.r) * 0.55,
                            wd.litCol.g + (1 - wd.litCol.g) * 0.55,
                            wd.litCol.b + (1 - wd.litCol.b) * 0.55, 1)
                        opacity: Math.max(0.25, wd.powerT)
                        font.family: root.mono
                        font.weight: Font.Bold
                        font.italic: wd.bg
                        font.pixelSize: wd.sizePx
                        font.letterSpacing: wd.sizePx * 0.04
                    }
                }

                // held-note hum: a real blurred halo breathing with the bass —
                // only ever mounted for the sustained word (at most one)
                Loader {
                    active: wd.st.sustain && root.lineShown
                    anchors.fill: litClip
                    sourceComponent: MultiEffect {
                        source: litClip
                        autoPaddingEnabled: true
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 26
                        colorization: 1.0
                        colorizationColor: wd.litCol
                        opacity: 0.45 + 0.45 * (root.engine.audioReady ? root.engine.audioPulse : 0.3)
                    }
                }
            }
        }

        // the canopy underline: a bent-corner neon tube drawing with the line
        Canvas {
            id: stripe
            x: 0
            y: root.lineH + 4
            width: region.width
            height: 12
            readonly property real t: root.lineT
            onTChanged: requestPaint()
            onWidthChanged: requestPaint()
            Connections {
                target: root.pal
                function onNeonChanged() { stripe.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, c = 8
                // dead tube: full path, faint
                function path(frac) {
                    const end = Math.max(c * 2, w * frac)
                    ctx.beginPath()
                    ctx.moveTo(1, 1)
                    ctx.lineTo(c, 1 + c * 0.75)
                    ctx.lineTo(end - c, 1 + c * 0.75)
                    ctx.lineTo(end - 1, 1)
                }
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                path(1)
                ctx.strokeStyle = root.glassTube
                ctx.globalAlpha = 0.25
                ctx.lineWidth = 1.5
                ctx.stroke()
                if (stripe.t > 0.02) {
                    path(stripe.t)
                    ctx.strokeStyle = root.pal.neon
                    ctx.globalAlpha = 0.22
                    ctx.lineWidth = 4.5
                    ctx.stroke()
                    ctx.globalAlpha = 0.95
                    ctx.lineWidth = 1.6
                    ctx.stroke()
                }
                ctx.globalAlpha = 1
            }
        }
    }

    // status when a track's playing but there's no line to light
    Row {
        x: root.boxX + root.boxW - width
        y: root.boxY
        spacing: 10
        visible: root.engine.player !== null && root.engine.tokens.length === 0
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Rectangle { width: 18; height: 2; color: root.amber; opacity: 0.6 }
            Rectangle { width: 18; height: 2; color: root.neon; opacity: 0.7 }
            Rectangle { width: 18; height: 2; color: pal.magenta; opacity: 0.5 }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: !root.engine.lyricsLoaded ? "LOADING LYRICS…"
                  : !root.engine.lyricsSynced ? "NO LYRICS"
                  : "♪"
            color: root.glassTube
            opacity: 0.8
            font.family: root.mono
            font.pixelSize: Math.round(14 * pal.uiScale)
            font.letterSpacing: 3
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.45)
        }
    }

    // live offset readout, flashed while calibrating by ear
    Text {
        id: offsetOsd
        function flash() { opacity = 1; osdHide.restart() }
        x: root.boxX + root.boxW - width
        y: root.boxY - Math.round(24 * pal.uiScale)
        opacity: 0
        text: "OFFSET " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " ms"
        color: root.amber
        font.family: root.mono
        font.weight: Font.Bold
        font.pixelSize: Math.round(15 * pal.uiScale)
        font.letterSpacing: 2
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.5)
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
    }
}
