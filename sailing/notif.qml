import QtQuick

// sailing: marconigram notification chrome — each card is a radio-message
// slip handed up from the wireless room. A slate slip with a dashed telegram
// frame, a morse spine down the left edge in the urgency color (replacing
// the default stripe), and a faint circular RECD stamp pressed into the
// bottom-right corner. The shell keeps the daemon/stack/text; this only
// dresses the card.
Item {
    id: root
    required property var pal

    readonly property color dusk:  pal.cyan
    readonly property color buoy:  pal.neon
    readonly property color slate: pal.dim
    readonly property color pale:  pal.text
    readonly property color glass: pal.glass
    function paleA(a)  { return Qt.rgba(pale.r, pale.g, pale.b, a) }
    function duskA(a)  { return Qt.rgba(dusk.r, dusk.g, dusk.b, a) }

    // the slip: a shade paler than the cabin wall, so it reads as paper
    // handed into a dark room without fighting the shell-owned text colors
    function lift(c, t) {
        return Qt.rgba(c.r + (pale.r - c.r) * t, c.g + (pale.g - c.g) * t, c.b + (pale.b - c.b) * t, 1)
    }
    readonly property color slip: lift(glass, 0.09)

    property color cardBg: Qt.rgba(slip.r, slip.g, slip.b, 0.95)
    property color cardBorder: paleA(0.20)
    property int cardBorderWidth: 1
    property int cardRadius: 6
    property bool cardSpine: false   // the morse spine below replaces it

    property Component backdrop: Component {
        Item {
            id: chassis
            property var note: null   // injected by the shell after load
            readonly property color tint: note ? note.accentCol : root.buoy

            // dashed telegram frame, inset from the card edge
            Canvas {
                id: frame
                anchors.fill: parent
                anchors.margins: 4
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: root.pal
                    function onCyanChanged() { frame.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = root.duskA(0.30)
                    ctx.lineWidth = 1
                    ctx.setLineDash([4, 3])
                    ctx.strokeRect(0.5, 0.5, width - 1, height - 1)
                }
            }

            // morse spine: · · — · down the left edge, urgency-tinted
            Column {
                anchors.left: parent.left
                anchors.leftMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    // dot dot dash dot dash — just enough to read as morse
                    model: [3, 3, 9, 3, 9]
                    Rectangle {
                        required property int modelData
                        width: 2.5
                        height: modelData
                        radius: 1
                        color: chassis.tint
                        opacity: 0.9
                    }
                }
            }

            // RECD stamp, pressed crooked into the corner
            Item {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                width: 30; height: 30
                rotation: -14
                opacity: 0.32

                Rectangle {
                    anchors.fill: parent
                    radius: 15
                    color: "transparent"
                    border.width: 1.4
                    border.color: chassis.tint
                }
                Text {
                    anchors.centerIn: parent
                    text: "RECD"
                    color: chassis.tint
                    font.family: root.pal.fontMono
                    font.pixelSize: 7
                    font.letterSpacing: 1
                }
            }
        }
    }
}
