import QtQuick

// sleeper: notes slid under the compartment door. Each card is a folded paper
// note that came in through the door gap: linen-tinted glass with a shadow
// band along the top edge (the dark of the corridor under the door), a wax
// seal in the urgency color, and a folded corner bottom-right. Hover and the
// corridor light catches the seal. The shell keeps the daemon, stacking,
// text and actions; this only dresses the card.
Item {
    id: root
    required property var pal

    function linenA(a) { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function teaA(a)   { return Qt.rgba(pal.amber.r, pal.amber.g, pal.amber.b, a) }
    function woodA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    property color cardBg: Qt.rgba(pal.glass.r * 0.85 + pal.text.r * 0.06,
                                   pal.glass.g * 0.85 + pal.text.g * 0.06,
                                   pal.glass.b * 0.85 + pal.text.b * 0.06, 0.95)
    property color cardBorder: linenA(0.35)
    property int cardBorderWidth: 1
    property int cardRadius: 3      // paper, near-square
    property bool cardSpine: false  // the wax seal below replaces it

    // notification center: what was left at the door overnight — with the
    // do-not-disturb hanger out while quiet hours hold
    property color panelBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.96)
    property color panelBorder: teaA(0.4)
    property int panelBorderWidth: 1
    property int panelRadius: 5
    property string panelTitle: "notifications"
    property Component panelBackdrop: Component {
        Item {
            id: doorLog
            property var panel: null
            readonly property bool quiet: panel ? panel.dnd : false

            // the door gap: a dark rail along the top with corridor light behind it
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
                height: 7
                radius: 4
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.5) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Rectangle {   // corridor lamplight leaking through the gap
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1; leftMargin: 10; rightMargin: 10 }
                height: 2
                opacity: doorLog.quiet ? 0.15 : 0.5
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.teaA(0.0) }
                    GradientStop { position: 0.5; color: root.teaA(0.8) }
                    GradientStop { position: 1.0; color: root.teaA(0.0) }
                }
            }

            // the do-not-disturb hanger, out only during quiet hours
            Item {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 14
                anchors.topMargin: 8
                width: dndText.implicitWidth + 16; height: 30
                visible: doorLog.quiet
                rotation: -3
                Rectangle {   // its string loop
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -3
                    width: 8; height: 8; radius: 4
                    color: "transparent"
                    border.width: 1
                    border.color: root.teaA(0.6)
                }
                Rectangle {   // the tag
                    anchors.fill: parent
                    anchors.topMargin: 4
                    radius: 2
                    color: Qt.rgba(root.pal.text.r, root.pal.text.g, root.pal.text.b, 0.10)
                    border.width: 1
                    border.color: root.teaA(0.5)
                    Text {
                        id: dndText
                        anchors.centerIn: parent
                        text: "do not disturb"
                        font.family: root.pal.fontMono
                        font.pixelSize: 10
                        color: root.teaA(0.9)
                    }
                }
            }

            // a small crescent at the foot
            Text {
                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 14; bottomMargin: 8 }
                text: "☾"
                font.pixelSize: 10
                color: Qt.alpha(root.pal.cyan, doorLog.quiet ? 0.35 : 0.7)
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: paper
            property var note: null   // injected by the shell: the card delegate
            readonly property color tint: note ? note.accentCol : root.pal.amber
            function tintA(a) { return Qt.rgba(tint.r, tint.g, tint.b, a) }

            // the door-gap shadow along the top edge — the note just came in
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
                height: Math.min(16, parent.height * 0.3)
                radius: root.cardRadius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.32) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // urgency-tinted edge, warmer under the pointer
            Rectangle {
                anchors.fill: parent
                radius: root.cardRadius
                color: "transparent"
                border.width: 1
                border.color: paper.tintA(paper.note && paper.note.hovered ? 0.8 : 0.4)
                Behavior on border.color { ColorAnimation { duration: 180 } }
            }

            // the wax seal, top-left
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 10
                anchors.topMargin: 10
                width: 9; height: 9; radius: 4.5
                color: paper.tint
                Rectangle {   // the seal's pressed ring
                    anchors.centerIn: parent
                    width: 5; height: 5; radius: 2.5
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.35)
                }
            }
            // faint ruled lines — it's a written note
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 26
                anchors.rightMargin: 12
                anchors.topMargin: 26
                spacing: 9
                Repeater {
                    model: Math.max(1, Math.floor((paper.height - 34) / 12))
                    Rectangle { width: parent.width; height: 1; color: root.linenA(0.07) }
                }
            }

            // the folded corner, bottom-right
            Canvas {
                id: fold
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 14; height: 14
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.beginPath()
                    ctx.moveTo(width, 0)
                    ctx.lineTo(width, height)
                    ctx.lineTo(0, height)
                    ctx.closePath()
                    ctx.fillStyle = String(Qt.rgba(0, 0, 0, 0.35))
                    ctx.fill()
                    ctx.beginPath()
                    ctx.moveTo(width, 0)
                    ctx.lineTo(0, height)
                    ctx.strokeStyle = String(root.linenA(0.3))
                    ctx.lineWidth = 1
                    ctx.stroke()
                }
                Component.onCompleted: requestPaint()
                Connections {
                    target: root.pal
                    function onTextChanged() { fold.requestPaint() }
                }
            }
        }
    }
}
