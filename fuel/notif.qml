import QtQuick

// fuel: receipt-printout notification chrome. Each card is a ticket torn off
// the pump's printer: perforated zigzag teeth across the top and bottom edges
// (drawn by the backdrop, so the card itself stays bare), a pump stripe band
// under the top perforation whose middle stripe takes the urgency color,
// faint platen feed-lines across the paper, and a tear-line + station stamp
// at the foot. The shell keeps the daemon/stack/text; this only dresses it.
Item {
    id: root
    required property var pal

    // the backdrop paints the whole ticket, teeth included
    property color cardBg: "transparent"
    property color cardBorder: "transparent"
    property int cardBorderWidth: 0
    property int cardRadius: 0
    property bool cardSpine: false   // the stripe band below replaces it

    function inkA(a) { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }

    // notification center: the pump's printer housing — dark casing with the
    // three-stripe livery under the header and a printer slot the tickets
    // hang out of; receipts (the cards) stack straight off the roll
    property color panelBg: Qt.rgba(0.05, 0.055, 0.07, 0.96)
    property color panelBorder: inkA(0.22)
    property int panelBorderWidth: 1
    property int panelRadius: 4
    property string panelTitle: "Notifications"
    property Component panelBackdrop: Component {
        Item {
            id: housing
            property var panel: null

            // livery stripes under the header, full width
            Column {
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 46; leftMargin: 6; rightMargin: 6 }
                spacing: 1
                Rectangle { width: parent.width; height: 1.5; color: root.pal.amber; opacity: 0.55 }
                Rectangle { width: parent.width; height: 2.5; color: root.pal.neon; opacity: 0.8 }
                Rectangle { width: parent.width; height: 1.5; color: root.pal.magenta; opacity: 0.40 }
            }

            // printer slot: a dark mouth with a highlight lip
            Rectangle {
                anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 41 }
                width: parent.width - 60
                height: 3
                radius: 1.5
                color: "#000000"
                opacity: 0.8
            }

            // pump badge at the foot
            Rectangle {
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 12; bottomMargin: 9 }
                width: 4; height: 4; rotation: 45
                color: root.pal.neon
                opacity: 0.7
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: chassis
            property var note: null   // injected by the shell: the card delegate
            readonly property color tint: chassis.note ? chassis.note.accentCol : root.pal.neon

            // the ticket body with zigzag perforations
            Canvas {
                id: paper
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: root.pal
                    function onTextChanged() { paper.requestPaint() }
                    function onDimChanged()  { paper.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    if (w <= 0 || h <= 0) return
                    const tooth = 9, th = 5
                    const nTeeth = Math.max(1, Math.floor(w / tooth))
                    const tw = w / nTeeth
                    // ticket silhouette: straight sides, toothed top + bottom
                    ctx.beginPath()
                    ctx.moveTo(0, th)
                    for (let i = 0; i < nTeeth; i++) {
                        ctx.lineTo(i * tw + tw / 2, 0)
                        ctx.lineTo((i + 1) * tw, th)
                    }
                    ctx.lineTo(w, h - th)
                    for (let i = nTeeth; i > 0; i--) {
                        ctx.lineTo(i * tw - tw / 2, h)
                        ctx.lineTo((i - 1) * tw, h - th)
                    }
                    ctx.closePath()
                    // thermal-paper dark: warm near-black
                    ctx.fillStyle = "rgba(13,15,18,0.96)"
                    ctx.fill()
                    // paper-white edge along the perforations
                    ctx.strokeStyle = Qt.rgba(root.pal.text.r, root.pal.text.g, root.pal.text.b, 0.30)
                    ctx.lineWidth = 1
                    ctx.stroke()
                    // faint platen feed-lines across the paper
                    ctx.strokeStyle = Qt.rgba(root.pal.text.r, root.pal.text.g, root.pal.text.b, 0.028)
                    for (let y = th + 8; y < h - th - 6; y += 5) {
                        ctx.beginPath(); ctx.moveTo(4, y); ctx.lineTo(w - 4, y); ctx.stroke()
                    }
                    // tear line above the foot (hand-dashed — Context2D has no setLineDash)
                    ctx.strokeStyle = Qt.rgba(root.pal.text.r, root.pal.text.g, root.pal.text.b, 0.16)
                    ctx.beginPath()
                    const ty = h - th - 4
                    for (let x = 6; x < w - 6; x += 7) {
                        ctx.moveTo(x, ty); ctx.lineTo(Math.min(x + 3, w - 6), ty)
                    }
                    ctx.stroke()
                }
            }

            // pump stripe band under the top perforation — urgency rides the core
            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 7
                anchors.leftMargin: 5
                anchors.rightMargin: 5
                spacing: 1
                Rectangle { width: parent.width; height: 1.5; color: root.pal.amber; opacity: 0.55 }
                Rectangle {
                    width: parent.width; height: 2.5
                    color: chassis.tint
                    opacity: chassis.note && chassis.note.hovered ? 1.0 : 0.85
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                Rectangle { width: parent.width; height: 1.5; color: root.pal.magenta; opacity: 0.40 }
            }

            // station stamp at the foot
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 10
                anchors.bottomMargin: 8
                width: 4; height: 4; rotation: 45
                color: chassis.tint
                opacity: 0.7
            }
        }
    }
}
