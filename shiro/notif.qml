import QtQuick

// shiro: washi-paper notification chrome. Near-white paper with an ink
// hairline and crisp corners, a tapered brush stroke down the left edge in
// the urgency color, and a faint blush seal stamped in the bottom-right.
// The shell keeps the daemon/stack/text; this only dresses the card.
Item {
    id: root
    required property var pal

    function toWhite(c, t) {
        return Qt.rgba(c.r + (1 - c.r) * t, c.g + (1 - c.g) * t, c.b + (1 - c.b) * t, 1)
    }
    readonly property color paper: toWhite(pal.glass, 0.65)

    property color cardBg: Qt.rgba(paper.r, paper.g, paper.b, 0.96)
    property color cardBorder: Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.16)
    property int cardBorderWidth: 1
    property int cardRadius: 5
    property bool cardSpine: false   // the brush stroke below replaces it

    // notification center: a taller sheet of the same washi — binding thread
    // stitched down the left margin, one big hanko pressed at the foot
    property color panelBg: Qt.rgba(paper.r, paper.g, paper.b, 0.97)
    property color panelBorder: Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.20)
    property int panelBorderWidth: 1
    property int panelRadius: 5
    property string panelTitle: "Letters"
    property Component panelBackdrop: Component {
        Item {
            property var panel: null

            Column {
                anchors { top: parent.top; bottom: parent.bottom; left: parent.left; leftMargin: 6; topMargin: 16; bottomMargin: 16 }
                spacing: 14
                Repeater {
                    model: Math.max(0, Math.floor((parent.height + 14) / 22))
                    Rectangle {
                        width: 2; height: 8; radius: 1
                        color: Qt.rgba(root.pal.text.r, root.pal.text.g, root.pal.text.b, 0.18)
                    }
                }
            }

            Rectangle {
                anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
                width: 15; height: 15; radius: 3
                color: "transparent"
                border.width: 1
                border.color: root.pal.cyan
                opacity: 0.4
                Rectangle { anchors.centerIn: parent; width: 5; height: 5; radius: 1; color: root.pal.cyan }
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: chassis
            property var note: null   // injected by the shell: the card delegate

            // tapered brush stroke down the left edge, urgency-tinted
            Canvas {
                id: stroke
                width: 12
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 5 }
                readonly property color tint: chassis.note ? chassis.note.accentCol : root.pal.neon
                onTintChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const h = height
                    if (h <= 0) return
                    ctx.beginPath()
                    ctx.moveTo(2, 0)
                    // pressure fades toward the bottom, with a slight hand waver
                    for (let y = 0; y <= h; y += 4) {
                        const t = Math.min(1, y / h)
                        const w = 1.0 + 3.8 * Math.pow(1 - t, 1.4) + Math.sin(t * 8 + 1) * 0.5
                        ctx.lineTo(2 + Math.max(0.8, w), y)
                    }
                    ctx.lineTo(2, h)
                    ctx.closePath()
                    ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.85)
                    ctx.fill()
                    // the flick where the brush landed
                    ctx.beginPath()
                    ctx.arc(9.5, 5, 1.4, 0, Math.PI * 2)
                    ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.5)
                    ctx.fill()
                }
            }

            // faint blush seal, like a hanko stamp on the paper
            Rectangle {
                anchors { right: parent.right; bottom: parent.bottom; margins: 7 }
                width: 9; height: 9; radius: 2
                color: "transparent"
                border.width: 1
                border.color: root.pal.cyan
                opacity: 0.35

                Rectangle {
                    anchors.centerIn: parent
                    width: 3; height: 3; radius: 1
                    color: root.pal.cyan
                }
            }
        }
    }
}
