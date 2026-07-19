import QtQuick
import Quickshell

// encore: the CUE CLOCK — the venue clock hanging over the diva's side of the
// stage, parked in the dark of the hall top-right. Big mono digits under a
// small spotlight pool, a cue lamp ticking the internal count (hard on/off,
// quantized — law 1), and a count-in strip of eight lamp segments that steps
// once a second, one whole lamp at a time, like a bar of 8ths filling.
// When the minute turns the time takes a lighting cue: blackout cut, then
// iris back up from the light (law 2 — nothing fades, it's re-lit).
// Click-through scenery; the whole rig rests while occluded (law 3).
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while locked or a fullscreen window covers the monitor
    property bool occluded: false

    readonly property color teal: pal.neon        // the diva
    readonly property color lacquer: pal.cyan     // nail-lacquer blue
    readonly property color crowd: pal.magenta    // the crowd / alert
    readonly property color spot: pal.amber       // follow-spot warm white
    readonly property color rest: pal.dim         // resting lamps
    readonly property color ink: pal.text
    readonly property string mono: pal.fontMono
    function tealA(a)  { return Qt.rgba(teal.r, teal.g, teal.b, a) }
    function spotA(a)  { return Qt.rgba(spot.r, spot.g, spot.b, a) }
    function restA(a)  { return Qt.rgba(rest.r, rest.g, rest.b, a) }
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    // seconds drive the count-in strip; drop to minutes while occluded so a
    // locked desktop stops waking bindings every second
    SystemClock { id: clock; precision: root.occluded ? SystemClock.Minutes : SystemClock.Seconds }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")
    readonly property int sec: clock.date.getSeconds()

    // ── the ensemble, hung in the dark hall top-right ───────────────────────
    Item {
        id: rig
        x: Math.round(root.width * 0.965 - width)
        y: Math.round(root.height * 0.075)
        width: col.width
        height: col.height
        transformOrigin: Item.TopRight

        // boot: the clock is LIT — iris up from a point of light, once.
        // opacity snaps (a cut), the scale irises open (the beam widening).
        property real bootIris: 0.6
        opacity: 0
        scale: pal.uiScale * bootIris
        ParallelAnimation {
            running: true
            NumberAnimation { target: rig; property: "opacity"; from: 0; to: 1; duration: 90 }
            NumberAnimation { target: rig; property: "bootIris"; from: 0.6; to: 1; duration: 420; easing.type: Easing.OutBack }
        }

        // the spotlight pool behind the digits — one static radial paint.
        // (anchored to col, its sibling — timeCue is nested inside it)
        Canvas {
            id: pool
            anchors.centerIn: col
            anchors.verticalCenterOffset: -6
            width: col.width * 1.9
            height: col.height * 2.2
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const g = ctx.createRadialGradient(width / 2, height / 2, 0, width / 2, height / 2, width / 2)
                g.addColorStop(0, String(root.spotA(0.10)))
                g.addColorStop(0.55, String(root.spotA(0.035)))
                g.addColorStop(1, String(root.spotA(0)))
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, height)
            }
            Component.onCompleted: requestPaint()
            Connections {
                target: root.pal
                function onAmberChanged() { pool.requestPaint() }
            }
        }

        Column {
            id: col
            spacing: 12

            // header: cue lamp + the show's name
            Row {
                anchors.right: parent.right
                spacing: 9

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ENCORE · STAGE RIGHT"
                    color: root.inkA(0.5)
                    font.family: root.mono
                    font.pixelSize: 11
                    font.letterSpacing: 6
                }
                // the cue lamp: a hard metronome tick, ~120bpm feel at 500ms.
                // two-frame blink — lit, dark, lit. never a fade (law 1+2).
                Rectangle {
                    id: cueLamp
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8; height: 8; radius: 4
                    property bool tick: true
                    color: tick ? root.teal : root.restA(0.7)
                    Timer {
                        interval: 500; repeat: true
                        running: !root.occluded && root.visible
                        onTriggered: cueLamp.tick = !cueLamp.tick
                    }
                    onVisibleChanged: if (!visible) tick = true
                }
            }

            // the time — big, mono, the diva's teal. re-lit on the minute.
            Item {
                id: timeCue
                anchors.right: parent.right
                width: timeText.implicitWidth
                height: timeText.implicitHeight
                // the minute cue: blackout cut → iris back up
                property real irisT: 1
                opacity: irisT < 0.05 ? 0 : 1      // hard cut, no fade
                scale: 0.75 + 0.25 * irisT
                transformOrigin: Item.Center

                Text {
                    id: timeText
                    text: root.hhmm
                    color: root.teal
                    font.family: root.mono
                    font.pixelSize: 96
                    font.weight: Font.Black
                    font.letterSpacing: 4
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.55)
                }
                SequentialAnimation {
                    id: relight
                    // blackout…
                    NumberAnimation { target: timeCue; property: "irisT"; to: 0; duration: 0 }
                    PauseAnimation { duration: 90 }
                    // …and the spot snaps back open
                    NumberAnimation { target: timeCue; property: "irisT"; to: 1; duration: 320; easing.type: Easing.OutBack }
                }
            }
            Connections {
                target: root
                function onHhmmChanged() { if (!root.occluded && rig.opacity === 1) relight.restart() }
            }

            // the count-in: eight lamps, one lit per second, whole steps only.
            // beat 1 of the bar is the follow-spot's — warm white; the rest teal.
            Row {
                id: countRow
                anchors.right: parent.right
                spacing: 8
                Repeater {
                    model: 8
                    Rectangle {
                        required property int index
                        readonly property bool lit: index === (root.sec % 8)
                        width: 22; height: 5; radius: 2.5
                        color: lit ? (index === 0 ? root.spot : root.teal) : root.restA(0.45)
                        // no Behavior — the lamp changes are hard cuts
                    }
                }
            }

            // the tour date, printed like the cue sheet's header line
            Text {
                anchors.right: parent.right
                text: "ON STAGE · " + Qt.formatDateTime(clock.date, "ddd d MMM").toUpperCase()
                color: root.inkA(0.62)
                font.family: root.mono
                font.pixelSize: 13
                font.letterSpacing: 7
            }
        }
    }
}
