import QtQuick
import Quickshell

// guts: desktop clock in the empty paper-white sky, upper-left.
// A manga caption panel: thin imperfect ink rules on a faint paper wash
// (the wash keeps it readable on the lock screen's darkened blur), big
// brush-serif numerals that ink themselves in left-to-right, a rough gray
// brush stroke beneath, and a blood-red hanko seal carrying the Brand of
// Sacrifice that stamps down once a minute.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color ink:   pal.text
    readonly property color blood: pal.neon
    readonly property color paper: pal.glass
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"
    readonly property string sans: "Noto Sans"
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function paperA(a) { return Qt.rgba(paper.r, paper.g, paper.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hh: Qt.formatDateTime(clock.date, "HH")
    readonly property string mm: Qt.formatDateTime(clock.date, "mm")

    // boot-in
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

    // once a minute the seal stamps back down
    property int _lastMin: -1
    Connections {
        target: clock
        function onDateChanged() {
            const m = clock.date.getMinutes()
            if (root._lastMin >= 0 && m !== root._lastMin && root.bootT >= 1)
                sealStamp.restart()
            root._lastMin = m
        }
    }

    // ── the Brand of Sacrifice — hooked head, barb, tapering tail, a drop ────
    function paintBrand(ctx, x, y, s, col, alpha) {
        ctx.save()
        ctx.globalAlpha = alpha
        ctx.fillStyle = col
        ctx.strokeStyle = col
        ctx.lineWidth = Math.max(0.8, 0.035 * s)   // fattens the tail at seal sizes
        ctx.lineJoin = "round"
        ctx.beginPath()
        ctx.moveTo(x + 0.02 * s, y + 0.32 * s)
        ctx.quadraticCurveTo(x + 0.10 * s, y + 0.02 * s, x + 0.38 * s, y + 0.00 * s)
        ctx.quadraticCurveTo(x + 0.62 * s, y - 0.01 * s, x + 0.66 * s, y + 0.20 * s)
        ctx.quadraticCurveTo(x + 0.68 * s, y + 0.34 * s, x + 0.52 * s, y + 0.44 * s)
        ctx.quadraticCurveTo(x + 0.34 * s, y + 0.55 * s, x + 0.24 * s, y + 0.78 * s)
        ctx.quadraticCurveTo(x + 0.14 * s, y + 1.00 * s, x + 0.14 * s, y + 1.22 * s)
        ctx.quadraticCurveTo(x + 0.10 * s, y + 0.98 * s, x + 0.20 * s, y + 0.72 * s)
        ctx.quadraticCurveTo(x + 0.28 * s, y + 0.50 * s, x + 0.40 * s, y + 0.36 * s)
        ctx.quadraticCurveTo(x + 0.52 * s, y + 0.22 * s, x + 0.44 * s, y + 0.14 * s)
        ctx.quadraticCurveTo(x + 0.34 * s, y + 0.06 * s, x + 0.20 * s, y + 0.16 * s)
        ctx.quadraticCurveTo(x + 0.08 * s, y + 0.24 * s, x + 0.02 * s, y + 0.32 * s)
        ctx.closePath()
        ctx.fill(); ctx.stroke()
        // barb off the right shoulder
        ctx.beginPath()
        ctx.moveTo(x + 0.50 * s, y + 0.30 * s)
        ctx.quadraticCurveTo(x + 0.78 * s, y + 0.32 * s, x + 0.92 * s, y + 0.52 * s)
        ctx.quadraticCurveTo(x + 0.70 * s, y + 0.46 * s, x + 0.46 * s, y + 0.42 * s)
        ctx.closePath()
        ctx.fill(); ctx.stroke()
        // the weeping drop under the tail
        ctx.beginPath()
        ctx.arc(x + 0.13 * s, y + 1.36 * s, 0.05 * s, 0, Math.PI * 2)
        ctx.fill()
        ctx.restore()
    }

    // ── the caption panel ────────────────────────────────────────────────────
    Item {
        id: panel
        x: Math.round(root.width * 0.055)
        y: Math.round(root.height * 0.085) - Math.round(18 * (1 - root.bootT))
        width: col.width + 76 * root.ui + seal.width
        height: col.height + 44 * root.ui
        opacity: root.bootT

        // paper wash — near-invisible over the white sky, earns its keep on
        // the lock screen's darkened blur
        Rectangle {
            anchors.fill: parent
            color: root.paperA(0.55)
        }

        // imperfect panel rules, hand-wavered
        Canvas {
            id: frame
            anchors.fill: parent
            Connections {
                target: root.pal
                function onTextChanged() { frame.requestPaint() }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height
                ctx.strokeStyle = root.inkA(0.85)
                ctx.lineWidth = 2 * root.ui
                function waverLine(x0, y0, x1, y1) {
                    ctx.beginPath()
                    ctx.moveTo(x0, y0)
                    const steps = 14
                    for (let i = 1; i <= steps; i++) {
                        const t = i / steps
                        const wob = Math.sin(t * 9 + x0 + y0) * 0.9
                        const nx = x0 + (x1 - x0) * t + (y0 === y1 ? 0 : wob)
                        const ny = y0 + (y1 - y0) * t + (y0 === y1 ? wob : 0)
                        ctx.lineTo(nx, ny)
                    }
                    ctx.stroke()
                }
                waverLine(0, 1, w, 1)
                waverLine(0, h - 1, w, h - 1)
                waverLine(1, 0, 1, h)
                waverLine(w - 1, 0, w - 1, h)
                // panel gutter tick, bottom-left — like a page corner
                ctx.lineWidth = 1
                ctx.strokeStyle = root.inkA(0.4)
                waverLine(0, h - 7 * root.ui, 26 * root.ui, h - 7 * root.ui)
            }
        }

        Column {
            id: col
            x: 26 * root.ui
            y: 20 * root.ui
            spacing: Math.round(10 * root.ui)

            // the time — each digit inks itself in
            Row {
                id: timeRow
                spacing: 0
                InkDigit { ch: root.hh[0]; ord: 0 }
                InkDigit { ch: root.hh[1]; ord: 1 }
                Text {   // the cut between panels
                    anchors.verticalCenter: parent.verticalCenter
                    text: ":"
                    color: root.inkA(0.45)
                    font.family: root.serif
                    font.pixelSize: Math.round(96 * root.ui)
                    font.weight: Font.Black
                }
                InkDigit { ch: root.mm[0]; ord: 2 }
                InkDigit { ch: root.mm[1]; ord: 3 }
            }

            // rough drying brush stroke under the numerals
            Canvas {
                id: underStroke
                width: timeRow.width
                height: Math.round(14 * root.ui)
                Connections {
                    target: root.pal
                    function onTextChanged() { underStroke.requestPaint() }
                }
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    if (w <= 0) return
                    ctx.beginPath()
                    ctx.moveTo(0, h * 0.35)
                    // pressure swells mid-stroke, frays at the exit
                    for (let x = 0; x <= w; x += 6) {
                        const t = x / w
                        const press = Math.sin(t * Math.PI) * 0.5 + 0.2
                        const wob = Math.sin(t * 21) * 1.2
                        ctx.lineTo(x, h * 0.35 - press * 3 - wob)
                    }
                    for (let x = w; x >= 0; x -= 6) {
                        const t = x / w
                        const press = Math.sin(t * Math.PI) * 0.5 + 0.2
                        const wob = Math.cos(t * 17) * 1.4
                        ctx.lineTo(x, h * 0.35 + press * h * 0.5 + wob)
                    }
                    ctx.closePath()
                    ctx.fillStyle = root.inkA(0.30)
                    ctx.fill()
                    // dry-brush flecks trailing off the end
                    ctx.fillStyle = root.inkA(0.22)
                    for (let i = 0; i < 5; i++) {
                        const fx = w * (0.86 + i * 0.028)
                        ctx.beginPath()
                        ctx.arc(Math.min(fx, w - 2), h * (0.3 + (i % 3) * 0.2), 1.3, 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
            }

            // the date line — a red slash where others put a dot
            Row {
                spacing: Math.round(12 * root.ui)
                Text {
                    text: Qt.formatDateTime(clock.date, "dddd").toUpperCase()
                    color: root.inkA(0.58)
                    font.family: root.sans
                    font.pixelSize: Math.round(14 * root.ui)
                    font.letterSpacing: 6
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(14 * root.ui); height: Math.round(2.5 * root.ui)
                    rotation: -32
                    color: root.blood
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "MMMM dd").toUpperCase()
                    color: root.inkA(0.58)
                    font.family: root.sans
                    font.pixelSize: Math.round(14 * root.ui)
                    font.letterSpacing: 6
                }
            }
        }

        // ── the hanko seal — stamps down once a minute ────────────────────────
        Item {
            id: seal
            width: Math.round(62 * root.ui)
            height: width
            anchors.right: parent.right
            anchors.rightMargin: Math.round(22 * root.ui)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(30 * root.ui)
            rotation: -6

            property real stampT: 1
            SequentialAnimation {
                id: sealStamp
                NumberAnimation { target: seal; property: "stampT"; to: 0; duration: 90; easing.type: Easing.InQuad }
                NumberAnimation { target: seal; property: "stampT"; to: 1; duration: 320; easing.type: Easing.OutBack }
            }
            scale: 1 + (1 - stampT) * 0.45
            opacity: 0.35 + stampT * 0.65

            Canvas {
                id: sealCv
                anchors.fill: parent
                Connections {
                    target: root.pal
                    function onNeonChanged() { sealCv.requestPaint() }
                    function onGlassChanged() { sealCv.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    // distressed red square — nicked corners, uneven edge
                    ctx.fillStyle = root.blood
                    ctx.beginPath()
                    ctx.moveTo(3, 1)
                    ctx.lineTo(w - 2, 3)
                    ctx.lineTo(w - 1, h * 0.4)
                    ctx.lineTo(w - 3, h - 2)
                    ctx.lineTo(w * 0.5, h - 1)
                    ctx.lineTo(2, h - 3)
                    ctx.lineTo(1, h * 0.55)
                    ctx.closePath()
                    ctx.fill()
                    // stamp grain — flecks of paper showing through
                    ctx.fillStyle = root.paperA(0.35)
                    const fl = [[0.16, 0.2], [0.83, 0.14], [0.9, 0.78], [0.2, 0.86], [0.55, 0.08]]
                    for (const f of fl) {
                        ctx.beginPath()
                        ctx.arc(w * f[0], h * f[1], 1.6, 0, Math.PI * 2)
                        ctx.fill()
                    }
                    // the Brand in negative paper-white
                    root.paintBrand(ctx, w * 0.24, h * 0.14, h * 0.52, root.paper, 0.96)
                }
            }
        }
    }

    // a digit that reveals like ink soaking left-to-right
    component InkDigit: Item {
        id: dig
        property string ch: ""
        property int ord: 0
        width: meas.implicitWidth
        height: meas.implicitHeight

        // invisible measuring twin so width stays stable while revealing
        Text {
            id: meas
            visible: false
            text: dig.ch
            font.family: root.serif
            font.pixelSize: Math.round(118 * root.ui)
            font.weight: Font.Black
        }

        property real reveal: 0
        SequentialAnimation {
            id: revealAnim
            PauseAnimation { duration: dig.ord * 110 }
            NumberAnimation { target: dig; property: "reveal"; from: 0; to: 1; duration: 460; easing.type: Easing.OutCubic }
        }
        onChChanged: revealAnim.restart()
        Component.onCompleted: revealAnim.restart()

        Item {
            clip: true
            width: dig.width * dig.reveal
            height: dig.height
            Text {
                text: dig.ch
                color: root.ink
                font.family: root.serif
                font.pixelSize: Math.round(118 * root.ui)
                font.weight: Font.Black
            }
        }
        // the wet ink edge chasing the reveal
        Rectangle {
            visible: dig.reveal > 0.02 && dig.reveal < 0.98
            x: dig.width * dig.reveal - width / 2
            y: dig.height * 0.16
            width: Math.round(3 * root.ui)
            height: dig.height * 0.68
            color: root.inkA(0.25)
        }
    }
}
