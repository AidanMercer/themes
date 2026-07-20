import QtQuick
import Quickshell

// sakura: bare lock (bareLock — LockStage stands its chrome down). The video
// keeps playing full-bleed and sharp; a dusk-plum card blooms into the center
// carrying the time and the passcode blossom: one petal opens per keystroke,
// five make the flower, extra characters gather as stamens. A wrong password
// scatters every petal (law 2 — leave by letting go) and the bud starts over.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color cream: pal.text
    readonly property color pink:  pal.neon
    readonly property color sky:   pal.cyan
    readonly property color rose:  pal.magenta
    readonly property color plum:  pal.glass
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    readonly property string sans: "Noto Sans"
    function creamA(a) { return Qt.rgba(cream.r, cream.g, cream.b, a) }
    function pinkA(a)  { return Qt.rgba(pink.r, pink.g, pink.b, a) }
    function skyA(a)   { return Qt.rgba(sky.r, sky.g, sky.b, a) }
    function plumA(a)  { return Qt.rgba(plum.r, plum.g, plum.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // soft vignette so the card and petals sit in a hush, video still visible
    Rectangle {
        anchors.fill: parent
        opacity: root.p * 0.5
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.plumA(0.55) }
            GradientStop { position: 0.35; color: root.plumA(0.10) }
            GradientStop { position: 0.65; color: root.plumA(0.10) }
            GradientStop { position: 1.0; color: root.plumA(0.65) }
        }
    }

    // a few petals crossing the hush while the lock is up
    Repeater {
        model: 6
        Canvas {
            id: lp
            required property int index
            readonly property real seed: (index * 0.618034) % 1
            readonly property real r: (6 + seed * 5) * root.ui
            width: r * 2.2; height: r * 2.2
            x: root.width * ((seed * 5.39) % 1)
            opacity: root.p * (0.35 + 0.4 * seed)
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.translate(width / 2, height / 2)
                ctx.rotate(seed * 6.28)
                ctx.beginPath()
                ctx.moveTo(0, r * 0.5)
                ctx.bezierCurveTo(-r * 0.8, 0, -r * 0.6, -r * 0.8, -r * 0.14, -r * 0.9)
                ctx.lineTo(0, -r * 0.76)
                ctx.lineTo(r * 0.14, -r * 0.9)
                ctx.bezierCurveTo(r * 0.6, -r * 0.8, r * 0.8, 0, 0, r * 0.5)
                ctx.closePath()
                ctx.fillStyle = String(root.pinkA(0.8))
                ctx.fill()
            }
            Component.onCompleted: requestPaint()
            NumberAnimation on y {
                running: root.p > 0.2
                loops: Animation.Infinite
                from: -40 - lp.seed * 200
                to: root.height + 40
                duration: 26000 + lp.seed * 20000
            }
        }
    }

    // ── the card blooms into the center ─────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.round(500 * root.ui)
        height: Math.round(430 * root.ui)
        radius: 22
        color: root.plumA(0.84)
        border.width: 1
        border.color: root.pinkA(0.32)
        opacity: root.p
        scale: 0.94 + 0.06 * root.p

        // canopy light along the top
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 70
            radius: 21
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.pinkA(0.10) }
                GradientStop { position: 1.0; color: root.pinkA(0.0) }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(44 * root.ui)
            spacing: Math.round(8 * root.ui)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "s a k u r a"
                color: root.pinkA(0.8)
                font.family: root.sans
                font.pixelSize: Math.round(12 * root.ui)
                font.letterSpacing: 7
            }
            Text {
                id: timeText
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.creamA(0.97)
                font.family: root.sans
                font.weight: Font.Light
                font.pixelSize: Math.round(88 * root.ui)
                font.letterSpacing: 4
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Text {
                    text: Qt.formatDateTime(clock.date, "dddd").toLowerCase()
                    color: root.skyA(0.9)
                    font.family: root.sans
                    font.pixelSize: Math.round(13 * root.ui)
                    font.letterSpacing: 3
                }
                Text {
                    text: "·"
                    color: root.pinkA(0.8)
                    font.family: root.sans
                    font.pixelSize: Math.round(13 * root.ui)
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "MMMM d").toLowerCase()
                    color: root.creamA(0.7)
                    font.family: root.sans
                    font.pixelSize: Math.round(13 * root.ui)
                    font.letterSpacing: 3
                }
            }
        }

        // ── the passcode blossom ────────────────────────────────────────────
        Item {
            id: passArea
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(card.height * 0.56)
            width: Math.round(120 * root.ui)
            height: width

            Canvas {
                id: passBlossom
                anchors.fill: parent
                // one petal per keystroke; extra characters gather as stamens
                readonly property int chars: root.host.pwLength
                property real scatterT: 0        // 1 = petals fully flung
                property real busyPulse: root.host.busy ? 0.92 : 1
                onCharsChanged: requestPaint()
                onScatterTChanged: requestPaint()
                onBusyPulseChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, r = w * 0.34
                    ctx.translate(w / 2, w / 2)
                    ctx.scale(busyPulse, busyPulse)
                    const openPetals = Math.min(5, chars)
                    const failing = scatterT > 0
                    const col = failing ? root.rose : root.pink

                    if (chars === 0 && !failing) {
                        // resting bud
                        ctx.beginPath()
                        ctx.arc(0, 0, r * 0.22, 0, 2 * Math.PI)
                        ctx.fillStyle = String(root.pinkA(0.65))
                        ctx.fill()
                        return
                    }
                    for (let i = 0; i < 5; i++) {
                        if (i >= openPetals && !failing) continue
                        ctx.save()
                        ctx.rotate(i * Math.PI * 2 / 5)
                        // on failure every petal flings outward and fades
                        if (failing) {
                            ctx.translate(0, -r * 1.5 * scatterT)
                            ctx.rotate(scatterT * (i % 2 === 0 ? 0.9 : -0.9))
                            ctx.globalAlpha = Math.max(0, 1 - scatterT * 1.15)
                        }
                        const pr = r, pw = pr * 0.55
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.bezierCurveTo(-pw, -pr * 0.35, -pw * 0.9, -pr * 0.85, -pr * 0.16, -pr * 0.97)
                        ctx.lineTo(0, -pr * 0.85)
                        ctx.lineTo(pr * 0.16, -pr * 0.97)
                        ctx.bezierCurveTo(pw * 0.9, -pr * 0.85, pw, -pr * 0.35, 0, 0)
                        ctx.closePath()
                        ctx.fillStyle = String(Qt.rgba(col.r, col.g, col.b, 0.88))
                        ctx.fill()
                        ctx.restore()
                    }
                    ctx.globalAlpha = 1
                    // stamens: characters past the fifth
                    const stamens = Math.min(9, Math.max(0, chars - 5))
                    for (let s = 0; s < stamens; s++) {
                        const a = s * Math.PI * 2 / 9 - Math.PI / 2
                        const sr = r * 0.34
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.lineTo(Math.cos(a) * sr, Math.sin(a) * sr)
                        ctx.strokeStyle = String(root.creamA(0.85))
                        ctx.lineWidth = 1.2
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.arc(Math.cos(a) * sr, Math.sin(a) * sr, 1.8, 0, 2 * Math.PI)
                        ctx.fillStyle = String(root.creamA(0.9))
                        ctx.fill()
                    }
                    // heart of the flower
                    ctx.beginPath()
                    ctx.arc(0, 0, Math.max(2, r * 0.14), 0, 2 * Math.PI)
                    ctx.fillStyle = String(root.creamA(0.92))
                    ctx.fill()
                }
                Behavior on busyPulse { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }
            }

            // wrong password: the petals scatter, then the bud returns
            Connections {
                target: root.host
                function onFailedChanged() { if (root.host.failed) scatter.restart() }
            }
            SequentialAnimation {
                id: scatter
                NumberAnimation { target: passBlossom; property: "scatterT"; from: 0; to: 1; duration: 620; easing.type: Easing.OutSine }
                PauseAnimation { duration: 180 }
                NumberAnimation { target: passBlossom; property: "scatterT"; to: 0; duration: 0 }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(30 * root.ui)
            text: root.host.failed ? "the petals scattered — try again"
                : root.host.pwLength === 0 ? "type, and the blossom opens"
                : "petals gathering · enter when ready"
            color: root.host.failed ? root.rose : root.creamA(0.6)
            font.family: root.sans
            font.italic: true
            font.pixelSize: Math.round(13 * root.ui)
            font.letterSpacing: 2
        }
    }
}
