import QtQuick
import Quickshell

// road8: the time, written on the sky in fat amber pixels — the same light as
// the city below, hung in the empty air up and left of the lone star. No
// pixel font is installed, so the theme draws its own: a 5×7 bitmap glyph
// renderer on Canvas, one dark drop-pixel behind every lit cell so it reads
// over the blurred lock wallpaper too. Digits don't fade — they REROLL: when
// the minute turns, each changed digit rewrites itself row by row, top to
// bottom, like a display taking new data. The colon is a hard 1Hz blink, and
// once a minute a pair of taillight pixels dashes under the date and is gone.
// Click-through scenery; everything stops while occluded.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while locked or a fullscreen window covers the monitor
    property bool occluded: false

    readonly property color amber: pal.neon
    readonly property color starlight: pal.cyan
    readonly property color tail: pal.magenta
    readonly property color ink: pal.text
    readonly property string mono: pal.fontMono
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // ── the house pixel font: 5×7 rows, "1" = lit cell ─────────────────────
    readonly property var pixmap: ({
        "0": ["01110","10001","10011","10101","11001","10001","01110"],
        "1": ["00100","01100","00100","00100","00100","00100","01110"],
        "2": ["01110","10001","00001","00010","00100","01000","11111"],
        "3": ["11111","00010","00100","00010","00001","10001","01110"],
        "4": ["00010","00110","01010","10010","11111","00010","00010"],
        "5": ["11111","10000","11110","00001","00001","10001","01110"],
        "6": ["00110","01000","10000","11110","10001","10001","01110"],
        "7": ["11111","00001","00010","00100","01000","01000","01000"],
        "8": ["01110","10001","10001","01110","10001","10001","01110"],
        "9": ["01110","10001","10001","01111","00001","00010","01100"],
        ":": ["000","000","010","000","010","000","000"],
        "*": ["00100","00100","11011","00100","01010"],
        " ": ["00000","00000","00000","00000","00000","00000","00000"]
    })

    // one glyph on one canvas. rows below `sweep` still show the OLD glyph, so
    // animating sweep 0→7 rewrites the digit top-to-bottom — the reroll.
    component PixelGlyph: Canvas {
        id: g
        property string ch: " "
        property string prevCh: " "
        property int sweep: 7
        property real cell: 9
        property color face: root.amber
        property real shadeA: 0.5
        readonly property var mNew: root.pixmap[ch] || root.pixmap[" "]
        readonly property var mOld: root.pixmap[prevCh] || root.pixmap[" "]
        width: (mNew[0].length + 0.4) * cell
        height: (mNew.length + 0.4) * cell
        onSweepChanged: requestPaint()
        onChChanged: requestPaint()
        onFaceChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const c = cell, gap = Math.max(1, c * 0.16)
            const rows = mNew.length
            // pass 1: drop shadows, one pixel down-right, so faces stay crisp
            ctx.fillStyle = String(Qt.rgba(0, 0, 0, shadeA))
            for (let r = 0; r < rows; r++) {
                const m = r < sweep ? mNew : mOld
                for (let k = 0; k < m[r].length; k++)
                    if (m[r].charAt(k) === "1")
                        ctx.fillRect(k * c + c * 0.34, r * c + c * 0.34, c - gap, c - gap)
            }
            // pass 2: lit faces
            ctx.fillStyle = String(face)
            for (let r = 0; r < rows; r++) {
                const m = r < sweep ? mNew : mOld
                for (let k = 0; k < m[r].length; k++)
                    if (m[r].charAt(k) === "1")
                        ctx.fillRect(k * c, r * c, c - gap, c - gap)
            }
        }
    }

    // a digit that rerolls whenever its target changes (sweep is an int, so
    // the animation lands on whole rows — stepped, never smooth)
    component RollDigit: PixelGlyph {
        id: rd
        property string target: " "
        NumberAnimation { id: roll; target: rd; property: "sweep"; from: 0; to: 7; duration: 300 }
        onTargetChanged: { rd.prevCh = rd.ch; rd.ch = target; roll.restart() }
        Component.onCompleted: { rd.prevCh = " "; rd.ch = target; roll.restart() }
    }

    // ── the ensemble, parked in the upper-left sky ──────────────────────────
    Item {
        id: sign
        x: Math.round(root.width * 0.075)
        y: Math.round(root.height * 0.10)
        width: digitRow.width
        height: 150
        scale: pal.uiScale
        transformOrigin: Item.TopLeft

        // slow fade up on boot — the digits themselves boot by rerolling
        opacity: 0
        NumberAnimation on opacity { running: true; to: 1; duration: 500 }

        // faint pool of city light behind the digits
        Canvas {
            id: halo
            anchors.centerIn: digitRow
            width: digitRow.width * 1.9
            height: digitRow.height * 3
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const g = ctx.createRadialGradient(width / 2, height / 2, 0, width / 2, height / 2, width / 2)
                g.addColorStop(0, root.amberA(0.07))
                g.addColorStop(1, root.amberA(0))
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, height)
            }
            Component.onCompleted: requestPaint()
            Connections {
                target: root.pal
                function onNeonChanged() { halo.requestPaint() }
            }
        }

        Column {
            spacing: 10

            // header: a pixel spark + where we are
            Row {
                spacing: 10
                PixelGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    ch: "*"
                    cell: 3
                    face: root.starlight
                    shadeA: 0.35
                    // the star breathes, slowly, only while someone can see it
                    SequentialAnimation on opacity {
                        running: !root.occluded && root.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 2600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 2600; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "BEFORE THE ROAD"
                    color: root.inkA(0.55)
                    font.family: root.mono
                    font.pixelSize: 11
                    font.letterSpacing: 6
                }
            }

            // the time in house pixels
            Row {
                id: digitRow
                spacing: 8
                RollDigit { target: root.hhmm.charAt(0) }
                RollDigit { target: root.hhmm.charAt(1) }
                PixelGlyph {
                    id: colon
                    ch: ":"
                    property bool tick: true
                    opacity: tick ? 1 : 0.22   // hard blink, no easing — it's a display
                    Timer {
                        interval: 1000; repeat: true
                        running: !root.occluded && root.visible
                        onTriggered: colon.tick = !colon.tick
                    }
                    onVisibleChanged: if (!visible) tick = true
                }
                RollDigit { target: root.hhmm.charAt(3) }
                RollDigit { target: root.hhmm.charAt(4) }
            }

            // the center line: five amber dashes, then the date
            Row {
                spacing: 9
                Repeater {
                    model: 5
                    Rectangle {
                        width: 14; height: 3
                        color: root.amberA(0.8)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
            Text {
                text: Qt.formatDateTime(clock.date, "ddd d MMM").toUpperCase()
                color: root.inkA(0.72)
                font.family: root.mono
                font.pixelSize: 14
                font.letterSpacing: 7
            }
        }

        // once a minute: taillights dash under the date, right and gone.
        // x lands on an 8px grid — the car moves in pixel steps.
        Item {
            id: streak
            property real t: -1
            visible: t >= 0
            y: 132
            x: Math.round((digitRow.width + 40) * Math.max(0, t) / 8) * 8 - 20
            Rectangle { x: 0; width: 5; height: 5; color: root.tail }
            Rectangle { x: 8; width: 5; height: 5; color: root.tail }
            Rectangle { x: -7; width: 4; height: 5; color: root.amberA(0.35) }   // exhaust ember
            NumberAnimation {
                id: streakAnim
                target: streak; property: "t"
                from: 0; to: 1; duration: 900
                onStopped: streak.t = -1
            }
        }
        Connections {
            target: clock
            function onDateChanged() { if (!root.occluded && sign.opacity === 1) streakAnim.restart() }
        }
    }
}
