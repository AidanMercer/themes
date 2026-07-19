import QtQuick
import Quickshell

// downpour: the hour, written on the fog of the left windowpane. A breath
// haze blooms on the glass, then the time is finger-written into it — each
// digit wipes in behind a pale fingertip smear, light serif, no pop. When
// the minute turns the stale digits re-mist (the glass fogs back over them)
// and the new ones are written again; the turn also spends one droplet: a
// bead at the end of the meniscus line breaks and runs. The colon is two
// beads sitting on the glass, breathing slower than she is. Click-through
// scenery; everything stops while occluded.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while locked or a fullscreen window covers the monitor
    property bool occluded: false

    readonly property color paneLight: pal.neon     // wet-glass cyan
    readonly property color ink: pal.text
    readonly property string serif: "Noto Serif"
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function paneA(a)  { return Qt.rgba(paneLight.r, paneLight.g, paneLight.b, a) }

    // deterministic hash — the same condensation on every mount
    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // ── a finger-written glyph: wipes in behind a fingertip smear ───────────
    component WrittenGlyph: Item {
        id: wg
        property string target: " "
        property string ch: " "
        property real reveal: 1
        property real px: 84
        property color face: root.inkA(0.92)
        width: meas.implicitWidth
        height: meas.implicitHeight

        Text {   // metrics only
            id: meas
            visible: false
            text: wg.ch === " " ? "0" : wg.ch
            font.family: root.serif
            font.pixelSize: wg.px
            font.weight: Font.Light
        }

        // the letters, surfacing behind the clear leading edge
        Item {
            width: Math.max(0, wg.reveal * wg.width)
            height: wg.height
            clip: true
            Text {
                text: wg.ch
                textFormat: Text.PlainText
                color: wg.face
                font.family: root.serif
                font.pixelSize: wg.px
                font.weight: Font.Light
            }
        }
        // the fingertip smear leading the wipe
        Rectangle {
            visible: wg.reveal > 0.02 && wg.reveal < 0.98
            x: wg.reveal * wg.width - width / 2
            width: wg.px * 0.22
            height: wg.height * 0.94
            radius: width / 2
            opacity: 0.55
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.inkA(0.0) }
                GradientStop { position: 0.45; color: root.inkA(0.30) }
                GradientStop { position: 1.0; color: root.inkA(0.0) }
            }
        }

        // minute turn: the glass takes the old digit back, then writes the new
        SequentialAnimation {
            id: rewrite
            NumberAnimation { target: wg; property: "opacity"; to: 0; duration: 520; easing.type: Easing.InOutSine }
            ScriptAction { script: { wg.ch = wg.target; wg.reveal = 0; wg.opacity = 1 } }
            NumberAnimation { target: wg; property: "reveal"; from: 0; to: 1; duration: 820; easing.type: Easing.InOutSine }
        }
        onTargetChanged: {
            if (wg.ch === " ") { wg.ch = target; wg.reveal = 0; firstWrite.restart() }
            else rewrite.restart()
        }
        NumberAnimation { id: firstWrite; target: wg; property: "reveal"; from: 0; to: 1; duration: 900; easing.type: Easing.InOutSine }
    }

    // ── the ensemble, on the left pane's dim clouds ─────────────────────────
    Item {
        id: pane
        x: Math.round(root.width * 0.065)
        y: Math.round(root.height * 0.085)
        width: 480
        height: 300
        scale: pal.uiScale
        transformOrigin: Item.TopLeft

        // the breath: a haze blooming on the glass behind everything
        Canvas {
            id: breath
            anchors.fill: parent
            opacity: 0
            NumberAnimation on opacity { running: true; to: 1; duration: 1600; easing.type: Easing.InOutSine }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height
                // an irregular condensation blob — three overlapping breaths
                for (let i = 0; i < 3; i++) {
                    const cx = w * (0.30 + 0.22 * i + 0.05 * root.rnd(i * 7 + 1))
                    const cy = h * (0.38 + 0.10 * root.rnd(i * 13 + 3))
                    const r = w * (0.30 - 0.05 * i)
                    const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                    g.addColorStop(0, String(Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.055)))
                    g.addColorStop(0.7, String(Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.022)))
                    g.addColorStop(1, String(Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0)))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, w, h)
                }
            }
            Component.onCompleted: requestPaint()
            Connections {
                target: root.pal
                function onTextChanged() { breath.requestPaint() }
            }
        }

        Column {
            x: 26
            y: 18
            spacing: 10

            // whose hour this is
            Text {
                text: "the last quiet hour"
                color: root.inkA(0.42)
                font.family: root.serif
                font.italic: true
                font.pixelSize: 15
                font.letterSpacing: 3
                opacity: 0
                NumberAnimation on opacity { running: true; to: 1; duration: 2200; easing.type: Easing.InOutSine }
            }

            // the time, written on the glass
            Row {
                id: digitRow
                spacing: 6
                WrittenGlyph { target: root.hhmm.charAt(0) }
                WrittenGlyph { target: root.hhmm.charAt(1) }
                // the colon: two beads on the glass, breathing
                Item {
                    width: 22
                    height: 100
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: 2
                        Rectangle {
                            required property int index
                            x: 8
                            y: 32 + index * 30
                            width: 7; height: 8
                            radius: 4
                            color: root.paneA(0.75)
                            // the glint riding the bead
                            Rectangle { x: 1.5; y: 1.5; width: 2; height: 2; radius: 1; color: root.inkA(0.85) }
                            SequentialAnimation on opacity {
                                running: !root.occluded && root.visible
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.45; duration: 3600 + index * 900; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0.95; duration: 3600 + index * 900; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
                WrittenGlyph { target: root.hhmm.charAt(3) }
                WrittenGlyph { target: root.hhmm.charAt(4) }
            }

            // the meniscus: a sagging waterline under the hour, beads resting on it
            Canvas {
                id: meniscus
                width: digitRow.width
                height: 12
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width
                    ctx.beginPath()
                    ctx.moveTo(0, 3)
                    ctx.quadraticCurveTo(w * 0.30, 6.5, w * 0.55, 4.5)
                    ctx.quadraticCurveTo(w * 0.80, 3, w, 5.5)
                    ctx.strokeStyle = String(root.paneA(0.38))
                    ctx.lineWidth = 1.2
                    ctx.stroke()
                    // beads sitting on the line
                    for (let i = 0; i < 3; i++) {
                        const bx = w * (0.16 + 0.3 * i + 0.08 * root.rnd(i * 31 + 5))
                        ctx.beginPath()
                        ctx.ellipse(bx, 1.5, 5, 6)
                        ctx.fillStyle = String(root.paneA(0.55))
                        ctx.fill()
                    }
                }
                Component.onCompleted: requestPaint()
                Connections {
                    target: root.pal
                    function onNeonChanged() { meniscus.requestPaint() }
                }
            }

            // the date, in her handwriting
            Text {
                text: Qt.formatDateTime(clock.date, "dddd d MMMM").toLowerCase()
                color: root.inkA(0.55)
                font.family: root.serif
                font.italic: true
                font.pixelSize: 17
                font.letterSpacing: 2
            }
        }

        // ── the minute's droplet: a bead at the line's end breaks and runs ──
        Item {
            id: drop
            property real t: -1
            visible: t >= 0
            x: 26 + digitRow.width - 4
            y: 148
            // the bead, falling — gravity wins suddenly
            Rectangle {
                id: dropBead
                x: -3
                y: 92 * Math.max(0, drop.t) * Math.max(0, drop.t)   // ease-in fall
                width: 6; height: 8
                radius: 3
                color: root.paneA(0.85 * (1 - Math.max(0, drop.t) * 0.5))
                Rectangle { x: 1.2; y: 1.4; width: 1.8; height: 1.8; radius: 1; color: root.inkA(0.9) }
            }
            // the thinning trail it leaves
            Rectangle {
                x: -1
                y: 0
                width: 1.6
                height: dropBead.y
                opacity: 0.4 * (1 - Math.max(0, drop.t))
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.paneA(0.0) }
                    GradientStop { position: 1.0; color: root.paneA(0.8) }
                }
            }
            SequentialAnimation {
                id: dropAnim
                NumberAnimation { target: drop; property: "t"; from: 0; to: 1; duration: 620; easing.type: Easing.Linear }
                PauseAnimation { duration: 260 }
                PropertyAction { target: drop; property: "t"; value: -1 }
            }
        }
        Connections {
            target: clock
            function onDateChanged() { if (!root.occluded && root.visible) dropAnim.restart() }
        }
    }
}
