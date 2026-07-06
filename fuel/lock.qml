import QtQuick
import QtQuick.Effects
import QtQuick.Particles
import Quickshell

// fuel: bare lock (the bareLock marker tells LockStage we own the chrome).
// The station video keeps playing sharp — snow still falling, neon still
// humming — while extra snow drifts across the glass in the foreground.
// A STATION CLOSED neon sign powers on letter by letter with host.progress
// (STATION in icy tube-white, CLOSED in tail-light red), framed by a
// bent-corner tube that draws itself around the words. The passcode is a
// pump keypad: each keystroke presses a chamfered key alight. A blur-slice
// price placard bottom-left carries the time in seven-segment tubes.
// Everything rides host.progress so unlock plays it all back down.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color neon:  pal.neon
    readonly property color ice:   pal.cyan
    readonly property color red:   pal.magenta
    readonly property color amber: pal.amber
    readonly property color dim:   pal.dim
    readonly property color ink:   pal.text
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    readonly property string mono: pal.fontMono
    function neonA(a) { return Qt.rgba(neon.r, neon.g, neon.b, a) }
    function iceA(a)  { return Qt.rgba(ice.r, ice.g, ice.b, a) }
    function redA(a)  { return Qt.rgba(red.r, red.g, red.b, a) }
    function inkA(a)  { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    readonly property color glassTube: Qt.rgba(0.42, 0.46, 0.50, 1)

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hh: Qt.formatDateTime(clock.date, "HH")
    readonly property string mm: Qt.formatDateTime(clock.date, "mm")

    // gentle vignette so the chrome reads over the bright pumps
    Rectangle {
        anchors.fill: parent
        opacity: root.p * 0.35
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.55) }
            GradientStop { position: 0.35; color: "transparent" }
            GradientStop { position: 0.75; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
        }
    }

    // ── foreground snow, drifting across the whole pane ─────────────────────
    ParticleSystem {
        id: snowSys
        anchors.fill: parent
        running: root.visible && root.p > 0.05
        opacity: root.p

        Emitter {
            anchors.top: parent.top
            anchors.topMargin: -20
            width: parent.width
            height: 1
            emitRate: 16
            lifeSpan: 14000
            lifeSpanVariation: 4000
            size: 5
            sizeVariation: 3
            velocity: AngleDirection {
                angle: 90
                angleVariation: 8
                magnitude: 62
                magnitudeVariation: 30
            }
        }
        Wander {
            anchors.fill: parent
            xVariance: 60
            pace: 40
        }
        ItemParticle {
            delegate: Rectangle {
                width: 3 + Math.random() * 3
                height: width
                radius: width / 2
                color: root.ink
                opacity: 0.25 + Math.random() * 0.45
            }
        }
    }

    // ── STATION CLOSED — the neon sign, top-center sky ──────────────────────
    Item {
        id: sign
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.10)
        width: signCol.width + 96 * root.ui
        height: signCol.height + 56 * root.ui
        opacity: Math.min(1, root.p * 1.6)

        // per-letter power-on threshold across the lock engage
        readonly property string w1: "STATION"
        readonly property string w2: "CLOSED"
        readonly property int nLetters: w1.length + w2.length
        function litFor(i) {
            // letters power on across p 0.15 → 0.9, each with a hard-ish ramp
            const t0 = 0.15 + 0.72 * i / sign.nLetters
            return Math.max(0, Math.min(1, (root.p - t0) / 0.06))
        }

        // rare tube stutter once fully locked
        property int flickIdx: -1
        property real flickMul: 1
        Timer {
            interval: 20000 + Math.floor(Math.random() * 25000)
            running: root.visible && root.p > 0.98
            repeat: true
            onTriggered: {
                sign.flickIdx = Math.floor(Math.random() * sign.nLetters)
                signFlick.restart()
                interval = 20000 + Math.floor(Math.random() * 25000)
            }
        }
        SequentialAnimation {
            id: signFlick
            NumberAnimation { target: sign; property: "flickMul"; to: 0.3; duration: 50 }
            NumberAnimation { target: sign; property: "flickMul"; to: 0.85; duration: 60 }
            NumberAnimation { target: sign; property: "flickMul"; to: 0.5; duration: 55 }
            SequentialAnimation {
                NumberAnimation { target: sign; property: "flickMul"; to: 1.0; duration: 110 }
                ScriptAction { script: sign.flickIdx = -1 }
            }
        }

        // the bent-corner tube frame, drawing on with progress
        Canvas {
            id: signFrame
            anchors.fill: parent
            readonly property real t: Math.max(0, Math.min(1, (root.p - 0.1) / 0.8))
            onTChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height, c = 14 * root.ui
                if (w <= 0 || h <= 0) return
                // full chamfered ring path, then dash it on by t
                const pts = [
                    [c, 0.8], [w - c, 0.8], [w - 0.8, c], [w - 0.8, h - c],
                    [w - c, h - 0.8], [c, h - 0.8], [0.8, h - c], [0.8, c], [c, 0.8]
                ]
                let total = 0
                for (let i = 1; i < pts.length; i++)
                    total += Math.hypot(pts[i][0] - pts[i-1][0], pts[i][1] - pts[i-1][1])
                let budget = total * signFrame.t
                function drawPath() {
                    let left = budget
                    ctx.beginPath()
                    ctx.moveTo(pts[0][0], pts[0][1])
                    for (let i = 1; i < pts.length && left > 0; i++) {
                        const seg = Math.hypot(pts[i][0] - pts[i-1][0], pts[i][1] - pts[i-1][1])
                        if (seg <= left) { ctx.lineTo(pts[i][0], pts[i][1]); left -= seg }
                        else {
                            const f = left / seg
                            ctx.lineTo(pts[i-1][0] + (pts[i][0] - pts[i-1][0]) * f,
                                       pts[i-1][1] + (pts[i][1] - pts[i-1][1]) * f)
                            left = 0
                        }
                    }
                }
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                drawPath()
                ctx.strokeStyle = root.pal.neon
                ctx.globalAlpha = 0.20
                ctx.lineWidth = 5
                ctx.stroke()
                drawPath()
                ctx.globalAlpha = 0.9
                ctx.lineWidth = 1.6
                ctx.stroke()
                ctx.globalAlpha = 1
            }
        }

        // faint sign backing so the tubes read over bright frames
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            color: Qt.rgba(0, 0, 0, 0.38)
            z: -1
        }

        Column {
            id: signCol
            anchors.centerIn: parent
            spacing: 6 * root.ui

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(10 * root.ui)
                Repeater {
                    model: sign.w1.length
                    delegate: Item {
                        id: l1
                        required property int index
                        readonly property real lit: sign.litFor(index)
                            * (sign.flickIdx === index ? sign.flickMul : 1)
                        width: t1.width; height: t1.height
                        Text {
                            anchors.centerIn: t1
                            text: t1.text
                            color: root.ice
                            opacity: 0.35 * l1.lit
                            scale: 1.12
                            font: t1.font
                        }
                        Text {
                            id: t1
                            text: sign.w1[index]
                            color: l1.lit > 0.4
                                ? Qt.rgba(root.ice.r + (1 - root.ice.r) * 0.5,
                                          root.ice.g + (1 - root.ice.g) * 0.5,
                                          root.ice.b + (1 - root.ice.b) * 0.5, 1)
                                : root.glassTube
                            opacity: 0.30 + 0.70 * l1.lit
                            font.family: root.mono
                            font.weight: Font.Black
                            font.pixelSize: Math.round(44 * root.ui)
                            font.letterSpacing: 4
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(14 * root.ui)
                Repeater {
                    model: sign.w2.length
                    delegate: Item {
                        id: l2
                        required property int index
                        readonly property real lit: sign.litFor(sign.w1.length + index)
                            * (sign.flickIdx === sign.w1.length + index ? sign.flickMul : 1)
                        width: t2.width; height: t2.height
                        Text {
                            anchors.centerIn: t2
                            text: t2.text
                            color: root.red
                            opacity: 0.40 * l2.lit
                            scale: 1.14
                            font: t2.font
                        }
                        Text {
                            id: t2
                            text: sign.w2[index]
                            color: l2.lit > 0.4
                                ? Qt.rgba(root.red.r + (1 - root.red.r) * 0.45,
                                          root.red.g + (1 - root.red.g) * 0.45,
                                          root.red.b + (1 - root.red.b) * 0.45, 1)
                                : root.glassTube
                            opacity: 0.30 + 0.70 * l2.lit
                            font.family: root.mono
                            font.weight: Font.Black
                            font.pixelSize: Math.round(58 * root.ui)
                            font.letterSpacing: 6
                        }
                    }
                }
            }
        }
    }

    // ── blur-slice price placard: the time, bottom-left ─────────────────────
    readonly property real cardW: Math.round(330 * ui)
    readonly property real cardH: Math.round(150 * ui)
    readonly property real cardX: Math.round(48 * ui)
    readonly property real cardY: root.height - cardH - Math.round(64 * ui)

    ShaderEffectSource {
        id: slice
        sourceItem: root.host.backgroundItem
        sourceRect: Qt.rect(root.cardX, root.cardY, root.cardW, root.cardH)
        live: true
        visible: false
    }

    Item {
        id: card
        x: root.cardX
        y: root.cardY + Math.round(18 * root.ui) * (1 - root.p)
        width: root.cardW
        height: root.cardH
        opacity: root.p

        MultiEffect {
            anchors.fill: parent
            source: slice
            blurEnabled: true
            blur: 1.0
            blurMax: 44
            brightness: -0.22
            saturation: -0.15
        }
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.02, 0.035, 0.05, 0.45)
        }
        // bent neon stripe over the top edge
        Canvas {
            id: cardStripe
            anchors.fill: parent
            onWidthChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, c = 12 * root.ui
                ctx.beginPath()
                ctx.moveTo(0.8, c + 4); ctx.lineTo(c + 1.5, 1.2)
                ctx.lineTo(w - c - 1.5, 1.2); ctx.lineTo(w - 0.8, c + 4)
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.strokeStyle = root.pal.neon
                ctx.lineWidth = 4
                ctx.globalAlpha = 0.20
                ctx.stroke()
                ctx.lineWidth = 1.5
                ctx.globalAlpha = 0.9
                ctx.stroke()
                ctx.globalAlpha = 1
            }
        }

        // seven-segment time
        Row {
            id: cardTime
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(30 * root.ui)
            spacing: Math.round(7 * root.ui)
            Repeater {
                model: [0, 1, -1, 2, 3]
                delegate: Item {
                    id: cd
                    required property var modelData
                    readonly property bool colon: modelData === -1
                    readonly property string src: root.hh + root.mm
                    readonly property int value: colon ? -1 : parseInt(src[modelData])
                    width: colon ? Math.round(10 * root.ui) : Math.round(26 * root.ui)
                    height: Math.round(47 * root.ui)
                    readonly property var mask: cd.colon || isNaN(cd.value) ? [0,0,0,0,0,0,0] : [
                        [1,1,1,1,1,1,0], [0,1,1,0,0,0,0], [1,1,0,1,1,0,1], [1,1,1,1,0,0,1],
                        [0,1,1,0,0,1,1], [1,0,1,1,0,1,1], [1,0,1,1,1,1,1], [1,1,1,0,0,0,0],
                        [1,1,1,1,1,1,1], [1,1,1,1,0,1,1]][cd.value]
                    // colon dots
                    Column {
                        visible: cd.colon
                        anchors.centerIn: parent
                        spacing: Math.round(12 * root.ui)
                        Rectangle { width: Math.round(5 * root.ui); height: width; radius: 1; color: root.neon; opacity: 0.9 }
                        Rectangle { width: Math.round(5 * root.ui); height: width; radius: 1; color: root.neon; opacity: 0.9 }
                    }
                    Repeater {
                        model: cd.colon ? 0 : 7
                        Rectangle {
                            required property int index
                            readonly property real t: cd.width * 0.17
                            readonly property var g: {
                                const W = cd.width, H = cd.height, tt = t
                                switch (index) {
                                case 0: return { x: tt * 0.75, y: 0,                 w: W - tt * 1.5, h: tt }
                                case 1: return { x: W - tt,    y: tt * 0.65,         w: tt,           h: H / 2 - tt }
                                case 2: return { x: W - tt,    y: H / 2 + tt * 0.35, w: tt,           h: H / 2 - tt }
                                case 3: return { x: tt * 0.75, y: H - tt,            w: W - tt * 1.5, h: tt }
                                case 4: return { x: 0,         y: H / 2 + tt * 0.35, w: tt,           h: H / 2 - tt }
                                case 5: return { x: 0,         y: tt * 0.65,         w: tt,           h: H / 2 - tt }
                                default: return { x: tt * 0.75, y: H / 2 - tt / 2,   w: W - tt * 1.5, h: tt }
                                }
                            }
                            x: g.x; y: g.y; width: g.w; height: g.h
                            radius: t / 2
                            color: cd.mask[index] ? root.neon : root.ink
                            opacity: cd.mask[index] ? 0.95 : 0.10
                        }
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: cardTime.bottom
            anchors.topMargin: Math.round(14 * root.ui)
            text: Qt.formatDateTime(clock.date, "ddd MMM dd").toUpperCase()
            color: root.iceA(0.8)
            font.family: root.mono
            font.pixelSize: Math.round(11 * root.ui)
            font.letterSpacing: 4
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(12 * root.ui)
            spacing: 8
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Rectangle { width: 14; height: 2; color: root.amber; opacity: 0.8 }
                Rectangle { width: 14; height: 2; color: root.neon; opacity: 0.9 }
                Rectangle { width: 14; height: 2; color: root.red; opacity: 0.7 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "PUMPS LOCKED · 24 HR"
                color: root.inkA(0.5)
                font.family: root.mono
                font.pixelSize: Math.round(8 * root.ui)
                font.letterSpacing: 3
            }
        }
    }

    // ── pump keypad passcode, bottom-center ─────────────────────────────────
    Column {
        id: passArea
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.80)
        spacing: Math.round(16 * root.ui)
        opacity: root.p

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(10 * root.ui)
            Repeater {
                model: Math.max(root.host.pwLength, 1)
                delegate: Item {
                    id: key
                    required property int index
                    readonly property bool pressed: index < root.host.pwLength
                    width: Math.round(16 * root.ui)
                    height: Math.round(20 * root.ui)
                    // chamfered key: a rect with its top-right corner cut
                    Canvas {
                        id: keyFill
                        anchors.fill: parent
                        opacity: key.pressed ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        Component.onCompleted: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const w = width, h = height, c = w * 0.35
                            ctx.beginPath()
                            ctx.moveTo(0, 0); ctx.lineTo(w - c, 0); ctx.lineTo(w, c)
                            ctx.lineTo(w, h); ctx.lineTo(0, h)
                            ctx.closePath()
                            ctx.fillStyle = root.host.failed
                                ? Qt.rgba(root.red.r, root.red.g, root.red.b, 0.85)
                                : Qt.rgba(root.amber.r, root.amber.g, root.amber.b, 0.9)
                            ctx.fill()
                        }
                        Connections {
                            target: root.host
                            function onFailedChanged() { keyFill.requestPaint() }
                        }
                    }
                    // resting key outline
                    Canvas {
                        anchors.fill: parent
                        opacity: key.pressed ? 0 : 0.45
                        Component.onCompleted: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const w = width, h = height, c = w * 0.35
                            ctx.beginPath()
                            ctx.moveTo(0.5, 0.5); ctx.lineTo(w - c, 0.5); ctx.lineTo(w - 0.5, c)
                            ctx.lineTo(w - 0.5, h - 0.5); ctx.lineTo(0.5, h - 0.5)
                            ctx.closePath()
                            ctx.strokeStyle = root.glassTube
                            ctx.lineWidth = 1
                            ctx.stroke()
                        }
                    }
                    scale: key.pressed ? (root.host.busy ? 0.8 : 1) : 0.9
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.host.failed ? "CODE REJECTED — SEE ATTENDANT"
                : root.host.busy ? "AUTHORIZING…"
                : root.host.pwLength === 0 ? "ENTER ATTENDANT CODE" : ""
            color: root.host.failed ? root.red : root.iceA(0.75)
            font.family: root.mono
            font.pixelSize: Math.round(11 * root.ui)
            font.letterSpacing: 4
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.55)
        }
    }
    // wrong code: the keypad flinches
    Connections {
        target: root.host
        function onFailedChanged() { if (root.host.failed) shake.restart() }
    }
    SequentialAnimation {
        id: shake
        NumberAnimation { target: passArea; property: "anchors.horizontalCenterOffset"; to: -9; duration: 50 }
        NumberAnimation { target: passArea; property: "anchors.horizontalCenterOffset"; to: 8; duration: 50 }
        NumberAnimation { target: passArea; property: "anchors.horizontalCenterOffset"; to: -5; duration: 50 }
        NumberAnimation { target: passArea; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
    }
}
