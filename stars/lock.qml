import QtQuick
import Quickshell

// stars: lock overlay, drawn above the standard lock content (blurred
// wallpaper + the hanging sign clock + password dots — already there).
// As the lock engages the night deepens: a dark vignette settles in, a
// second population of stars fades up in the sky, and while you're away
// the occasional shooting star crosses on a sparse random timer. A thin
// telephone wire draws itself across the lower screen with a small cat
// settled on it, keeping watch over the passcode dots below; somewhere
// near the ledge a pair of amber cat eyes opens, blinks once, and slips
// away. A wrong password flashes the wire coral-red. On unlock one last
// shooting star wipes across as the night lifts.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property color amber: pal.neon
    readonly property color coral: pal.cyan
    readonly property color alert: pal.magenta
    readonly property color slate: pal.dim
    readonly property color ink:   pal.text
    readonly property color catInk: Qt.darker(pal.glass, 1.6)
    readonly property real p: host.progress
    readonly property real ui: pal.uiScale
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }

    // ── the night deepens: edge vignette + a settled dark wash ─────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.01, 0.03, 0.07, 0.30 * root.p)
    }
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: parent.height * 0.34
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.01, 0.02, 0.06, 0.55) }
            GradientStop { position: 1.0; color: Qt.rgba(0.01, 0.02, 0.06, 0.0) }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * 0.4
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.01, 0.02, 0.06, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0.01, 0.02, 0.06, 0.6) }
        }
    }

    // ── extra stars come out ─────────────────────────────────────────────
    Repeater {
        model: 30
        delegate: Rectangle {
            id: star
            required property int index
            readonly property real s1: ((index * 0.61803) % 1)
            readonly property real s2: ((index * 0.38197 + 0.17) % 1)
            readonly property bool bright: index % 6 === 0
            x: root.width * s1
            y: root.height * (0.03 + 0.52 * s2)
            width: (bright ? 2.6 : 1.6) * root.ui
            height: width
            radius: width / 2
            color: bright ? root.ink : root.inkA(0.8)
            // each star fades up on its own slice of the lock engage
            opacity: Math.max(0, Math.min(1, root.p * 1.6 - s2 * 0.6)) * (0.35 + 0.55 * s1)

            // only a handful twinkle, slowly, and only while locked
            SequentialAnimation on scale {
                running: star.bright && root.p > 0.95
                loops: Animation.Infinite
                NumberAnimation { to: 1.5; duration: 2200 + star.s1 * 2400; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 2600 + star.s2 * 2400; easing.type: Easing.InOutSine }
            }
        }
    }

    // ── sparse shooting stars while the desk sleeps ─────────────────────────
    Item {
        id: meteor
        property real t: -1
        property real baseX: 0.2
        property real baseY: 0.15
        property real len: 120
        visible: t >= 0
        x: root.width * baseX + (root.width * 0.3) * Math.max(0, t)
        y: root.height * baseY + (root.height * 0.14) * Math.max(0, t)
        rotation: 25
        opacity: t >= 0 ? Math.sin(Math.PI * Math.min(1, t)) : 0

        Rectangle {
            width: meteor.len * root.ui; height: 1.6 * root.ui; radius: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.inkA(0.0) }
                GradientStop { position: 1.0; color: root.inkA(0.9) }
            }
        }
        Rectangle {
            x: meteor.len * root.ui - 2; y: -1.2 * root.ui
            width: 4 * root.ui; height: 4 * root.ui; radius: 2 * root.ui
            color: root.ink
        }

        NumberAnimation {
            id: meteorAnim
            target: meteor; property: "t"
            from: 0; to: 1; duration: 1100; easing.type: Easing.InOutQuad
            onStopped: meteor.t = -1
        }
    }
    Timer {
        id: meteorTimer
        running: root.p > 0.95 && !root.host.unlocking
        repeat: true
        interval: 9000 + Math.floor(Math.random() * 11000)
        onTriggered: {
            meteor.baseX = 0.08 + Math.random() * 0.55
            meteor.baseY = 0.05 + Math.random() * 0.30
            meteor.len = 90 + Math.random() * 70
            meteorAnim.restart()
            interval = 9000 + Math.floor(Math.random() * 11000)
        }
    }

    // ── the unlock wipe: one big shooting star as the night lifts ──────────
    Item {
        id: wipe
        property real t: -1
        visible: t >= 0
        x: -root.width * 0.2 + root.width * 1.3 * Math.max(0, t)
        y: root.height * (0.42 - 0.18 * Math.max(0, t))
        rotation: -12
        Rectangle {
            width: 260 * root.ui; height: 2.2 * root.ui; radius: 1.5
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.inkA(0.0) }
                GradientStop { position: 1.0; color: root.inkA(0.95) }
            }
        }
        Rectangle {
            x: 260 * root.ui - 3; y: -1.8 * root.ui
            width: 6 * root.ui; height: 6 * root.ui; radius: 3 * root.ui
            color: root.ink
        }
        NumberAnimation {
            id: wipeAnim
            target: wipe; property: "t"
            from: 0; to: 1; duration: 700; easing.type: Easing.OutQuad
            onStopped: wipe.t = -1
        }
    }
    Connections {
        target: root.host
        function onUnlockingChanged() { if (root.host.unlocking) wipeAnim.restart() }
    }

    // ── the low wire: a catenary framing the passcode area ─────────────────
    Canvas {
        id: lowWire
        anchors.fill: parent
        readonly property real sweep: root.p
        readonly property color strokeCol: root.host.failed ? root.alert : root.slate
        onSweepChanged: requestPaint()
        onStrokeColChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (width <= 0 || sweep <= 0.01) return
            const x0 = width * 0.16, x1 = width * 0.84
            const y0 = height * 0.755
            const yc = height * 0.805       // sag through the middle
            const n = 60
            const upTo = Math.max(2, Math.round(n * Math.min(1, sweep)))
            ctx.strokeStyle = String(Qt.rgba(strokeCol.r, strokeCol.g, strokeCol.b, 0.75 * sweep))
            ctx.lineWidth = 1.4 * root.ui
            ctx.beginPath()
            for (let i = 0; i <= upTo; i++) {
                const t = i / n
                const u = 1 - t
                const x = x0 + (x1 - x0) * t
                const y = u * u * y0 + 2 * u * t * yc + t * t * y0
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
            ctx.stroke()
            // the two little end knobs
            ctx.fillStyle = ctx.strokeStyle
            ctx.beginPath(); ctx.arc(x0, y0, 2.4 * root.ui, 0, Math.PI * 2); ctx.fill()
            if (sweep >= 1) { ctx.beginPath(); ctx.arc(x1, y0, 2.4 * root.ui, 0, Math.PI * 2); ctx.fill() }
        }
    }

    // the cat settled on the low wire, tail hanging — appears with the wire
    Item {
        id: wireCat
        readonly property real fx: 0.335
        readonly property real t: (fx - 0.16) / 0.68
        readonly property real wy: {
            const u = 1 - t
            return root.height * (u * u * 0.755 + 2 * u * t * 0.805 + t * t * 0.755)
        }
        x: root.width * fx - width / 2
        y: wy - height + 2 * root.ui
        width: 26 * root.ui
        height: 22 * root.ui
        opacity: root.p >= 0.98 ? 0.95 : 0
        Behavior on opacity { NumberAnimation { duration: 500 } }

        Canvas {
            id: wireCatBody
            anchors.fill: parent
            Connections {
                target: root.pal
                function onGlassChanged() { wireCatBody.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const s = width / 16
                ctx.fillStyle = String(root.catInk)
                // seated body
                ctx.beginPath()
                ctx.moveTo(3 * s, 13.6 * s)
                ctx.quadraticCurveTo(2 * s, 6 * s, 6 * s, 5 * s)
                ctx.quadraticCurveTo(10 * s, 4.4 * s, 11.5 * s, 8 * s)
                ctx.quadraticCurveTo(13 * s, 11 * s, 13 * s, 13.6 * s)
                ctx.closePath()
                ctx.fill()
                // head
                ctx.beginPath()
                ctx.arc(6.5 * s, 4.6 * s, 3.1 * s, 0, Math.PI * 2)
                ctx.fill()
                // ears
                ctx.beginPath()
                ctx.moveTo(4.1 * s, 3.2 * s); ctx.lineTo(4.4 * s, 0.6 * s); ctx.lineTo(6.1 * s, 2 * s); ctx.closePath(); ctx.fill()
                ctx.beginPath()
                ctx.moveTo(7.1 * s, 2 * s); ctx.lineTo(8.8 * s, 0.8 * s); ctx.lineTo(8.9 * s, 3.4 * s); ctx.closePath(); ctx.fill()
                // tail hanging off the wire
                ctx.strokeStyle = String(root.catInk)
                ctx.lineWidth = 1.6 * s
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.moveTo(12.6 * s, 13 * s)
                ctx.quadraticCurveTo(15 * s, 14.5 * s, 14.4 * s, 18 * s)
                ctx.stroke()
            }
        }
    }

    // ── the cat eyes near the ledge: open, blink once, gone ────────────────
    Item {
        id: eyes
        x: root.width * 0.472
        y: root.height * 0.715
        width: 26 * root.ui
        height: 8 * root.ui
        opacity: 0
        readonly property color eyeCol: root.host.failed ? root.alert : root.amber

        Repeater {
            model: 2
            delegate: Rectangle {
                required property int index
                x: index * 16 * root.ui
                width: 9 * root.ui
                height: eyes.height
                radius: height / 2
                color: eyes.eyeCol
                // slit pupil
                Rectangle {
                    anchors.centerIn: parent
                    width: 1.6 * root.ui
                    height: parent.height * 0.8
                    radius: width / 2
                    color: root.catInk
                }
            }
        }

        SequentialAnimation {
            id: eyesShow
            NumberAnimation { target: eyes; property: "opacity"; to: 0.9; duration: 700 }
            PauseAnimation { duration: 1100 }
            // the blink
            NumberAnimation { target: eyes; property: "scale"; to: 0.08; duration: 90; easing.type: Easing.InQuad }
            NumberAnimation { target: eyes; property: "scale"; to: 1.0; duration: 130; easing.type: Easing.OutQuad }
            PauseAnimation { duration: 1400 }
            NumberAnimation { target: eyes; property: "opacity"; to: 0; duration: 900 }
        }
        Timer {
            // first appearance shortly after the lock settles, then rarely.
            // the lock instance persists across lock cycles, so re-arm the
            // short first-look interval whenever the lock re-engages.
            running: root.p > 0.95 && !root.host.unlocking
            repeat: true
            triggeredOnStart: false
            interval: 3000
            onRunningChanged: if (running) interval = 3000
            onTriggered: {
                if (eyes.opacity === 0) eyesShow.restart()
                interval = 42000 + Math.floor(Math.random() * 30000)
            }
        }
    }
}
