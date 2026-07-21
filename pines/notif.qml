import QtQuick

// pines: field messages. Notification cards are slips pinned to the cab
// glass: cold slate, a hairline frame, and down the left edge a bearing
// rail — a vertical hairline with degree ticks and a benchmark triangle at
// its head, inked in the urgency's tone. The shell keeps the daemon, stack,
// text and actions. The Super+I history drawer keeps the same rail grammar
// on the panel, with the lamp pip going ember while dnd is on and the entry
// count logged in the head rule.
Item {
    id: root
    required property var pal
    function silverA(a) { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function lampA(a)   { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }

    property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.92)
    property color cardBorder: silverA(0.30)
    property int cardRadius: 4
    property int cardBorderWidth: 1
    property bool cardSpine: false   // the bearing rail below replaces it

    // the history drawer (Super+I)
    property color panelBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.96)
    property color panelBorder: silverA(0.38)
    property int panelBorderWidth: 1
    property int panelRadius: 5
    property string panelTitle: "notifications"
    property Component panelBackdrop: Component {
        Item {
            id: logbook
            property var panel: null
            readonly property bool shuttered: panel ? panel.dnd === true : false

            // head rule + the lamp pip (ember while dnd is on)
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
                height: 1
                color: logbook.shuttered ? root.pal.magenta : root.lampA(0.7)
                opacity: 0.8
            }
            Rectangle {
                id: logLamp
                anchors { top: parent.top; right: parent.right; topMargin: 13; rightMargin: 14 }
                width: 6; height: 6; radius: 3
                color: logbook.shuttered ? root.pal.magenta : root.pal.neon
                SequentialAnimation on opacity {
                    running: logbook.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.4; duration: 1400; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                }
            }
            Text {
                anchors { top: parent.top; right: parent.right; topMargin: 10; rightMargin: 26 }
                text: (logbook.shuttered ? "dnd · " : "")
                    + String(logbook.panel ? logbook.panel.count : 0).padStart(2, "0") + " entries"
                font.family: root.pal.fontMono
                font.pixelSize: 10
                font.letterSpacing: 2
                color: logbook.shuttered ? root.pal.magenta : root.silverA(0.8)
            }

            // corner ticks, lamp-warm
            Item {
                x: 0; y: 0; width: 11; height: 11
                Rectangle { width: parent.width; height: 1.4; color: root.lampA(0.55) }
                Rectangle { width: 1.4; height: parent.height; color: root.lampA(0.55) }
            }
            Item {
                x: parent.width - 11; y: parent.height - 11
                width: 11; height: 11
                Rectangle { y: parent.height - 1.4; width: parent.width; height: 1.4; color: root.lampA(0.55) }
                Rectangle { x: parent.width - 1.4; width: 1.4; height: parent.height; color: root.lampA(0.55) }
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: slip
            property var note: null   // injected by the shell: the card delegate
            readonly property color tone: note ? note.accentCol : root.pal.neon
            readonly property real lit: note && note.hovered ? 1 : 0.65

            // the bearing rail down the left edge
            Item {
                id: rail
                width: 14
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 5; bottomMargin: 5; leftMargin: 5 }
                opacity: slip.lit
                Behavior on opacity { NumberAnimation { duration: 150 } }

                // the benchmark at the rail's head
                Canvas {
                    id: bm
                    x: 0; y: 0
                    width: 11; height: 9
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.strokeStyle = String(slip.tone)
                        ctx.lineWidth = 1.2
                        ctx.beginPath()
                        ctx.moveTo(width / 2, 1)
                        ctx.lineTo(width - 1, height - 1)
                        ctx.lineTo(1, height - 1)
                        ctx.closePath()
                        ctx.stroke()
                        ctx.fillStyle = String(slip.tone)
                        ctx.fillRect(width / 2 - 1, height * 0.5, 2, 2)
                    }
                    Connections {
                        target: slip
                        function onToneChanged() { bm.requestPaint() }
                    }
                    Component.onCompleted: requestPaint()
                }
                // the hairline, hanging from the benchmark
                Rectangle {
                    x: 5; y: 11
                    width: 1
                    height: Math.max(0, rail.height - 13)
                    color: Qt.rgba(slip.tone.r, slip.tone.g, slip.tone.b, 0.6)
                }
                // degree ticks — tolerant of short history rows
                Repeater {
                    model: Math.max(0, Math.floor((rail.height - 16) / 9))
                    Rectangle {
                        required property int index
                        x: 5; y: 14 + index * 9
                        width: index % 3 === 0 ? 5 : 3
                        height: 1
                        color: Qt.rgba(slip.tone.r, slip.tone.g, slip.tone.b, index % 3 === 0 ? 0.65 : 0.4)
                    }
                }
            }

            // one lamp-warm tick on the far corner
            Item {
                x: parent.width - 10; y: parent.height - 10
                width: 10; height: 10
                opacity: slip.lit * 0.8
                Rectangle { y: parent.height - 1.2; width: parent.width; height: 1.2; color: root.lampA(0.6) }
                Rectangle { x: parent.width - 1.2; width: 1.2; height: parent.height; color: root.lampA(0.6) }
            }
        }
    }
}
