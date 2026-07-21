import QtQuick

// stars: dispensed-item notification chrome. Each card is a little product
// just dropped from the machine: night glass with a warm glow edge tinted
// by urgency (amber / coral / signal red), a ticket stub down the left —
// perforation dots and one lit bottle-light in the urgency color — and a
// tiny star punched near the bottom-right corner. The glow leans brighter
// while hovered, like the product window catching your eye. The shell keeps
// the daemon, stacking, text and actions; this only dresses the card.
Item {
    id: root
    required property var pal

    function inkA(a)   { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function slateA(a) { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.94)
    property color cardBorder: slateA(0.65)
    property int cardBorderWidth: 1
    property int cardRadius: 9
    property bool cardSpine: false   // the ticket stub below replaces it

    // notification center: the vending machine's lit window — night glass
    // with a slate frame, a row of bottle-lights across the top (dimmed to
    // embers while DND holds), and a punched star at the foot
    property color panelBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.96)
    property color panelBorder: slateA(0.75)
    property int panelBorderWidth: 1
    property int panelRadius: 11
    property string panelTitle: "notifications"
    property Component panelBackdrop: Component {
        Item {
            id: machine
            property var panel: null
            readonly property bool quiet: panel ? panel.dnd : false

            // bottle-lights at the foot, opposite the punched star
            Row {
                anchors { bottom: parent.bottom; left: parent.left; bottomMargin: 7; leftMargin: 16 }
                spacing: 9
                Repeater {
                    model: 3
                    Item {
                        required property int index
                        width: 5; height: 9
                        opacity: machine.quiet ? 0.35 : 0.55 + index * 0.15
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 0
                            width: 2.5; height: 1.5; radius: 0.5
                            color: root.pal.neon
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 1.5
                            width: 5; height: 7.5; radius: 2
                            color: Qt.rgba(root.pal.neon.r, root.pal.neon.g, root.pal.neon.b, 0.9)
                        }
                    }
                }
            }

            // light pooled in from the top of the window
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
                height: Math.min(46, parent.height * 0.2)
                radius: 10
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(root.pal.neon.r, root.pal.neon.g, root.pal.neon.b, machine.quiet ? 0.04 : 0.09) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Text {
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 10; bottomMargin: 7 }
                text: "✧"
                font.pixelSize: 11
                color: root.inkA(0.32)
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: chassis
            property var note: null   // injected by the shell: the card delegate
            readonly property color tint: note ? note.accentCol : root.pal.neon
            function tintA(a) { return Qt.rgba(tint.r, tint.g, tint.b, a) }

            // warm glow edge, urgency-tinted, brighter under the pointer
            Rectangle {
                anchors.fill: parent
                radius: root.cardRadius
                color: "transparent"
                border.width: 1
                border.color: chassis.tintA(chassis.note && chassis.note.hovered ? 0.85 : 0.5)
                Behavior on border.color { ColorAnimation { duration: 180 } }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                radius: root.cardRadius + 2
                color: "transparent"
                border.width: 2
                border.color: chassis.tintA(chassis.note && chassis.note.hovered ? 0.22 : 0.10)
                Behavior on border.color { ColorAnimation { duration: 180 } }
            }
            // light pooled inside the top of the card
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: Math.min(34, parent.height * 0.45)
                radius: root.cardRadius - 1
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chassis.tintA(0.10) }
                    GradientStop { position: 1.0; color: chassis.tintA(0.0) }
                }
            }

            // the ticket stub: perforation dots down a left rail
            Column {
                id: perf
                anchors.left: parent.left
                anchors.leftMargin: 13
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Repeater {
                    model: Math.max(2, Math.floor((chassis.height - 26) / 8))
                    Rectangle {
                        width: 2.5; height: 2.5; radius: 1.25
                        color: root.inkA(0.28)
                    }
                }
            }
            // the stub's bottle-light, lit in the urgency color
            Item {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.top: parent.top
                anchors.topMargin: 8
                width: 7; height: 12
                Rectangle {   // halo
                    anchors.centerIn: parent
                    width: 15; height: 18; radius: 7
                    color: chassis.tint
                    opacity: 0.16
                }
                Rectangle {   // cap
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 0
                    width: 3; height: 2; radius: 0.5
                    color: chassis.tint
                }
                Rectangle {   // body
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 2
                    width: 7; height: 10; radius: 2.5
                    color: chassis.tintA(0.9)
                }
            }

            // the punched star, bottom-right
            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 8
                anchors.bottomMargin: 5
                text: "✧"
                font.pixelSize: 9
                color: root.inkA(0.30)
            }
        }
    }
}
