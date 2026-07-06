import QtQuick
import QtQuick.Effects
import Quickshell

// fuel: gas-price-sign clock, hung in the empty upper-left night sky.
// A chamfered roadside placard whose top edge carries the canopy's neon
// stripe (bending 45° at the corners). The time is four hand-built
// seven-segment digits — neon-tube orange over unpowered ghost segments —
// with a gas-price "9/10" fraction riding the minutes. Each digit buzzes
// on with a fluorescent-starter stutter at mount, and once in a long while
// a single random digit browns out for a beat, like a tired tube.
// Also mounted on the (non-bare) lock screen — the dark placard reads fine.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color neon:  pal.neon
    readonly property color ice:   pal.cyan
    readonly property color red:   pal.magenta
    readonly property color amber: pal.amber
    readonly property color dim:   pal.dim
    readonly property color ink:   pal.text
    readonly property string mono: pal.fontMono
    function neonA(a) { return Qt.rgba(neon.r, neon.g, neon.b, a) }
    function iceA(a)  { return Qt.rgba(ice.r, ice.g, ice.b, a) }
    function inkA(a)  { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hh: Qt.formatDateTime(clock.date, "HH")
    readonly property string mm: Qt.formatDateTime(clock.date, "mm")

    // ── seven-segment plumbing ──────────────────────────────────────────────
    // segment order: A top, B tr, C br, D bottom, E bl, F tl, G mid
    readonly property var segMasks: [
        [1,1,1,1,1,1,0],  // 0
        [0,1,1,0,0,0,0],  // 1
        [1,1,0,1,1,0,1],  // 2
        [1,1,1,1,0,0,1],  // 3
        [0,1,1,0,0,1,1],  // 4
        [1,0,1,1,0,1,1],  // 5
        [1,0,1,1,1,1,1],  // 6
        [1,1,1,0,0,0,0],  // 7
        [1,1,1,1,1,1,1],  // 8
        [1,1,1,1,0,1,1]   // 9
    ]
    function segGeom(i, W, H, t) {
        switch (i) {
        case 0: return { x: t * 0.75, y: 0,                w: W - t * 1.5, h: t }             // A
        case 1: return { x: W - t,    y: t * 0.65,         w: t,           h: H / 2 - t }     // B
        case 2: return { x: W - t,    y: H / 2 + t * 0.35, w: t,           h: H / 2 - t }     // C
        case 3: return { x: t * 0.75, y: H - t,            w: W - t * 1.5, h: t }             // D
        case 4: return { x: 0,        y: H / 2 + t * 0.35, w: t,           h: H / 2 - t }     // E
        case 5: return { x: 0,        y: t * 0.65,         w: t,           h: H / 2 - t }     // F
        default: return { x: t * 0.75, y: H / 2 - t / 2,   w: W - t * 1.5, h: t }             // G
        }
    }

    // one neon seven-segment digit; buzzes in on mount, flickers on demand
    component SegDigit: Item {
        id: sd
        property int value: 8
        property real segW: 34
        property int digitIndex: 0
        property real glowMul: 0          // buzz-in raises this to 1
        width: segW
        height: segW * 1.8
        readonly property real t: segW * 0.17
        readonly property var mask: (sd.value >= 0 && sd.value <= 9)
            ? root.segMasks[sd.value] : [0,0,0,0,0,0,0]

        // DSEG-style lean to the right
        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(1, -0.08, 0, 0.08 * sd.height,
                                 0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1)
        }

        Repeater {
            model: 7
            Rectangle {
                required property int index
                readonly property var g: root.segGeom(index, sd.width, sd.height, sd.t)
                x: g.x; y: g.y; width: g.w; height: g.h
                radius: sd.t / 2
                color: sd.mask[index] ? root.neon : root.ink
                opacity: sd.mask[index] ? 0.95 * sd.glowMul : 0.10
                Behavior on opacity { NumberAnimation { duration: 90 } }
            }
        }

        // fluorescent-starter buzz on mount, staggered per digit
        SequentialAnimation {
            running: true
            PauseAnimation { duration: 260 + sd.digitIndex * 150 }
            NumberAnimation { target: sd; property: "glowMul"; to: 0.55; duration: 45 }
            NumberAnimation { target: sd; property: "glowMul"; to: 0.10; duration: 60 }
            NumberAnimation { target: sd; property: "glowMul"; to: 0.85; duration: 45 }
            NumberAnimation { target: sd; property: "glowMul"; to: 0.30; duration: 70 }
            NumberAnimation { target: sd; property: "glowMul"; to: 1.0;  duration: 90 }
        }

        // rare single brown-out, driven by the root flicker timer
        Connections {
            target: root
            function onFlickNonceChanged() {
                if (root.flickIdx === sd.digitIndex) tubeFlick.restart()
            }
        }
        SequentialAnimation {
            id: tubeFlick
            NumberAnimation { target: sd; property: "glowMul"; to: 0.35; duration: 45 }
            NumberAnimation { target: sd; property: "glowMul"; to: 0.9;  duration: 60 }
            NumberAnimation { target: sd; property: "glowMul"; to: 0.55; duration: 55 }
            NumberAnimation { target: sd; property: "glowMul"; to: 1.0;  duration: 120 }
        }
    }

    // rare, subtle: one random digit stutters, every ~25–55s
    property int flickIdx: -1
    property int flickNonce: 0
    Timer {
        interval: 25000 + Math.floor(Math.random() * 30000)
        running: root.visible
        repeat: true
        onTriggered: {
            root.flickIdx = Math.floor(Math.random() * 4)
            root.flickNonce++
            interval = 25000 + Math.floor(Math.random() * 30000)
        }
    }

    // boot-in: the placard fades up while the digits buzz on
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

    // ── the sign ────────────────────────────────────────────────────────────
    Item {
        id: sign
        width: 372
        height: col.implicitHeight + 44
        x: Math.round(root.width * 0.045)
        y: Math.round(root.height * 0.085) - 14 * (1 - root.bootT)
        opacity: root.bootT
        scale: pal.uiScale
        transformOrigin: Item.TopLeft

        // chamfered placard; neon canopy stripe rides the top edge and bends
        // 45° down both top corners — the theme's signature line.
        Canvas {
            id: plate
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            Connections {
                target: root.pal
                function onNeonChanged()  { plate.requestPaint() }
                function onDimChanged()   { plate.requestPaint() }
                function onGlassChanged() { plate.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                const w = width, h = height, c = 16
                ctx.reset()
                // body: top corners chamfered like the canopy
                ctx.beginPath()
                ctx.moveTo(0, c); ctx.lineTo(c, 0); ctx.lineTo(w - c, 0)
                ctx.lineTo(w, c); ctx.lineTo(w, h); ctx.lineTo(0, h)
                ctx.closePath()
                const g = ctx.createLinearGradient(0, 0, 0, h)
                g.addColorStop(0, "rgba(6,9,13,0.78)")
                g.addColorStop(1, "rgba(4,6,9,0.62)")
                ctx.fillStyle = g
                ctx.fill()
                ctx.strokeStyle = root.pal.dim
                ctx.globalAlpha = 0.55
                ctx.lineWidth = 1
                ctx.stroke()
                ctx.globalAlpha = 1
                // the neon stripe: wide soft pass, then crisp core
                ctx.beginPath()
                ctx.moveTo(1, c + 5); ctx.lineTo(c + 2, 1.5)
                ctx.lineTo(w - c - 2, 1.5); ctx.lineTo(w - 1, c + 5)
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.strokeStyle = root.pal.neon
                ctx.lineWidth = 5
                ctx.globalAlpha = 0.22
                ctx.stroke()
                ctx.lineWidth = 1.7
                ctx.globalAlpha = 0.95
                ctx.stroke()
                ctx.globalAlpha = 1
            }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 26
            anchors.rightMargin: 26
            anchors.topMargin: 24
            spacing: 14

            // header: pump stripe band + FUEL wordmark + sign number
            Item {
                width: parent.width
                height: 20
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    // the retro 3-stripe pump band
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Rectangle { width: 26; height: 3; color: root.amber }
                        Rectangle { width: 26; height: 3; color: root.neon }
                        Rectangle { width: 26; height: 3; color: root.red }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "FUEL"
                        color: root.ink
                        font.family: root.mono
                        font.weight: Font.Black
                        font.pixelSize: 16
                        font.letterSpacing: 7
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Nº 07"
                    color: root.ice
                    opacity: 0.7
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 3
                }
            }

            // the price: HH : MM with a raised 9/10 fraction
            Item {
                width: parent.width
                height: 84

                Row {
                    id: timeRow
                    anchors.left: parent.left
                    spacing: 9

                    SegDigit { segW: 40; digitIndex: 0; value: parseInt(root.hh[0]) }
                    SegDigit { segW: 40; digitIndex: 1; value: parseInt(root.hh[1]) }
                    // colon: two square neon dots
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 18
                        Rectangle { width: 7; height: 7; radius: 2; color: root.neon; opacity: 0.9 }
                        Rectangle { width: 7; height: 7; radius: 2; color: root.neon; opacity: 0.9 }
                    }
                    SegDigit { segW: 40; digitIndex: 2; value: parseInt(root.mm[0]) }
                    SegDigit { segW: 40; digitIndex: 3; value: parseInt(root.mm[1]) }
                }

                // soft neon halo behind the digits
                MultiEffect {
                    source: timeRow
                    anchors.fill: timeRow
                    autoPaddingEnabled: true
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 24
                    colorization: 1.0
                    colorizationColor: root.neon
                    opacity: 0.5
                    z: -1
                }

                // the gas-price fraction, riding top-right of the minutes
                Column {
                    anchors.left: timeRow.right
                    anchors.leftMargin: 10
                    anchors.top: timeRow.top
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "9"
                        color: root.neon
                        font.family: root.mono
                        font.weight: Font.Bold
                        font.pixelSize: 17
                    }
                    Rectangle { width: 18; height: 2; color: root.neonA(0.75) }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "10"
                        color: root.neon
                        font.family: root.mono
                        font.weight: Font.Bold
                        font.pixelSize: 13
                    }
                }
            }

            // icy divider with the price grade rows below
            Rectangle { width: parent.width; height: 1; color: root.dim; opacity: 0.55 }

            Item {
                width: parent.width
                height: 15
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text {
                        text: "SELF SERVE"
                        color: root.ice
                        font.family: root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 4
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4; height: 4; rotation: 45
                        color: root.amber
                    }
                    Text {
                        text: "24 HR"
                        color: root.amber
                        font.family: root.mono
                        font.weight: Font.Bold
                        font.pixelSize: 10
                        font.letterSpacing: 3
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "ddd MMM dd").toUpperCase()
                    color: root.inkA(0.75)
                    font.family: root.mono
                    font.pixelSize: 11
                    font.letterSpacing: 3
                }
            }
        }
    }
}
