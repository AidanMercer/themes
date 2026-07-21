import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// sleeper: the brass plaque over the berth, screwed to the wood wall right of
// the window. A thin double frame with corner screws, a small crescent moon,
// the time in tall serif linen, then a perforated rule and the date.
// Digits change the paper way — the new figure SLIDES down into place and the
// old one slides out below, tucked, never faded. Once a minute a band of warm
// city light sweeps across the plaque (a lamp passing the window), and while
// music plays the whole plaque rocks on the bogie rhythm — the shared
// wall-time sway clock every sleeper widget phase-locks to. Idle = perfectly
// still. Click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while locked or a fullscreen window covers the monitor
    property bool occluded: false

    readonly property color green: pal.neon
    readonly property color moonpale: pal.cyan
    readonly property color stamp: pal.magenta
    readonly property color tea: pal.amber
    readonly property color wood: pal.dim
    readonly property color linen: pal.text
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    function linenA(a) { return Qt.rgba(linen.r, linen.g, linen.b, a) }
    function teaA(a)   { return Qt.rgba(tea.r, tea.g, tea.b, a) }
    function woodA(a)  { return Qt.rgba(wood.r, wood.g, wood.b, a) }
    function greenA(a) { return Qt.rgba(green.r, green.g, green.b, a) }
    function moonA(a)  { return Qt.rgba(moonpale.r, moonpale.g, moonpale.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // ── the bogie clock: phase from wall time, so every widget rocks in sync ──
    readonly property real swayPeriod: 4200
    property real swayPhase: 0
    readonly property bool trainMoving: {
        const ps = Mpris.players.values
        for (let i = 0; i < ps.length; i++)
            if (ps[i].playbackState === MprisPlaybackState.Playing) return true
        return false
    }
    property real swayAmp: (trainMoving && !occluded) ? 1 : 0
    Behavior on swayAmp { NumberAnimation { duration: 1400; easing.type: Easing.InOutSine } }
    Timer {
        interval: 50; repeat: true
        running: !root.occluded && (root.trainMoving || root.swayAmp > 0.01)
        onTriggered: root.swayPhase = ((Date.now() % root.swayPeriod) / root.swayPeriod) * 2 * Math.PI
    }
    readonly property real rock: Math.sin(swayPhase) * swayAmp          // roll, -1..1
    readonly property real heave: Math.sin(swayPhase * 2 + 0.7) * swayAmp

    // ── the plaque ──────────────────────────────────────────────────────────
    Item {
        id: plaque
        x: Math.round(root.width * 0.755)
        y: Math.round(root.height * 0.335) + root.heave * 1.6
        // laid out in unscaled units; the whole plaque shrinks via scale below
        width: 300
        height: col.implicitHeight + 44
        scale: root.pal.uiScale
        transformOrigin: Item.Top
        rotation: root.rock * 0.5

        // slide-in on boot: the plaque tucks down into place from above
        opacity: 0
        property real bootY: -14
        ParallelAnimation {
            running: true
            NumberAnimation { target: plaque; property: "opacity"; to: 1; duration: 700; easing.type: Easing.OutCubic }
            NumberAnimation { target: plaque; property: "bootY"; to: 0; duration: 700; easing.type: Easing.OutCubic }
        }
        transform: Translate { y: plaque.bootY }

        // plaque face: barely-there wood-glass so it reads on the lock blur too
        Rectangle {
            anchors.fill: parent
            radius: 3
            color: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.45)
            border.width: 1
            border.color: root.teaA(0.35)
        }
        // inner rule — the double frame of an engraved plate
        Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            radius: 2
            color: "transparent"
            border.width: 1
            border.color: root.woodA(0.7)
        }
        // corner screws
        Repeater {
            model: 4
            Rectangle {
                required property int index
                width: 4; height: 4; radius: 2
                x: index % 2 === 0 ? 8 : plaque.width - 12
                y: index < 2 ? 8 : plaque.height - 12
                color: root.teaA(0.55)
            }
        }

        Column {
            id: col
            anchors.horizontalCenter: parent.horizontalCenter
            y: 20
            spacing: 10

            // header: the crescent moon
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 9
                Canvas {
                    id: crescent
                    width: 14; height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.fillStyle = String(root.moonA(0.9))
                        ctx.beginPath()
                        ctx.arc(7, 7, 5.4, 0, 2 * Math.PI)
                        ctx.fill()
                        ctx.globalCompositeOperation = "destination-out"
                        ctx.beginPath()
                        ctx.arc(4.2, 5.8, 4.8, 0, 2 * Math.PI)
                        ctx.fill()
                    }
                    Component.onCompleted: requestPaint()
                    Connections {
                        target: root.pal
                        function onCyanChanged() { crescent.requestPaint() }
                    }
                    // the moon breathes, slowly, only while someone can see it
                    SequentialAnimation on opacity {
                        running: !root.occluded && root.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.5; duration: 3400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 3400; easing.type: Easing.InOutSine }
                    }
                }
            }

            // the time — tall serif, digits sliding like tucked paper
            Row {
                id: digitRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2
                Repeater {
                    model: 5
                    delegate: Item {
                        id: cell
                        required property int index
                        readonly property string target: root.hhmm.charAt(index)
                        readonly property bool colon: index === 2
                        width: colon ? Math.round(courNow.implicitWidth * 0.6) : courNow.implicitWidth
                        height: courNow.implicitHeight
                        clip: true

                        property string shown: " "
                        property string leaving: " "
                        onTargetChanged: { leaving = shown; shown = target; slide.restart() }
                        Component.onCompleted: { shown = target; leaving = " " }

                        // slide progress: 0 = old in place, 1 = new in place
                        property real t: 1
                        NumberAnimation {
                            id: slide
                            target: cell; property: "t"
                            from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic
                        }

                        Text {   // the figure leaving, sliding down and out
                            y: cell.t * cell.height
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.leaving
                            visible: cell.t < 1
                            color: root.linenA(0.9)
                            font.family: root.serif
                            font.pixelSize: 58
                            font.weight: Font.Light
                        }
                        Text {   // the figure arriving from above
                            id: courNow
                            y: (cell.t - 1) * cell.height
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.shown
                            color: cell.colon ? root.teaA(0.85) : root.linenA(0.92)
                            font.family: root.serif
                            font.pixelSize: 58
                            font.weight: Font.Light
                        }
                    }
                }
            }

            // perforation rule — the ticket edge
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Repeater {
                    model: 18
                    Rectangle {
                        width: 3; height: 3; radius: 1.5
                        color: root.teaA(0.45)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // the date line
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "ddd d MMM").toUpperCase()
                color: root.linenA(0.6)
                font.family: root.mono
                font.pixelSize: 11
                font.letterSpacing: 4
            }
        }

        // ── the passing lamp: once a minute, light crosses the plaque ───────
        Item {
            anchors.fill: parent
            clip: true
            Rectangle {
                id: lamp
                property real t: -1
                visible: t >= 0
                width: plaque.width * 0.45
                height: plaque.height * 1.6
                y: -plaque.height * 0.3
                x: -width + (plaque.width + width * 2) * Math.max(0, t)
                rotation: 14
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.teaA(0.0) }
                    GradientStop { position: 0.5; color: root.teaA(0.14) }
                    GradientStop { position: 1.0; color: root.teaA(0.0) }
                }
                NumberAnimation {
                    id: lampAnim
                    target: lamp; property: "t"
                    from: 0; to: 1; duration: 1600; easing.type: Easing.InOutSine
                    onStopped: lamp.t = -1
                }
            }
        }
        Connections {
            target: clock
            function onDateChanged() { if (!root.occluded && plaque.opacity === 1) lampAnim.restart() }
        }
    }
}
