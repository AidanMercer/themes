import QtQuick

// guts: lock overlay, drawn above the standard blurred lock content (the
// theme clock + passcode dots are already there). As the lock engages the
// screen is framed like a manga page: heavy black panel rules close in
// from the edges, a screentone vignette shades the corners, a paper page
// tag stamps the bottom-right, and the Brand of Sacrifice fades in over
// the swordsman and weeps a thin red drip. On unlock a sword-slash wipes
// diagonally across as the frame slides back out (everything rides
// host.progress, so the retreat is automatic).
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    property var host
    readonly property color ink:   pal.text
    readonly property color blood: pal.neon
    readonly property color fresh: pal.magenta
    readonly property color paper: pal.glass
    readonly property real ui: pal.uiScale
    readonly property real p: host ? host.progress : 0
    readonly property string serif: "Noto Serif Display"
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function paperA(a) { return Qt.rgba(paper.r, paper.g, paper.b, a) }

    readonly property real inset: Math.round(30 * ui)
    readonly property real ruleW: Math.round(7 * ui)

    // ── screentone vignette in the corners ───────────────────────────────────
    Canvas {
        id: toneCv
        anchors.fill: parent
        opacity: root.p * 0.5
        visible: root.p > 0.01
        Connections {
            target: root.pal
            function onTextChanged() { toneCv.requestPaint() }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            const rad = Math.min(w, h) * 0.36
            ctx.fillStyle = root.inkA(0.5)
            const corners = [[0, 0], [w, 0], [0, h], [w, h]]
            for (const c of corners) {
                for (let gy = -rad; gy <= rad; gy += 11) {
                    for (let gx = -rad; gx <= rad; gx += 11) {
                        const dd = Math.hypot(gx, gy) / rad
                        if (dd > 1) continue
                        const px = c[0] + gx + ((gy / 11) % 2 ? 5.5 : 0)
                        const py = c[1] + gy
                        if (px < -4 || px > w + 4 || py < -4 || py > h + 4) continue
                        ctx.beginPath()
                        ctx.arc(px, py, 2.6 * (1 - dd), 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
            }
        }
    }

    // ── the page frame closing in ────────────────────────────────────────────
    // top rule
    Rectangle {
        x: root.inset; width: parent.width - root.inset * 2; height: root.ruleW
        y: root.inset - (root.inset + height + 8) * (1 - root.p)
        color: root.ink
    }
    // bottom rule
    Rectangle {
        x: root.inset; width: parent.width - root.inset * 2; height: root.ruleW
        y: parent.height - root.inset - height + (root.inset + height + 8) * (1 - root.p)
        color: root.ink
    }
    // left rule
    Rectangle {
        y: root.inset; height: parent.height - root.inset * 2; width: root.ruleW
        x: root.inset - (root.inset + width + 8) * (1 - root.p)
        color: root.ink
    }
    // right rule
    Rectangle {
        y: root.inset; height: parent.height - root.inset * 2; width: root.ruleW
        x: parent.width - root.inset - width + (root.inset + width + 8) * (1 - root.p)
        color: root.ink
    }
    // inner hairline — the double manga rule, a beat behind the heavy one
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.inset + Math.round(12 * root.ui)
        color: "transparent"
        border.color: root.inkA(0.55)
        border.width: 1
        opacity: Math.max(0, (root.p - 0.5) * 2)
    }

    // a red registration slash at the top-left, where the printer bled
    Rectangle {
        x: root.inset + Math.round(18 * root.ui)
        y: root.inset - Math.round(4 * root.ui)
        width: Math.round(22 * root.ui); height: Math.round(3 * root.ui)
        rotation: -32
        color: root.blood
        opacity: Math.max(0, (root.p - 0.7) * 3.3)
    }

    // ── page tag, bottom-right ───────────────────────────────────────────────
    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.inset + Math.round(16 * root.ui)
        anchors.bottomMargin: root.inset + Math.round(14 * root.ui)
        width: tagRow.width + Math.round(18 * root.ui)
        height: Math.round(26 * root.ui)
        color: root.paperA(0.92)
        border.color: root.inkA(0.8)
        border.width: 1
        opacity: Math.max(0, (root.p - 0.6) * 2.5)
        Row {
            id: tagRow
            anchors.centerIn: parent
            spacing: Math.round(6 * root.ui)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(11 * root.ui); height: Math.round(2.5 * root.ui)
                rotation: -32
                color: root.blood
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "guts"
                color: root.inkA(0.7)
                font.family: root.serif
                font.italic: true
                font.pixelSize: Math.round(11 * root.ui)
                font.letterSpacing: 1
            }
        }
    }

    // ── the Brand of Sacrifice, weeping ──────────────────────────────────────
    Item {
        id: brand
        readonly property real s: Math.round(88 * root.ui)
        x: Math.round(root.width * 0.60)
        y: Math.round(root.height * 0.13)
        width: s
        height: s * 1.5
        opacity: Math.max(0, (root.p - 0.55) / 0.45)

        Canvas {
            id: brandCv
            anchors.fill: parent
            Connections {
                target: root.pal
                function onNeonChanged() { brandCv.requestPaint() }
                function onGlassChanged() { brandCv.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const s = brand.s
                // paper casing so the rune reads on the dark cape
                root.paintBrand(ctx, 2, 2, s, root.paperA(0.85), 1, 3.5 * root.ui)
                root.paintBrand(ctx, 2, 2, s, root.blood, 1, 0)
            }
        }

        // the thin red drip — swells, runs, dries, runs again
        property real dripT: 0
        SequentialAnimation on dripT {
            running: root.p > 0.95 && root.visible
            loops: Animation.Infinite
            NumberAnimation { from: 0; to: 1; duration: 7000; easing.type: Easing.InQuad }
            PauseAnimation { duration: 1400 }
        }
        Rectangle {
            x: brand.s * 0.13
            y: brand.s * 1.42
            width: Math.max(1.5, Math.round(1.8 * root.ui))
            height: brand.dripT * 110 * root.ui
            color: root.fresh
            opacity: brand.dripT < 0.8 ? 0.85 : 0.85 * (1 - (brand.dripT - 0.8) / 0.2)
        }
        Rectangle {   // the bead at the drip's head
            x: brand.s * 0.13 - width / 3
            y: brand.s * 1.42 + brand.dripT * 110 * root.ui - height / 2
            width: Math.round(4 * root.ui); height: Math.round(5 * root.ui)
            radius: width / 2
            color: root.fresh
            opacity: brand.dripT > 0.02 && brand.dripT < 0.8 ? 0.9 : 0
        }
    }

    // ── the unlock slash ─────────────────────────────────────────────────────
    property real slashT: 0
    Connections {
        target: root.host
        function onUnlockingChanged() {
            if (root.host.unlocking) slashAnim.restart()
        }
    }
    NumberAnimation {
        id: slashAnim
        target: root; property: "slashT"
        from: 0; to: 1; duration: 420; easing.type: Easing.InOutQuad
    }
    Item {
        visible: root.slashT > 0.01 && root.slashT < 0.99
        anchors.fill: parent
        Rectangle {
            readonly property real diag: Math.hypot(root.width, root.height)
            width: diag * 1.4
            height: Math.round(16 * root.ui)
            rotation: -34
            x: root.width * (root.slashT * 1.8 - 0.9) - width / 2 + root.width / 2
            y: root.height * (root.slashT * 1.6 - 0.8) - height / 2 + root.height / 2
            color: root.paperA(0.95)
            Rectangle {   // the arterial edge of the cut
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(2, Math.round(2.5 * root.ui))
                color: root.fresh
            }
        }
    }

    // the Brand — casing pass (big lw strokes a fat outline) then fill pass
    function paintBrand(ctx, x, y, s, col, alpha, lw) {
        ctx.save()
        ctx.globalAlpha = alpha
        ctx.fillStyle = col
        ctx.strokeStyle = col
        ctx.lineWidth = lw > 0 ? lw : Math.max(0.8, 0.035 * s)
        ctx.lineJoin = "round"
        function body() {
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
        }
        function barb() {
            ctx.beginPath()
            ctx.moveTo(x + 0.50 * s, y + 0.30 * s)
            ctx.quadraticCurveTo(x + 0.78 * s, y + 0.32 * s, x + 0.92 * s, y + 0.52 * s)
            ctx.quadraticCurveTo(x + 0.70 * s, y + 0.46 * s, x + 0.46 * s, y + 0.42 * s)
            ctx.closePath()
        }
        body(); ctx.stroke(); ctx.fill()
        barb(); ctx.stroke(); ctx.fill()
        // the drop under the tail
        ctx.beginPath()
        ctx.arc(x + 0.13 * s, y + 1.36 * s, 0.05 * s + (lw > 0 ? lw / 2 : 0), 0, Math.PI * 2)
        ctx.fill()
        ctx.restore()
    }
}
