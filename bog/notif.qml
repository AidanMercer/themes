import QtQuick

// bog: notifications land like pebbles dropped into the pond. Each card is a
// pebble come to rest — soft-cornered murk glass with a cork float lamp in
// the urgency color riding a short waterline on the left rail, and one set
// of ripple rings that spreads across the card the moment it arrives (the
// pond acknowledging the drop). Hover and the float sits up a little. The
// shell keeps the daemon, stacking, text and actions; this only dresses the
// card. The notification center is "the pond remembers": a waterline under
// its header, the raft resting at the foot, and under do-not-disturb the
// whole pond goes to sleep.
Item {
    id: root
    required property var pal

    function strawA(a) { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function sunA(a)   { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function mossA(a)  { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function reedA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.93)
    property color cardBorder: mossA(0.4)
    property int cardBorderWidth: 1
    property int cardRadius: 14      // pebble-smooth, nothing sharp in this pond
    property bool cardSpine: false   // the float on the waterline replaces it

    // notification center: the pond remembers
    property color panelBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.96)
    property color panelBorder: mossA(0.45)
    property int panelBorderWidth: 1
    property int panelRadius: 16
    property string panelTitle: "the pond remembers"
    property Component panelBackdrop: Component {
        Item {
            id: pond
            property var panel: null
            readonly property bool asleep: panel ? panel.dnd : false

            // the waterline under the header
            Rectangle {
                x: 14; y: 44
                width: parent.width - 28
                height: 1
                color: root.reedA(0.5)
            }
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    x: 22 + index * ((pond.width - 50) / 4)
                    y: 43
                    width: index % 2 === 0 ? 16 : 8
                    height: 2
                    radius: 1
                    color: root.sunA(pond.asleep ? 0.08 : 0.25)
                }
            }
            // noon light pooling from the top — the pond dims under DND
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
                height: Math.min(50, parent.height * 0.2)
                radius: 15
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.sunA(pond.asleep ? 0.02 : 0.07) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // the raft resting at the foot of the log
            Item {
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 14; bottomMargin: 10 }
                width: 30; height: 20
                opacity: pond.asleep ? 0.25 : 0.5
                Rectangle { x: 2; y: 14; width: 24; height: 4; radius: 2; color: root.mossA(0.9) }
                Rectangle { x: 12; y: 2; width: 1.4; height: 12; color: root.reedA(1) }
                Rectangle { x: 13.5; y: 2; width: 9; height: 8; radius: 4; color: root.mossA(0.7) }
                Rectangle { x: 6; y: 10; width: 4; height: 4; radius: 2; color: root.mossA(1) }
                Rectangle { x: 19; y: 11; width: 4; height: 3; radius: 1.5; color: Qt.rgba(root.pal.amber.r, root.pal.amber.g, root.pal.amber.b, 0.9) }
            }
            Text {
                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 16; bottomMargin: 9 }
                visible: pond.asleep
                text: "the pond sleeps"
                font.family: "Noto Serif Display"
                font.italic: true
                font.pixelSize: 10
                color: root.reedA(1)
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: pebble
            property var note: null   // injected by the shell: the card delegate
            readonly property color tint: note ? note.accentCol : root.pal.neon
            function tintA(a) { return Qt.rgba(tint.r, tint.g, tint.b, a) }

            // the arrival: one set of rings spreads from the float and is gone
            Canvas {
                id: landing
                property real t: -1
                visible: t >= 0
                anchors.fill: parent
                onTChanged: requestPaint()
                NumberAnimation {
                    id: landAnim
                    target: landing; property: "t"
                    from: 0; to: 1; duration: 2000; easing.type: Easing.OutSine
                    onStopped: landing.t = -1
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (t < 0) return
                    const cx = 22, cy = height * 0.5
                    for (let k = 0; k < 3; k++) {
                        const tt = (t - k * 0.16) / (1 - k * 0.16)
                        if (tt <= 0 || tt >= 1) continue
                        const r = 6 + (width * 0.55) * tt
                        ctx.save()
                        ctx.translate(cx, cy)
                        ctx.scale(1, 0.35)
                        ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
                        ctx.restore()
                        ctx.strokeStyle = String(pebble.tintA(0.30 * (1 - tt)))
                        ctx.lineWidth = Math.max(0.8, 1.8 * (1 - tt))
                        ctx.stroke()
                    }
                }
            }
            Component.onCompleted: landAnim.restart()

            // urgency-tinted edge, a breath brighter under the pointer
            Rectangle {
                anchors.fill: parent
                radius: root.cardRadius
                color: "transparent"
                border.width: 1
                border.color: pebble.tintA(pebble.note && pebble.note.hovered ? 0.7 : 0.35)
                Behavior on border.color { ColorAnimation { duration: 400 } }
            }
            // light pooled along the top of the card
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: Math.min(28, parent.height * 0.45)
                radius: root.cardRadius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: pebble.tintA(0.08) }
                    GradientStop { position: 1.0; color: pebble.tintA(0.0) }
                }
            }

            // the left rail: a short waterline with the float riding it
            Rectangle {
                x: 8; y: parent.height * 0.5
                width: 26; height: 1
                color: root.reedA(0.5)
            }
            Item {
                id: lamp
                x: 16
                y: pebble.height * 0.5 - 9
                width: 8; height: 12
                // hover: the float sits up on the line
                property real lift: pebble.note && pebble.note.hovered ? -2 : 0
                Behavior on lift { NumberAnimation { duration: 400; easing.type: Easing.InOutSine } }
                transform: Translate { y: lamp.lift }
                Rectangle { x: 0; y: 0; width: 8; height: 5; radius: 2.5; color: pebble.tint }
                Rectangle { x: 1; y: 4.4; width: 6; height: 4.4; radius: 2.2; color: pebble.tintA(0.55) }
                // its ghost under the waterline
                Rectangle { x: 1.5; y: 10.5; width: 5; height: 2; radius: 1; color: pebble.tintA(0.25) }
            }
        }
    }
}
