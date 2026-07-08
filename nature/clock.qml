import QtQuick
import Quickshell

// nature — "golden hour" desktop clock, upper right where all three meadows
// leave sky/bokeh room. Soft serif time floating on a warm dark-pine halo
// (legibility over the bright sun flare), wrapped in a sun-glow that slowly
// breathes. On every minute change 2–3 daisy petals detach from the time and
// drift off on the breeze. Also mounted on the lock screen over the blur.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color gold:  pal.neon
    readonly property color leaf:  pal.cyan
    readonly property color rose:  pal.magenta
    readonly property color moss:  pal.dim
    readonly property color cream: pal.text
    readonly property color pine:  pal.glass
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"
    readonly property string sans:  "Noto Sans"
    function creamA(a) { return Qt.rgba(cream.r, cream.g, cream.b, a) }
    function goldA(a)  { return Qt.rgba(gold.r, gold.g, gold.b, a) }
    function pineA(a)  { return Qt.rgba(pine.r, pine.g, pine.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // loader pushes true while the session is locked or a fullscreen window
    // covers this monitor — freeze the halo's breath when nothing's watching
    property bool occluded: false

    // boot-in: the clock blooms up out of nothing
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1200; easing.type: Easing.OutCubic }

    // minute flourish: petals detach and drift when the minute flips
    property int lastMinute: -1
    Connections {
        target: clock
        function onDateChanged() {
            const m = clock.date.getMinutes()
            if (root.lastMinute >= 0 && m !== root.lastMinute) petalBurst.restart()
            root.lastMinute = m
        }
    }

    Item {
        id: block
        width: 460 * root.ui
        height: 300 * root.ui
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Math.round(root.width * 0.035)
        anchors.topMargin: Math.round(root.height * 0.085) + Math.round(18 * (1 - root.bootT))
        opacity: root.bootT

        // adaptive dark-pine halo — a soft radial shade so the cream serif
        // reads over the sun flare (wp1), gold bokeh (wp2) and clouds (wp3)
        Canvas {
            id: shade
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const g = ctx.createRadialGradient(width * 0.55, height * 0.45, 10,
                                                   width * 0.55, height * 0.45, width * 0.58)
                g.addColorStop(0, root.pineA(0.52))
                g.addColorStop(0.65, root.pineA(0.30))
                g.addColorStop(1, root.pineA(0))
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, height)
            }
            Connections {
                target: root.pal
                function onGlassChanged() { shade.requestPaint() }
            }
        }

        // the sun-glow halo, breathing very slowly behind the time
        Canvas {
            id: halo
            width: 340 * root.ui
            height: 340 * root.ui
            anchors.centerIn: shade
            anchors.verticalCenterOffset: -10 * root.ui
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const g = ctx.createRadialGradient(width / 2, height / 2, 4,
                                                   width / 2, height / 2, width / 2)
                g.addColorStop(0, root.goldA(0.30))
                g.addColorStop(0.45, root.goldA(0.12))
                g.addColorStop(1, root.goldA(0))
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, height)
            }
            Connections {
                target: root.pal
                function onNeonChanged() { halo.requestPaint() }
            }
            // one slow breath — transform only, no repaints
            SequentialAnimation on scale {
                running: !root.occluded
                loops: Animation.Infinite
                NumberAnimation { to: 1.12; duration: 4200; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.94; duration: 4200; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on opacity {
                running: !root.occluded
                loops: Animation.Infinite
                NumberAnimation { to: 0.7; duration: 4200; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 4200; easing.type: Easing.InOutSine }
            }
        }

        Column {
            id: col
            anchors.centerIn: parent
            spacing: Math.round(8 * root.ui)

            // header: a tiny blossom + the theme's name, letterspaced
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(9 * root.ui)
                Canvas {
                    id: headBud
                    width: 14 * root.ui; height: 14 * root.ui
                    anchors.verticalCenter: parent.verticalCenter
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const c = width / 2, pr = width * 0.34
                        ctx.fillStyle = root.goldA(0.9)
                        for (let i = 0; i < 5; i++) {
                            const a = -Math.PI / 2 + i * Math.PI * 2 / 5
                            ctx.beginPath()
                            ctx.ellipse(c + Math.cos(a) * pr - pr * 0.55, c + Math.sin(a) * pr - pr * 0.55,
                                        pr * 1.1, pr * 1.1)
                            ctx.fill()
                        }
                        ctx.beginPath()
                        ctx.arc(c, c, width * 0.16, 0, Math.PI * 2)
                        ctx.fillStyle = Qt.rgba(root.rose.r, root.rose.g, root.rose.b, 1)
                        ctx.fill()
                    }
                    Connections {
                        target: root.pal
                        function onNeonChanged() { headBud.requestPaint() }
                        function onMagentaChanged() { headBud.requestPaint() }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "golden hour"
                    color: root.goldA(1.0)
                    font.family: root.serif
                    font.italic: true
                    font.weight: Font.Medium
                    font.pixelSize: Math.round(15 * root.ui)
                    font.letterSpacing: 5
                    style: Text.Raised
                    styleColor: Qt.rgba(0.08, 0.13, 0.09, 0.75)
                }
            }

            // the time — soft light serif, cream with a whisper of gold
            Text {
                id: timeText
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.cream
                font.family: root.serif
                font.pixelSize: Math.round(118 * root.ui)
                font.weight: Font.Medium
                font.letterSpacing: 3
            }

            // a curved grass-blade divider instead of a straight rule
            Canvas {
                id: divider
                anchors.horizontalCenter: parent.horizontalCenter
                width: timeText.width * 0.92
                height: 12 * root.ui
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    ctx.strokeStyle = root.goldA(0.55)
                    ctx.lineWidth = 1.4 * root.ui
                    ctx.beginPath()
                    ctx.moveTo(0, h * 0.7)
                    ctx.bezierCurveTo(w * 0.3, h * 0.15, w * 0.7, h * 1.05, w, h * 0.45)
                    ctx.stroke()
                    // two tiny leaves on the stem
                    ctx.fillStyle = Qt.rgba(root.leaf.r, root.leaf.g, root.leaf.b, 0.85)
                    ctx.beginPath()
                    ctx.ellipse(w * 0.3 - 4 * root.ui, h * 0.32 - 2.4 * root.ui, 8 * root.ui, 4.8 * root.ui)
                    ctx.fill()
                    ctx.beginPath()
                    ctx.ellipse(w * 0.7 - 4 * root.ui, h * 0.66 - 2.4 * root.ui, 8 * root.ui, 4.8 * root.ui)
                    ctx.fill()
                }
                Connections {
                    target: root.pal
                    function onNeonChanged() { divider.requestPaint() }
                    function onCyanChanged() { divider.requestPaint() }
                }
            }

            // date line
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(10 * root.ui)
                Text {
                    text: Qt.formatDateTime(clock.date, "dddd")
                    color: root.creamA(0.72)
                    font.family: root.serif
                    font.italic: true
                    font.weight: Font.Medium
                    font.pixelSize: Math.round(15 * root.ui)
                    font.letterSpacing: 3
                }
                Rectangle {
                    width: 4 * root.ui; height: 4 * root.ui; radius: 2 * root.ui
                    color: root.leaf
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "MMMM d")
                    color: root.creamA(0.72)
                    font.family: root.serif
                    font.italic: true
                    font.weight: Font.Medium
                    font.pixelSize: Math.round(15 * root.ui)
                    font.letterSpacing: 3
                }
            }
        }

        // ── the minute flourish: petals detach from the time and drift off ──
        Repeater {
            model: 3
            Canvas {
                id: petal
                required property int index
                readonly property real seed: (index * 0.618 + 0.21) % 1
                width: 16 * root.ui
                height: 10 * root.ui
                opacity: 0
                x: col.x + timeText.x + timeText.width * (0.25 + seed * 0.55)
                y: col.y + timeText.y + timeText.height * 0.3
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    // one soft petal — a leaning teardrop
                    ctx.beginPath()
                    ctx.moveTo(0, height * 0.6)
                    ctx.quadraticCurveTo(width * 0.35, -height * 0.25, width, height * 0.35)
                    ctx.quadraticCurveTo(width * 0.45, height * 1.1, 0, height * 0.6)
                    ctx.fillStyle = petal.index === 1
                        ? Qt.rgba(root.rose.r, root.rose.g, root.rose.b, 0.9)
                        : root.creamA(0.92)
                    ctx.fill()
                }
                Connections {
                    target: root.pal
                    function onTextChanged() { petal.requestPaint() }
                    function onMagentaChanged() { petal.requestPaint() }
                }

                ParallelAnimation {
                    id: drift
                    running: false
                    NumberAnimation {
                        target: petal; property: "x"
                        from: col.x + timeText.x + timeText.width * (0.25 + petal.seed * 0.55)
                        to: col.x + timeText.x + timeText.width * (0.55 + petal.seed * 0.55) + 90 * root.ui
                        duration: 2600 + petal.index * 380; easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: petal; property: "y"
                        from: col.y + timeText.y + timeText.height * (0.25 + petal.seed * 0.3)
                        to: col.y + timeText.y + timeText.height * 0.9 + (60 + petal.seed * 70) * root.ui
                        duration: 2600 + petal.index * 380; easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: petal; property: "rotation"
                        from: -20 + petal.seed * 40; to: 160 + petal.seed * 180
                        duration: 2600 + petal.index * 380
                    }
                    SequentialAnimation {
                        NumberAnimation { target: petal; property: "opacity"; from: 0; to: 0.95; duration: 240 }
                        PauseAnimation { duration: 1500 + petal.index * 300 }
                        NumberAnimation { target: petal; property: "opacity"; to: 0; duration: 860 + petal.index * 80 }
                    }
                }
                Connections {
                    target: petalBurst
                    function onRunningChanged() { if (petalBurst.running) drift.restart() }
                }
            }
        }
        // a tiny driver so all petals share one trigger
        SequentialAnimation { id: petalBurst; PauseAnimation { duration: 10 } }
    }
}
