import QtQuick

// moon: HUD notification chrome. Black readout card with a cyan hairline,
// neon corner brackets, scanlines, and the clock's data-rail down the left
// edge tinted by urgency. The shell keeps the daemon/stack/text.
Item {
    id: root
    required property var pal

    property color cardBg: Qt.rgba(0.03, 0.03, 0.06, 0.92)
    property color cardBorder: Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, 0.35)
    property int cardRadius: 0
    property int cardBorderWidth: 1
    property bool cardSpine: false   // the data-rail below replaces it

    // notification center: the breach-deck log — darker slab, neon top rail
    // with a live tick, brackets on the panel corners, same scanline wash
    property color panelBg: Qt.rgba(0.02, 0.02, 0.045, 0.96)
    property color panelBorder: Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, 0.45)
    property int panelBorderWidth: 1
    property int panelRadius: 0
    property string panelTitle: "COMMS LOG"
    property Component panelBackdrop: Component {
        Item {
            id: deck
            property var panel: null
            readonly property color live: panel && panel.dnd ? root.pal.magenta : root.pal.neon

            // top rail: hairline + a pulsing status block (magenta when muted)
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 6 }
                height: 2
                color: deck.live
                opacity: 0.7
            }
            Rectangle {
                id: tick
                anchors { top: parent.top; right: parent.right; topMargin: 12; rightMargin: 14 }
                width: 6; height: 6
                color: deck.live
                SequentialAnimation on opacity {
                    // the shell keeps this backdrop loaded while the center is
                    // closed (the window just hides) — only blink when it shows
                    running: tick.Window.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.25; duration: 900 }
                    NumberAnimation { from: 0.25; to: 1; duration: 900 }
                }
            }

            Item {
                x: -1; y: -1
                width: 18; height: 18
                Rectangle { width: parent.width; height: 2; color: root.pal.neon }
                Rectangle { width: 2; height: parent.height; color: root.pal.neon }
            }
            Item {
                x: parent.width - 17; y: parent.height - 17
                width: 18; height: 18
                Rectangle { y: parent.height - 2; width: parent.width; height: 2; color: root.pal.neon }
                Rectangle { x: parent.width - 2; width: 2; height: parent.height; color: root.pal.neon }
            }

            Canvas {
                anchors.fill: parent
                opacity: 0.10
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = "#000000"
                    ctx.lineWidth = 1
                    for (let y = 0; y < height; y += 3) {
                        ctx.beginPath()
                        ctx.moveTo(0, y + 0.5)
                        ctx.lineTo(width, y + 0.5)
                        ctx.stroke()
                    }
                }
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: chassis
            property var note: null   // injected by the shell: the card delegate
            readonly property color tint: note ? note.accentCol : root.pal.neon
            readonly property real lit: note && note.hovered ? 1 : 0.55

            // data-rail: urgency run, magenta chunk, cyan tick
            Item {
                id: rail
                width: 10
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 6 }
                Rectangle { x: 4; width: 2; height: parent.height; color: root.pal.dim; opacity: 0.8 }
                Rectangle { x: 3; width: 4; height: parent.height * 0.44; color: chassis.tint }
                Rectangle { x: 3; y: parent.height * 0.52; width: 4; height: parent.height * 0.20; color: root.pal.magenta; opacity: 0.85 }
                Rectangle { x: 2; y: parent.height * 0.82; width: 6; height: 6; color: root.pal.cyan }
                Rectangle { x: 0; width: 10; height: 2; color: chassis.tint }
                Rectangle { x: 0; y: parent.height - 2; width: 10; height: 2; color: chassis.tint }
            }

            // brackets on opposite corners, brightening under the pointer
            Item {
                x: -1; y: -1
                width: 14; height: 14
                opacity: chassis.lit
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Rectangle { width: parent.width; height: 2; color: root.pal.neon }
                Rectangle { width: 2; height: parent.height; color: root.pal.neon }
            }
            Item {
                x: parent.width - 13; y: parent.height - 13
                width: 14; height: 14
                opacity: chassis.lit
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Rectangle { y: parent.height - 2; width: parent.width; height: 2; color: root.pal.neon }
                Rectangle { x: parent.width - 2; width: 2; height: parent.height; color: root.pal.neon }
            }

            // scanlines, one cheap paint per size
            Canvas {
                anchors.fill: parent
                opacity: 0.12
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = "#000000"
                    ctx.lineWidth = 1
                    for (let y = 0; y < height; y += 3) {
                        ctx.beginPath()
                        ctx.moveTo(0, y + 0.5)
                        ctx.lineTo(width, y + 0.5)
                        ctx.stroke()
                    }
                }
            }
        }
    }
}
