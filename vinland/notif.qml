import QtQuick

// vinland: notification chrome — night glass with an ice hairline, a carved
// rune-stave down the left edge in the urgency color (a vertical stave with
// twig-rune branches), and a small gold star seal. The shell keeps the
// daemon/stack/text; this only dresses the card.
Item {
    id: root
    required property var pal

    function iceA(a)  { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function goldA(a) { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }

    property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.93)
    property color cardBorder: iceA(0.28)
    property int cardBorderWidth: 1
    property int cardRadius: 10
    property bool cardSpine: false   // the stave below replaces it

    property Component backdrop: Component {
        Item {
            id: chassis
            property var note: null   // injected by the shell: the card delegate

            // a carved stave down the left edge, urgency-tinted: a straight
            // cut with small twig-rune branches leaning off it
            Canvas {
                id: stave
                width: 16
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 6 }
                readonly property color tint: chassis.note ? chassis.note.accentCol : root.pal.neon
                onTintChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const h = height
                    if (h <= 0) return
                    ctx.strokeStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.65)
                    ctx.lineWidth = 1.2
                    ctx.beginPath()
                    ctx.moveTo(8, 12)
                    ctx.lineTo(8, h - 2)
                    ctx.stroke()
                    // twig branches, alternating sides on the way down
                    ctx.lineWidth = 1
                    let side = 1
                    for (let y = 20; y < h - 8; y += 13) {
                        ctx.beginPath()
                        ctx.moveTo(8, y)
                        ctx.lineTo(8 + side * 5, y - 5)
                        ctx.stroke()
                        side = -side
                    }
                    // the north star at the stave's head
                    const c = 8, cy = 6, R = 5
                    ctx.beginPath()
                    ctx.moveTo(c, cy - R)
                    ctx.quadraticCurveTo(c, cy, c + R, cy)
                    ctx.quadraticCurveTo(c, cy, c, cy + R)
                    ctx.quadraticCurveTo(c, cy, c - R, cy)
                    ctx.quadraticCurveTo(c, cy, c, cy - R)
                    ctx.closePath()
                    ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.9)
                    ctx.fill()
                }
            }

            // gold star seal, bottom-right
            Canvas {
                id: seal
                anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
                width: 9; height: 9
                opacity: 0.5
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const c = width / 2, R = width / 2
                    ctx.beginPath()
                    ctx.moveTo(c, c - R)
                    ctx.quadraticCurveTo(c, c, c + R, c)
                    ctx.quadraticCurveTo(c, c, c, c + R)
                    ctx.quadraticCurveTo(c, c, c - R, c)
                    ctx.quadraticCurveTo(c, c, c, c - R)
                    ctx.closePath()
                    ctx.strokeStyle = root.goldA(0.95)
                    ctx.lineWidth = 1
                    ctx.stroke()
                }
                Connections {
                    target: root.pal
                    function onCyanChanged() { seal.requestPaint() }
                }
            }
        }
    }
}
