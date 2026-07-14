import QtQuick

// avalon: notification chrome — moss glass with a gold hairline, a flower
// stem down the left edge in the urgency color, and a small gold diamond
// seal. The shell keeps the daemon/stack/text; this only dresses the card.
Item {
    id: root
    required property var pal

    function goldA(a) { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }

    property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.92)
    property color cardBorder: goldA(0.30)
    property int cardBorderWidth: 1
    property int cardRadius: 12
    property bool cardSpine: false   // the stem below replaces it

    // notification center: moss glass sheet with a gold inner hairline and a
    // scatter of petals drifting from the top-right corner
    property color panelBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.94)
    property color panelBorder: goldA(0.35)
    property int panelBorderWidth: 1
    property int panelRadius: 14
    property string panelTitle: "Missives"
    property Component panelBackdrop: Component {
        Item {
            property var panel: null

            Rectangle {
                anchors.fill: parent
                anchors.margins: 5
                radius: 10
                color: "transparent"
                border.width: 1
                border.color: root.goldA(0.16)
            }

            // petals settled near the top-right, out of the header's way
            Repeater {
                model: [
                    { px: 0.86, py: 0.055, r: 35,  s: 1.0,  o: 0.50 },
                    { px: 0.93, py: 0.085, r: 120, s: 0.75, o: 0.38 },
                    { px: 0.80, py: 0.100, r: 210, s: 0.6,  o: 0.28 }
                ]
                Rectangle {
                    required property var modelData
                    x: parent.width * modelData.px
                    y: parent.height * modelData.py
                    width: 9 * modelData.s; height: 5 * modelData.s
                    radius: height / 2
                    rotation: modelData.r
                    color: root.pal.neon
                    opacity: modelData.o
                }
            }

            // gold diamond seal at the foot, echoing the cards
            Rectangle {
                anchors { right: parent.right; bottom: parent.bottom; margins: 11 }
                width: 8; height: 8
                rotation: 45
                color: "transparent"
                border.width: 1
                border.color: root.pal.cyan
                opacity: 0.45
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: chassis
            property var note: null   // injected by the shell: the card delegate

            // stem down the left edge, a blossom at its head, urgency-tinted
            Canvas {
                id: stem
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
                    ctx.lineWidth = 1.4
                    ctx.beginPath()
                    ctx.moveTo(8, 14)
                    // the stem sways very slightly on its way down
                    for (let y = 14; y <= h; y += 4)
                        ctx.lineTo(8 + Math.sin(y * 0.045) * 1.6, y)
                    ctx.stroke()
                    // five-petal head (no ellipse() in qml canvas — scaled arcs)
                    ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.85)
                    for (let i = 0; i < 5; i++) {
                        const a = -Math.PI / 2 + i * Math.PI * 2 / 5
                        ctx.save()
                        ctx.translate(8 + Math.cos(a) * 3.4, 8 + Math.sin(a) * 3.4)
                        ctx.rotate(a + Math.PI / 2)
                        ctx.scale(1.7, 2.6)
                        ctx.beginPath()
                        ctx.arc(0, 0, 1, 0, Math.PI * 2)
                        ctx.restore()
                        ctx.fill()
                    }
                    ctx.beginPath()
                    ctx.arc(8, 8, 1.6, 0, Math.PI * 2)
                    ctx.fillStyle = root.goldA(0.95)
                    ctx.fill()
                }
            }

            // gold diamond seal, bottom-right
            Rectangle {
                anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
                width: 7; height: 7
                rotation: 45
                color: "transparent"
                border.width: 1
                border.color: root.pal.cyan
                opacity: 0.45
            }
        }
    }
}
