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

    // notification center: a night-glass stave board — carved top border of
    // twig runes, the north star holding the corner, frost creeping at the foot
    property color panelBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.95)
    property color panelBorder: iceA(0.34)
    property int panelBorderWidth: 1
    property int panelRadius: 12
    property string panelTitle: "Tidings"
    property Component panelBackdrop: Component {
        Item {
            property var panel: null

            // carved rune row along the top edge, under the header text
            Canvas {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 7 }
                height: 10
                opacity: 0.5
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = root.iceA(0.8)
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(0, 9.5)
                    ctx.lineTo(width, 9.5)
                    ctx.stroke()
                    let side = 1
                    for (let x = 10; x < width - 10; x += 16) {
                        ctx.beginPath()
                        ctx.moveTo(x, 9)
                        ctx.lineTo(x + side * 4, 2)
                        ctx.stroke()
                        side = -side
                    }
                }
            }

            // the north star, top-right corner
            Canvas {
                id: pole
                anchors { top: parent.top; right: parent.right; topMargin: 22; rightMargin: 14 }
                width: 13; height: 13
                opacity: 0.75
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
                    ctx.fillStyle = root.goldA(0.9)
                    ctx.fill()
                }
                Connections {
                    target: root.pal
                    function onCyanChanged() { pole.requestPaint() }
                }
            }

            // frost mist along the foot
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.height * 0.16
                radius: 12
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: root.iceA(0.10) }
                }
            }
        }
    }

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
