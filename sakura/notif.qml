import QtQuick

// sakura: notification chrome. Each card is a petal that drifted onto the
// desk — dusk-plum paper, a single notched petal pressed in the top-right
// corner tinted by urgency, and a thin stem line down the left edge in place
// of the default spine. The notification center is the branch ledger: cords
// stitched down the margin, a full blossom pressed at the foot, quiet hours
// close it to a bud.
Item {
    id: root
    required property var pal

    readonly property color cream: pal.text
    readonly property color pink:  pal.neon
    readonly property color plum:  pal.glass
    function creamA(a) { return Qt.rgba(cream.r, cream.g, cream.b, a) }
    function pinkA(a)  { return Qt.rgba(pink.r, pink.g, pink.b, a) }
    function twigA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    property color cardBg: Qt.rgba(plum.r, plum.g, plum.b, 0.94)
    property color cardBorder: pinkA(0.30)
    property int cardBorderWidth: 1
    property int cardRadius: 12
    property bool cardSpine: false   // the stem below replaces it

    // shared painter — bud 0 → bloom 1
    function drawBlossom(ctx, r, bloom, fillCol, coreCol) {
        if (bloom < 0.1) {
            ctx.beginPath()
            ctx.arc(0, 0, Math.max(1, r * 0.30), 0, 2 * Math.PI)
            ctx.fillStyle = fillCol
            ctx.fill()
            return
        }
        const pr = r * (0.4 + 0.6 * bloom)
        const w = pr * 0.55 * (0.55 + 0.45 * bloom)
        for (let i = 0; i < 5; i++) {
            ctx.save()
            ctx.rotate(i * Math.PI * 2 / 5)
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.bezierCurveTo(-w, -pr * 0.35, -w * 0.9, -pr * 0.85, -pr * 0.16, -pr * 0.97)
            ctx.lineTo(0, -pr * 0.85)
            ctx.lineTo(pr * 0.16, -pr * 0.97)
            ctx.bezierCurveTo(w * 0.9, -pr * 0.85, w, -pr * 0.35, 0, 0)
            ctx.closePath()
            ctx.fillStyle = fillCol
            ctx.fill()
            ctx.restore()
        }
        ctx.beginPath()
        ctx.arc(0, 0, Math.max(0.8, r * 0.14), 0, 2 * Math.PI)
        ctx.fillStyle = coreCol
        ctx.fill()
    }

    property Component backdrop: Component {
        Item {
            id: chassis
            property var note: null   // injected by the shell: the card delegate

            // stem line down the left edge, urgency-tinted
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 6; topMargin: 8; bottomMargin: 8 }
                width: 2
                radius: 1
                color: chassis.note ? Qt.alpha(chassis.note.accentCol, 0.8) : root.pinkA(0.8)
            }

            // the pressed petal, top-right — tinted by urgency
            Canvas {
                id: pressed
                anchors { right: parent.right; top: parent.top; margins: 8 }
                width: 16; height: 16
                readonly property color tint: chassis.note ? chassis.note.accentCol : root.pink
                onTintChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const r = 7
                    ctx.translate(width / 2, height / 2)
                    ctx.rotate(0.6)
                    ctx.beginPath()
                    ctx.moveTo(0, r * 0.5)
                    ctx.bezierCurveTo(-r * 0.8, 0, -r * 0.6, -r * 0.8, -r * 0.14, -r * 0.9)
                    ctx.lineTo(0, -r * 0.76)
                    ctx.lineTo(r * 0.14, -r * 0.9)
                    ctx.bezierCurveTo(r * 0.6, -r * 0.8, r * 0.8, 0, 0, r * 0.5)
                    ctx.closePath()
                    ctx.fillStyle = String(Qt.alpha(pressed.tint, 0.55))
                    ctx.fill()
                }
                Component.onCompleted: requestPaint()
            }
        }
    }

    // ── the notification center (Super+I) ───────────────────────────────────
    property color panelBg: Qt.rgba(plum.r, plum.g, plum.b, 0.95)
    property color panelBorder: pinkA(0.32)
    property int panelBorderWidth: 1
    property int panelRadius: 14
    property string panelTitle: "petals drifted in"
    property Component panelBackdrop: Component {
        Item {
            property var panel: null

            // cord stitched down the left margin
            Column {
                anchors { top: parent.top; bottom: parent.bottom; left: parent.left; leftMargin: 7; topMargin: 18; bottomMargin: 18 }
                spacing: 12
                Repeater {
                    model: Math.max(0, Math.floor((parent.height + 12) / 20))
                    Rectangle {
                        width: 1.5; height: 8; radius: 1
                        color: root.twigA(0.7)
                    }
                }
            }

            // the blossom at the foot: open when listening, a bud in quiet hours
            Canvas {
                id: footBlossom
                anchors { right: parent.right; bottom: parent.bottom; margins: 12 }
                width: 20; height: 20
                readonly property bool dnd: parent.panel ? parent.panel.dnd === true : false
                onDndChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.translate(width / 2, height / 2)
                    root.drawBlossom(ctx, 9, footBlossom.dnd ? 0 : 1,
                                     String(root.pinkA(footBlossom.dnd ? 0.5 : 0.85)),
                                     String(root.creamA(0.85)))
                }
                Component.onCompleted: requestPaint()
                Connections {
                    target: root.pal
                    function onNeonChanged() { footBlossom.requestPaint() }
                }
            }
        }
    }
}
