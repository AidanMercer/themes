import QtQuick
import Quickshell

// gunsmoke: the ledger entry, written into the fog of the upper-left where
// the wallpaper has only murk. A page heading — "№ 1887 · THE BOUNTY LEDGER"
// — then the time in big stamped serif capitals. Digits don't fade or roll:
// they are STAMPED (hammer law) — the new digit slams down with a one-frame
// bone flash and a wisp of powder smoke curls off the strike and dissipates
// (smoke law). The colon is two bullet holes, still. Below the double ledger
// rule, the date as an entry line and the hour counted in gate-tally strokes
// (groups of five, fifth slashed) — the theme's tally renderer.
// Click-through scenery; everything stops while occluded.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while locked or a fullscreen window covers the monitor
    property bool occluded: false

    readonly property color bone: pal.neon
    readonly property color steel: pal.cyan
    readonly property color blood: pal.magenta
    readonly property color ash: pal.dim
    readonly property color ink: pal.text
    readonly property string serif: "Noto Serif"
    readonly property string mono: pal.fontMono
    function boneA(a)  { return Qt.rgba(bone.r, bone.g, bone.b, a) }
    function steelA(a) { return Qt.rgba(steel.r, steel.g, steel.b, a) }
    function ashA(a)   { return Qt.rgba(ash.r, ash.g, ash.b, a) }
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // ── powder smoke: three motes rise, grow, thin out — the shared one-shot ──
    component SmokePuff: Item {
        id: puff
        property real t: -1                  // -1 parked, 0..1 playing
        visible: t >= 0
        function fire() { anim.restart() }
        readonly property real tt: Math.max(0, t)
        Repeater {
            model: 3
            Rectangle {
                required property int index
                readonly property real ph: index * 0.33
                x: (index - 1) * 7 + Math.sin((puff.tt + ph) * 6.2) * 4
                y: -puff.tt * (26 + index * 9)
                width: (5 + index * 2) * (1 + puff.tt * 1.6)
                height: width
                radius: width / 2
                color: root.boneA(0.22 * (1 - puff.tt))
            }
        }
        NumberAnimation {
            id: anim
            target: puff; property: "t"
            from: 0; to: 1; duration: 950; easing.type: Easing.OutQuad
            onStopped: puff.t = -1
        }
    }

    // ── a stamped digit: hammer in, smoke off the strike ────────────────────
    component StampDigit: Item {
        id: sd
        property string target: " "
        property real px: 96
        width: dtxt.implicitWidth
        height: dtxt.implicitHeight

        Text {
            id: dtxt
            text: sd.target
            color: root.boneA(0.92)
            font.family: root.serif
            font.pixelSize: sd.px
            font.weight: Font.Black
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.55)
        }
        // one-frame bone flash over the strike
        Rectangle {
            id: flash
            anchors.fill: dtxt
            anchors.margins: -4
            color: root.boneA(0.5)
            opacity: 0
        }
        SmokePuff {
            id: smoke
            x: sd.width * 0.5
            y: sd.height * 0.18
        }
        SequentialAnimation {
            id: stamp
            ParallelAnimation {
                NumberAnimation { target: dtxt; property: "scale"; from: 1.28; to: 1; duration: 80; easing.type: Easing.OutQuad }
                SequentialAnimation {
                    PropertyAction { target: flash; property: "opacity"; value: 0.55 }
                    PauseAnimation { duration: 45 }
                    PropertyAction { target: flash; property: "opacity"; value: 0 }
                }
            }
        }
        onTargetChanged: if (!root.occluded && root.visible) { stamp.restart(); smoke.fire() }
    }

    // ── the entry, parked in the upper-left murk ───────────────────────────
    Item {
        id: page
        x: Math.round(root.width * 0.065)
        y: Math.round(root.height * 0.09)
        scale: pal.uiScale
        transformOrigin: Item.TopLeft
        width: col.width
        height: col.height

        // boot: the page blooms out of the fog — up-drift + fade, smoke law
        opacity: 0
        property real rise: 10
        ParallelAnimation {
            running: true
            NumberAnimation { target: page; property: "opacity"; to: 1; duration: 900; easing.type: Easing.OutQuad }
            NumberAnimation { target: page; property: "rise"; to: 0; duration: 900; easing.type: Easing.OutQuad }
        }
        transform: Translate { y: page.rise }

        Column {
            id: col
            spacing: 10

            // page heading
            Row {
                spacing: 12
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "№ 1887"
                    color: root.ashA(1)
                    font.family: root.serif
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 2
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46; height: 1
                    color: root.ashA(0.8)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "THE BOUNTY LEDGER"
                    color: root.boneA(0.5)
                    font.family: root.serif
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 7
                }
            }

            // the time, stamped
            Row {
                id: digitRow
                spacing: 6
                StampDigit { target: root.hhmm.charAt(0) }
                StampDigit { target: root.hhmm.charAt(1) }
                // the colon: two bullet holes, still
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 22
                    Repeater {
                        model: 2
                        Rectangle {
                            width: 11; height: 11; radius: 5.5
                            color: Qt.rgba(0.02, 0.03, 0.04, 0.85)
                            border.width: 2
                            border.color: root.boneA(0.55)
                        }
                    }
                }
                StampDigit { target: root.hhmm.charAt(3) }
                StampDigit { target: root.hhmm.charAt(4) }
            }

            // double ledger rule
            Column {
                spacing: 3
                Rectangle { width: digitRow.width; height: 2; color: root.boneA(0.45) }
                Rectangle { width: digitRow.width; height: 1; color: root.boneA(0.18) }
            }

            // the entry line
            Text {
                text: "ENTRY · " + Qt.formatDateTime(clock.date, "ddd d MMM yyyy").toUpperCase()
                color: root.inkA(0.7)
                font.family: root.serif
                font.pixelSize: 15
                font.weight: Font.Bold
                font.letterSpacing: 5
            }

            // the hour, counted in gate tallies — groups of five, fifth slashed
            Row {
                spacing: 12
                Canvas {
                    id: tally
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property int count: {
                        const h = clock.date.getHours() % 12
                        return h === 0 ? 12 : h
                    }
                    width: 150; height: 20
                    onCountChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                    Connections {
                        target: root.pal
                        function onNeonChanged() { tally.requestPaint() }
                    }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.strokeStyle = String(root.boneA(0.7))
                        ctx.lineWidth = 2
                        ctx.lineCap = "round"
                        const n = tally.count
                        let x = 2
                        for (let i = 0; i < n; i++) {
                            const grp = Math.floor(i / 5), pos = i % 5
                            if (pos < 4) {
                                const gx = 2 + grp * 34 + pos * 6
                                // hand-set: each stroke leans a touch differently
                                const lean = ((i * 7) % 3) - 1
                                ctx.beginPath()
                                ctx.moveTo(gx + lean, 3)
                                ctx.lineTo(gx - lean, 17)
                                ctx.stroke()
                            } else {
                                // the fifth: slashed across the four
                                const gx = 2 + grp * 34
                                ctx.beginPath()
                                ctx.moveTo(gx - 3, 15)
                                ctx.lineTo(gx + 21, 5)
                                ctx.stroke()
                            }
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "HOURS ON THE HUNT"
                    color: root.ashA(0.9)
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 3
                }
            }
        }
    }
}
