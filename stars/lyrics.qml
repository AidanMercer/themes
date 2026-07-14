import QtQuick

// stars: constellation karaoke — STYLING ONLY, the engine (MPRIS clock,
// lyric fetch, per-word pacing) arrives as `engine`.
//
// The active line is charted as a constellation over the dark sea band under
// the horizon: every word hangs on the line's gentle catenary sag, and each
// word is first only its stars — one faint star per letter, joined by
// hairlines, the whole line sketched the moment it begins. As a word is sung
// the starlight sweeps through it (engine karaoke fill): its stars and
// hairlines brighten to amber and the letters condense out of them one by
// one. A held note twinkles. When the line completes, a shooting star
// crosses the chart and the old constellation dims back to faint stars
// until the next line is drawn. Adlibs float as small coral star-clusters
// without hairlines. Click-through scenery.
//
// Staging: a CHORUS is a whole-sky moment — the line charts larger and higher,
// up into the star field, hairlines burning brighter, a shooting star greeting
// its first line. The whole chart breathes on the kick drum. Instrumental
// breaks bring a sparse meteor shower, and three stars go out one by one as a
// countdown to the next verse. The lit starlight is graded toward each song's
// album art.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial properties)
    required property var pal
    required property var engine
    readonly property color amber: pal.neon
    readonly property color coral: pal.cyan
    readonly property color slate: pal.dim
    readonly property color ink:   pal.text
    readonly property string mono: pal.fontMono
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }

    // the lit starlight takes each song's own hue (fail-open: identity until
    // the album-art palette lands; the touches re-evaluate the binding then)
    readonly property color amberLive: (engine.trackPaletteReady, engine.trackVivid,
                                        engine.trackTint(amber, 0.30))

    // whole-sky staging: the chorus charts bigger, up into the star field
    readonly property bool skywide: engine.inChorus
    readonly property real stageK: skywide ? 1.22 : 1

    // the chart breathes on the kick drum
    property real beatKick: 0
    NumberAnimation { id: beatKickAnim; target: root; property: "beatKick"; from: 1; to: 0; duration: 160; easing.type: Easing.OutQuad }

    // ---- chart geometry ----------------------------------------------------
    readonly property real lyricSize: Math.round(30 * pal.uiScale)
    readonly property real charW: lyricSize * 0.60          // mono advance
    readonly property real wordH: lyricSize * 1.6
    readonly property real rowH: lyricSize * 2.15
    readonly property real boxW: Math.round(root.width * 0.60)
    readonly property real boxX: Math.round((root.width - boxW) / 2)
    readonly property real boxY: Math.round(root.height * 0.535)
    readonly property real sag: lyricSize * 0.85             // catenary dip

    function rng32(seed) {
        let a = seed >>> 0
        return function () {
            a = (a + 0x6D2B79F5) | 0
            let t = Math.imul(a ^ (a >>> 15), 1 | a)
            t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296
        }
    }

    // layout: words strung left→right along a sagging wire of stars, wrapping
    // to further rows; every row is centered and dips through its middle.
    // returns [{x,y,size}] in box coordinates, seeded per line. A chorus line
    // (`big`) charts scaled up across a wider box — the region bindings move
    // it up into the sky at the same moment, hidden by the line-change cut.
    function chart(seedIdx, toks, big) {
        const n = toks.length
        if (n === 0) return []
        const r = rng32((seedIdx + 1) * 2654435761)
        const sz = lyricSize * (big ? 1.22 : 1)
        const cw = sz * 0.60
        const bw = big ? Math.round(root.width * 0.72) : boxW
        const rH = sz * 2.15
        const sg = sz * 0.85
        const gap = cw * 1.1
        // first pass: assign words to rows
        const rows = []
        let cur = [], curW = 0
        for (let i = 0; i < n; i++) {
            const f = toks[i].bg ? 0.62 : 1.0
            // adlibs render wrapped in their parens — width includes them
            const chars = toks[i].text.length + (toks[i].bg ? 2 : 0)
            const wPx = Math.max(1, chars) * cw * f
            if (curW > 0 && curW + gap + wPx > bw) {
                rows.push({ words: cur, w: curW })
                cur = []; curW = 0
            }
            cur.push({ i: i, w: wPx, f: f })
            curW += (curW > 0 ? gap : 0) + wPx
        }
        if (cur.length) rows.push({ words: cur, w: curW })
        // second pass: center each row, sag through the middle, jitter a bit
        const out = new Array(n)
        for (let ri = 0; ri < rows.length; ri++) {
            const row = rows[ri]
            let x = (bw - row.w) / 2
            for (let k = 0; k < row.words.length; k++) {
                const wd = row.words[k]
                const t = bw > 0 ? (x + wd.w / 2) / bw : 0.5
                const dip = sg * (1 - (2 * t - 1) * (2 * t - 1))
                const jit = (r() - 0.5) * sz * 0.55
                out[wd.i] = {
                    x: x,
                    y: ri * rH + dip + jit,
                    size: sz * wd.f * (0.94 + r() * 0.12)
                }
                x += wd.w + gap
            }
        }
        return out
    }

    readonly property var curLayout:
        chart(engine.activeIndex, engine.tokens, engine.inChorus)

    // per-line star jitter seeds (one rng stream per line for letter stars)
    readonly property int lineSeed: (engine.activeIndex + 1) * 40503

    // finished line: hold briefly, then dim back to faint stars
    readonly property real lineHoldMs: 350
    readonly property bool lineExpired:
        engine.activeIndex >= 0 && engine.estMs > engine.lineDoneMs + lineHoldMs

    // hard cut between lines so only one constellation is ever charted
    property bool gate: true
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }
    Connections {
        target: root.engine
        function onActiveIndexChanged() {
            root.gate = false; gateCut.restart()
            // a shooting star greets the chorus as its first line is charted
            if (root.engine.inChorus && !root.wasChorus) streakAnim.restart()
            root.wasChorus = root.engine.inChorus
        }
        function onOffsetNudged() { offsetOsd.flash() }
        // quantized: the chart's breath lands on the kick drum
        function onBeat() { if (root.gate && !root.lineExpired && root.engine.tokens.length > 0) beatKickAnim.restart() }
    }
    property bool wasChorus: false

    // the line-complete shooting star
    property real streakT: -1
    SequentialAnimation {
        id: streakAnim
        NumberAnimation { target: root; property: "streakT"; from: 0; to: 1; duration: 850; easing.type: Easing.InOutQuad }
        PropertyAction { target: root; property: "streakT"; value: -1 }
    }
    onLineExpiredChanged: if (lineExpired && gate && engine.tokens.length > 0) streakAnim.restart()

    // ---- the chart ----------------------------------------------------------
    Item {
        id: region
        // the chorus charts up into the star field, wider; verses stay over the
        // sea band. The jump happens under the line-change cut.
        x: root.skywide ? Math.round((root.width - width) / 2) : root.boxX
        y: root.skywide ? Math.round(root.height * 0.42) : root.boxY
        width: root.skywide ? Math.round(root.width * 0.72) : root.boxW
        height: root.rowH * 3 + root.sag
        // the whole chart breathes on the kick drum
        scale: 1 + root.beatKick * 0.012
        transformOrigin: Item.Center

        Repeater {
            model: root.engine.tokens
            delegate: Item {
                id: wd
                required property int index
                required property var modelData          // {text, bg, mainIdx, t, d}
                readonly property bool bg: modelData.bg
                readonly property string word: bg ? "(" + modelData.text + ")" : modelData.text
                readonly property int nCh: word.length
                // touch audioSilent so held-word releases re-evaluate promptly
                readonly property var st: (root.engine.audioSilent,
                                           root.engine.tokenState(index, root.engine.estMs))
                readonly property var p: root.curLayout[index] ? root.curLayout[index]
                                       : ({ x: 0, y: 0, size: root.lyricSize })
                readonly property real cw: p.size * 0.60
                readonly property real wh: root.wordH * root.stageK
                readonly property real fillW: Math.max(0, Math.min(1, st.fill)) * width

                // deterministic star spots, one per letter
                readonly property var stars: {
                    const r = root.rng32(root.lineSeed + index * 7919)
                    const a = []
                    for (let j = 0; j < nCh; j++) {
                        a.push({
                            x: j * cw + cw * (0.25 + r() * 0.5),
                            y: wd.wh * (0.12 + r() * 0.72),
                            big: r() < 0.3
                        })
                    }
                    return a
                }

                x: wd.p.x
                y: wd.p.y
                width: nCh * cw
                height: wd.wh

                visible: root.gate && root.engine.tokens.length > 0
                opacity: root.lineExpired ? 0.22 : 1
                Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutQuad } }

                function paintStars(ctx, col, dotAlpha, lineAlpha) {
                    ctx.reset()
                    const s = wd.stars
                    if (!s.length) return
                    // hairlines between neighbouring stars (main words only)
                    if (!wd.bg && s.length > 1 && lineAlpha > 0) {
                        ctx.strokeStyle = col
                        ctx.globalAlpha = lineAlpha
                        ctx.lineWidth = 0.8
                        ctx.beginPath()
                        ctx.moveTo(s[0].x, s[0].y)
                        for (let j = 1; j < s.length; j++) ctx.lineTo(s[j].x, s[j].y)
                        ctx.stroke()
                    }
                    ctx.globalAlpha = dotAlpha
                    ctx.fillStyle = col
                    for (let j = 0; j < s.length; j++) {
                        const rad = s[j].big ? 2.2 : 1.4
                        ctx.beginPath()
                        ctx.arc(s[j].x, s[j].y, rad, 0, Math.PI * 2)
                        ctx.fill()
                        if (s[j].big) {   // four-point sparkle on the bigger stars
                            ctx.globalAlpha = dotAlpha * 0.7
                            ctx.lineWidth = 0.8
                            ctx.strokeStyle = col
                            ctx.beginPath()
                            ctx.moveTo(s[j].x - rad * 2.4, s[j].y); ctx.lineTo(s[j].x + rad * 2.4, s[j].y)
                            ctx.moveTo(s[j].x, s[j].y - rad * 2.4); ctx.lineTo(s[j].x, s[j].y + rad * 2.4)
                            ctx.stroke()
                            ctx.globalAlpha = dotAlpha
                        }
                    }
                    ctx.globalAlpha = 1
                }

                // faint sketch: the whole word's stars, there from line start
                Canvas {
                    id: dimStars
                    anchors.fill: parent
                    onPaint: wd.paintStars(getContext("2d"), String(root.inkA(1)), 0.34, wd.bg ? 0 : 0.13)
                    Connections {
                        target: root.pal
                        function onTextChanged() { dimStars.requestPaint() }
                    }
                    Component.onCompleted: requestPaint()
                }

                // lit constellation: same geometry in amber (coral for adlibs),
                // revealed by the karaoke fill via a clipping window — no
                // repaints while the sweep runs, just a width change.
                Item {
                    clip: true
                    width: wd.fillW
                    height: parent.height
                    opacity: twinkle.running ? 1 : (wd.st.active || wd.st.fill > 0 ? 1 : 0)
                    Canvas {
                        id: litStars
                        width: wd.width
                        height: wd.height
                        onPaint: paintLit()
                        // graded starlight; chorus hairlines burn brighter. Both
                        // read at paint time only — delegates recreate per line,
                        // so no new per-frame repaint triggers.
                        function paintLit() {
                            wd.paintStars(getContext("2d"),
                                          String(wd.bg ? root.coral : root.amberLive),
                                          0.95, wd.bg ? 0 : (root.skywide ? 0.75 : 0.5))
                        }
                        Connections {
                            target: root.pal
                            function onNeonChanged() { litStars.requestPaint() }
                            function onCyanChanged() { litStars.requestPaint() }
                        }
                        // the album-art palette can land mid-line
                        Connections {
                            target: root.engine
                            function onTrackVividChanged() { litStars.requestPaint() }
                        }
                        Component.onCompleted: requestPaint()
                    }
                }

                // the letters, condensing out of their stars as they're swept
                Repeater {
                    model: wd.nCh
                    delegate: Text {
                        id: ch
                        required property int index
                        readonly property bool lit: wd.st.fill * wd.nCh >= index + 0.5
                        readonly property real restY: (wd.wh - wd.p.size * 1.25) / 2
                        x: index * wd.cw
                        y: lit ? restY : (wd.stars[index] ? wd.stars[index].y - wd.p.size * 0.6 : restY)
                        text: wd.word.charAt(index)
                        textFormat: Text.PlainText
                        color: wd.bg ? root.coral : root.ink
                        opacity: lit ? (wd.bg ? 0.8 : 1) : 0
                        scale: lit ? 1 : 0.55
                        font.family: root.mono
                        font.pixelSize: wd.p.size
                        font.weight: wd.bg ? Font.Medium : Font.Bold
                        font.italic: wd.bg
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.55)
                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutQuad } }
                        Behavior on scale { NumberAnimation { duration: 190; easing.type: Easing.OutBack } }
                    }
                }

                // a held note twinkles its whole constellation
                SequentialAnimation {
                    id: twinkle
                    running: wd.st.sustain === true && !root.lineExpired
                    loops: Animation.Infinite
                    NumberAnimation { target: wd; property: "scale"; to: 1.045; duration: 420; easing.type: Easing.InOutSine }
                    NumberAnimation { target: wd; property: "scale"; to: 1.0; duration: 420; easing.type: Easing.InOutSine }
                    onStopped: wd.scale = 1
                }
            }
        }

        // the line-complete shooting star, crossing the whole chart
        Item {
            visible: root.streakT >= 0
            x: -80 + (region.width + 160) * Math.max(0, root.streakT)
            y: region.height * (0.55 - 0.30 * Math.max(0, root.streakT))
            rotation: -11
            Rectangle {
                width: 110; height: 1.6; radius: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.inkA(0.0) }
                    GradientStop { position: 1.0; color: root.inkA(0.9) }
                }
            }
            Rectangle { x: 107; y: -1.4; width: 4.4; height: 4.4; radius: 2.2; color: root.ink }
            Text { x: 100; y: -14; text: "✧"; color: root.inkA(0.75); font.pixelSize: 9 }
        }

        // status while a track plays but nothing is charted
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            visible: root.engine.player !== null && root.engine.tokens.length === 0
            text: !root.engine.lyricsLoaded ? "✦ reading the sky…"
                  : !root.engine.lyricsSynced ? "✧ no stars charted for this song"
                  : "✦"
            textFormat: Text.PlainText
            color: root.slateA(1)
            font.family: root.mono
            font.pixelSize: Math.round(root.lyricSize * 0.45)
            font.letterSpacing: 3
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.5)
        }

        // live lyric-offset OSD, flashed on calibration nudges
        Text {
            id: offsetOsd
            function flash() { opacity = 1; osdHide.restart() }
            anchors.horizontalCenter: parent.horizontalCenter
            y: -root.lyricSize * 1.4
            opacity: 0
            text: "✦ offset " + (root.engine.offsetMs > 0 ? "+" : "") + root.engine.offsetMs + " ms"
            color: root.amber
            font.family: root.mono
            font.pixelSize: Math.round(root.lyricSize * 0.5)
            font.letterSpacing: 2
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.55)
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
        }

        // three stars go out one by one — the next verse is almost charted
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -root.lyricSize * 1.1
            spacing: Math.round(root.lyricSize * 0.5)
            visible: root.countdownOn
            Repeater {
                model: 3
                Text {
                    required property int index
                    readonly property bool lit: Math.ceil(root.engine.nextLineInMs / 1067) > index
                    text: "✦"
                    textFormat: Text.PlainText
                    color: root.amberLive
                    opacity: lit ? 0.9 : 0.12
                    scale: lit ? 1 : 0.7
                    font.pixelSize: Math.round(root.lyricSize * 0.5)
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.5)
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutQuad } }
                }
            }
        }
    }

    // during the countdown the chart is dark; the stars above region stand in
    readonly property bool countdownOn:
        engine.player !== null && engine.lyricsSynced && engine.playing
        && engine.nextLineInMs >= 0 && engine.nextLineInMs < 3200
        && (engine.inInterlude || engine.activeIndex < 0)

    // ---- interlude: a sparse meteor shower through the break ----------------
    Repeater {
        model: 3
        Item {
            id: meteor
            required property int index
            readonly property bool on: root.engine.inInterlude && root.engine.playing
            property real t: -1
            visible: on && t >= 0 && t <= 1
            x: root.width * (0.12 + index * 0.27) + root.width * 0.30 * Math.max(0, t) - 60
            y: root.height * (0.09 + index * 0.08) + root.height * 0.07 * Math.max(0, t)
            rotation: -11
            opacity: 0.5 * (1 - Math.max(0, t))
            SequentialAnimation {
                running: meteor.on
                loops: Animation.Infinite
                PauseAnimation { duration: 500 + meteor.index * 1400 }
                NumberAnimation { target: meteor; property: "t"; from: 0; to: 1; duration: 950; easing.type: Easing.InOutQuad }
                PropertyAction { target: meteor; property: "t"; value: -1 }
                PauseAnimation { duration: 2600 }
            }
            Rectangle {
                width: 90; height: 1.4; radius: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.inkA(0.0) }
                    GradientStop { position: 1.0; color: root.inkA(0.8) }
                }
            }
            Rectangle { x: 88; y: -1.2; width: 3.6; height: 3.6; radius: 1.8; color: root.ink }
        }
    }
}
