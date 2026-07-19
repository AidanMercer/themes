import QtQuick
import Quickshell

// bog: the fishing-float clock. The time floats on the open water lower-left,
// written in storybook serif with a wavering shader reflection beneath its
// waterline — the pond's house rule: what floats casts a ghost. A two-tone
// cork bobber sits exactly where the wallpaper's painted fishing line touches
// the pond. When the minute turns the bobber DIPS (a bite), ripple rings
// spread, and the old minute sinks below the waterline while the new one
// surfaces through it. The date is spoken the way a folktale would say it:
// "friday, the eighteenth of july". Everything bobs on its own slow water
// line; everything holds still while occluded. Click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while locked or a fullscreen window covers the monitor
    property bool occluded: false

    readonly property color sun: pal.neon        // sunlit-grass amber
    readonly property color rust: pal.magenta    // the bobber's bait-red band
    readonly property color straw: pal.text
    readonly property color murk: pal.glass
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"
    function sunA(a)   { return Qt.rgba(sun.r, sun.g, sun.b, a) }
    function strawA(a) { return Qt.rgba(straw.r, straw.g, straw.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // the folktale date: "friday, the eighteenth of july"
    function spokenDate(d) {
        const ord = ["first","second","third","fourth","fifth","sixth","seventh",
            "eighth","ninth","tenth","eleventh","twelfth","thirteenth",
            "fourteenth","fifteenth","sixteenth","seventeenth","eighteenth",
            "nineteenth","twentieth","twenty-first","twenty-second",
            "twenty-third","twenty-fourth","twenty-fifth","twenty-sixth",
            "twenty-seventh","twenty-eighth","twenty-ninth","thirtieth",
            "thirty-first"]
        const day = Qt.formatDateTime(d, "dddd").toLowerCase()
        const mon = Qt.formatDateTime(d, "MMMM").toLowerCase()
        return day + ", the " + ord[d.getDate() - 1] + " of " + mon
    }

    // ── boot: the whole ensemble surfaces ──────────────────────────────────
    property real bootT: 0
    SequentialAnimation {
        running: true
        NumberAnimation { target: root; property: "bootT"; from: 0; to: 1; duration: 1500; easing.type: Easing.OutSine }
        ScriptAction { script: rings.splash() }
    }

    // ── the ripple: three staggered expanding ellipse rings ────────────────
    component Ripple: Canvas {
        id: rip
        property real t: -1
        property color tone: root.sun
        property real maxR: 60 * root.ui
        visible: t >= 0
        width: maxR * 2.3
        height: maxR
        onTChanged: requestPaint()
        function splash() { ripAnim.restart() }
        NumberAnimation {
            id: ripAnim
            target: rip; property: "t"
            from: 0; to: 1; duration: 1900; easing.type: Easing.OutSine
            onStopped: rip.t = -1
        }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (t < 0) return
            const cx = width / 2, cy = height / 2
            for (let k = 0; k < 3; k++) {
                const tt = (t - k * 0.17) / (1 - k * 0.17)
                if (tt <= 0 || tt >= 1) continue
                const r = maxR * (0.12 + 0.88 * tt)
                ctx.save()
                ctx.translate(cx, cy)
                ctx.scale(1, 0.32)
                ctx.beginPath()
                ctx.arc(0, 0, r, 0, 2 * Math.PI)
                ctx.restore()
                ctx.strokeStyle = String(Qt.rgba(tone.r, tone.g, tone.b, 0.45 * (1 - tt)))
                ctx.lineWidth = Math.max(0.8, 2.4 * (1 - tt))
                ctx.stroke()
            }
        }
    }

    // ── the time, afloat lower-left ────────────────────────────────────────
    Item {
        id: raft
        x: Math.round(root.width * 0.115)
        y: Math.round(root.height * 0.638) + Math.round(22 * (1 - root.bootT))
        opacity: root.bootT
        // its own slow water line
        property real bobY: 0
        transform: Translate { y: raft.bobY }
        SequentialAnimation on bobY {
            running: !root.occluded
            loops: Animation.Infinite
            NumberAnimation { to: 3; duration: 4400; easing.type: Easing.InOutSine }
            NumberAnimation { to: -3; duration: 4400; easing.type: Easing.InOutSine }
        }

        // the folktale date, floating just above the time
        Text {
            anchors.bottom: timeBlock.top
            anchors.bottomMargin: Math.round(6 * root.ui)
            x: Math.round(6 * root.ui)
            text: root.spokenDate(clock.date)
            color: root.strawA(0.62)
            font.family: root.serif
            font.italic: true
            font.pixelSize: Math.round(21 * root.ui)
            font.letterSpacing: 2
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.45)
        }

        // the time itself — old minute sinks, new one surfaces
        Item {
            id: timeBlock
            width: cur.implicitWidth
            height: Math.round(120 * root.ui)

            // set once on mount, then only by the flip handler — a live
            // binding here would race the handler and skip the surfacing
            property string shown: ""
            property string sinking: ""
            Component.onCompleted: shown = root.hhmm

            Connections {
                target: root
                function onHhmmChanged() {
                    if (timeBlock.shown === root.hhmm) return
                    timeBlock.sinking = timeBlock.shown
                    timeBlock.shown = root.hhmm
                    flip.restart()
                    if (!root.occluded && root.bootT === 1) {
                        dip.restart()
                        bobRings.splash()
                        rings.splash()
                    }
                }
            }

            Text {
                id: cur
                text: timeBlock.shown
                color: root.strawA(0.94)
                font.family: root.serif
                font.weight: Font.Light
                font.pixelSize: Math.round(118 * root.ui)
                font.letterSpacing: 4
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.5)
            }
            Text {
                id: old
                text: timeBlock.sinking
                color: root.strawA(0.94)
                font: cur.font
                opacity: 0
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.5)
            }
            ParallelAnimation {
                id: flip
                // the new minute surfaces from under the waterline…
                NumberAnimation { target: cur; property: "y"; from: 26; to: 0; duration: 1300; easing.type: Easing.OutSine }
                NumberAnimation { target: cur; property: "opacity"; from: 0; to: 1; duration: 1100; easing.type: Easing.OutSine }
                // …while the old one settles beneath it
                NumberAnimation { target: old; property: "y"; from: 0; to: 34; duration: 1200; easing.type: Easing.InOutSine }
                NumberAnimation { target: old; property: "opacity"; from: 0.8; to: 0; duration: 1100; easing.type: Easing.InOutSine }
            }
        }

        // the waterline: a few sun-glints along the surface under the digits
        Row {
            id: glints
            anchors.top: timeBlock.bottom
            anchors.topMargin: Math.round(2 * root.ui)
            x: -Math.round(14 * root.ui)
            spacing: Math.round(17 * root.ui)
            Repeater {
                model: 7
                Rectangle {
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    width: (index % 3 === 0 ? 26 : 13) * root.ui
                    height: Math.max(1, Math.round(1.4 * root.ui))
                    radius: height / 2
                    color: root.sunA(index % 2 === 0 ? 0.30 : 0.16)
                }
            }
        }

        // the reflection: the time mirrored through the pond's shader
        ShaderEffectSource {
            id: mirrorSrc
            sourceItem: timeBlock
            hideSource: false
            live: true
            visible: false
        }
        ShaderEffect {
            anchors.top: glints.bottom
            anchors.topMargin: Math.round(1 * root.ui)
            x: 0
            width: timeBlock.width
            height: Math.round(timeBlock.height * 0.62)
            fragmentShader: Qt.resolvedUrl("reflect.frag.qsb")
            property var source: mirrorSrc
            property real time: 0
            property real amp: 0.014
            opacity: 0.5
            NumberAnimation on time {
                from: 0; to: 600; duration: 600000
                loops: Animation.Infinite
                running: !root.occluded && root.visible
            }
        }

        // a minute-turn ripple under the digits
        Ripple {
            id: rings
            anchors.horizontalCenter: timeBlock.horizontalCenter
            anchors.verticalCenter: glints.verticalCenter
            maxR: 90 * root.ui
            tone: root.sun
        }
    }

    // ── the bobber, where the painted line meets the water ─────────────────
    Item {
        id: bobber
        x: Math.round(root.width * 0.3755)
        y: Math.round(root.height * 0.6115)
        opacity: root.bootT
        property real bobY: 0
        property real dipY: 0
        transform: Translate { y: bobber.bobY + bobber.dipY }
        SequentialAnimation on bobY {
            running: !root.occluded
            loops: Animation.Infinite
            NumberAnimation { to: 2.2; duration: 3400; easing.type: Easing.InOutSine }
            NumberAnimation { to: -2.2; duration: 3400; easing.type: Easing.InOutSine }
        }
        // the bite: a quick pull under, a slow buoyant recovery
        SequentialAnimation {
            id: dip
            NumberAnimation { target: bobber; property: "dipY"; to: 8 * root.ui; duration: 380; easing.type: Easing.InOutSine }
            NumberAnimation { target: bobber; property: "dipY"; to: -2 * root.ui; duration: 700; easing.type: Easing.OutSine }
            NumberAnimation { target: bobber; property: "dipY"; to: 0; duration: 900; easing.type: Easing.InOutSine }
        }

        // the cork: rust cap, straw belly, sitting half-proud of the water
        Canvas {
            id: cork
            width: Math.round(15 * root.ui)
            height: Math.round(20 * root.ui)
            x: -width / 2
            y: -height * 0.62
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height
                // stem tip
                ctx.fillStyle = String(root.strawA(0.85))
                ctx.fillRect(w * 0.44, 0, Math.max(1.5, w * 0.12), h * 0.2)
                // rust cap (upper half of the egg)
                ctx.beginPath()
                ctx.moveTo(w * 0.5, h * 0.14)
                ctx.bezierCurveTo(w * 0.96, h * 0.14, w * 0.98, h * 0.56, w * 0.5, h * 0.56)
                ctx.bezierCurveTo(w * 0.02, h * 0.56, w * 0.04, h * 0.14, w * 0.5, h * 0.14)
                ctx.fillStyle = String(root.rust)
                ctx.fill()
                // straw belly (below the band, mostly underwater)
                ctx.beginPath()
                ctx.moveTo(w * 0.5, h * 0.56)
                ctx.bezierCurveTo(w * 0.94, h * 0.56, w * 0.86, h * 0.96, w * 0.5, h * 0.96)
                ctx.bezierCurveTo(w * 0.14, h * 0.96, w * 0.06, h * 0.56, w * 0.5, h * 0.56)
                ctx.fillStyle = String(root.sunA(0.9))
                ctx.fill()
                // the waterline cutting across the belly
                ctx.fillStyle = String(Qt.rgba(root.murk.r, root.murk.g, root.murk.b, 0.55))
                ctx.fillRect(0, h * 0.62, w, h * 0.38)
                // one small noon highlight on the cap
                ctx.beginPath()
                ctx.arc(w * 0.36, h * 0.3, w * 0.09, 0, 2 * Math.PI)
                ctx.fillStyle = String(root.strawA(0.6))
                ctx.fill()
            }
            Connections {
                target: root.pal
                function onMagentaChanged() { cork.requestPaint() }
                function onNeonChanged() { cork.requestPaint() }
            }
        }
        // its dim reflection blob
        Rectangle {
            x: -Math.round(5 * root.ui)
            y: Math.round(4 * root.ui)
            width: Math.round(10 * root.ui)
            height: Math.round(3 * root.ui)
            radius: height / 2
            color: root.rust
            opacity: 0.28
        }
        Ripple {
            id: bobRings
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            maxR: 55 * root.ui
            tone: root.straw
        }
    }
}
