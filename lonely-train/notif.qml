import QtQuick

// lonely-train: station-placard notification chrome. Night glass with an
// amber band along the top edge (the station-sign grammar of the bar), a
// route spine down the left with a station dot lit in the urgency color,
// and a tiny LT roundel in the corner. The shell keeps the daemon, stack,
// text and actions; this only dresses the card.
Item {
    id: root
    required property var pal

    function inkA(a) { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }

    property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.94)
    property color cardBorder: inkA(0.12)
    property int cardBorderWidth: 1
    property int cardRadius: 9
    property bool cardSpine: false   // the route spine below replaces it

    // notification center: the platform notice board — night glass, amber
    // sign band across the top, a full route line running down the left
    // margin between the placards, roundel at the foot
    property color panelBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.96)
    property color panelBorder: inkA(0.16)
    property int panelBorderWidth: 1
    property int panelRadius: 11
    property string panelTitle: "Service notices"
    property Component panelBackdrop: Component {
        Item {
            id: board
            property var panel: null

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
                height: 3
                radius: 1.5
                color: Qt.rgba(root.pal.neon.r, root.pal.neon.g, root.pal.neon.b,
                               board.panel && board.panel.dnd ? 0.35 : 0.8)
            }

            // route line down the left margin, stops spaced out along it
            Item {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 4; topMargin: 54; bottomMargin: 26 }
                width: 6
                Rectangle {
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; bottom: parent.bottom }
                    width: 1.5
                    color: root.inkA(0.14)
                }
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 34
                    Repeater {
                        model: 6
                        Rectangle {
                            width: 4; height: 4; radius: 2
                            color: "transparent"
                            border.width: 1
                            border.color: root.inkA(0.3)
                        }
                    }
                }
            }

            Rectangle {
                anchors { right: parent.right; bottom: parent.bottom; margins: 9 }
                width: 15; height: 15; radius: 7.5
                color: "transparent"
                border.width: 1.2
                border.color: Qt.rgba(root.pal.neon.r, root.pal.neon.g, root.pal.neon.b, 0.5)
                Text {
                    anchors.centerIn: parent
                    text: "LT"
                    color: Qt.rgba(root.pal.neon.r, root.pal.neon.g, root.pal.neon.b, 0.6)
                    font.family: root.pal.fontMono
                    font.pixelSize: 6
                    font.weight: Font.Black
                }
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: chassis
            property var note: null   // injected by the shell: the card delegate
            readonly property color tint: note ? note.accentCol : root.pal.neon

            // amber band along the top edge — station-sign grammar
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 2
                radius: 1
                color: Qt.rgba(chassis.tint.r, chassis.tint.g, chassis.tint.b, 0.8)
            }

            // route spine: a vertical line with the arriving station lit
            Item {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 9
                width: 10

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    width: 1.5
                    color: root.inkA(0.15)
                }
                // passed stop, small and hollow
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 10
                    width: 4; height: 4; radius: 2
                    color: "transparent"
                    border.width: 1
                    border.color: root.inkA(0.3)
                }
                // this stop, lit in the urgency color
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: chassis.note && chassis.note.hovered ? 9 : 7
                    height: width
                    radius: width / 2
                    color: chassis.tint
                    Behavior on width { NumberAnimation { duration: 150 } }
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 6; height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(chassis.tint.r, chassis.tint.g, chassis.tint.b, 0.4)
                    }
                }
                // next stop
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    width: 4; height: 4; radius: 2
                    color: "transparent"
                    border.width: 1
                    border.color: root.inkA(0.3)
                }
            }

            // tiny LT roundel, bottom-right
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                width: 13; height: 13; radius: 6.5
                color: "transparent"
                border.width: 1.2
                border.color: Qt.rgba(root.pal.neon.r, root.pal.neon.g, root.pal.neon.b, 0.5)
                Text {
                    anchors.centerIn: parent
                    text: "LT"
                    color: Qt.rgba(root.pal.neon.r, root.pal.neon.g, root.pal.neon.b, 0.6)
                    font.family: root.pal.fontMono
                    font.pixelSize: 5
                    font.weight: Font.Black
                }
            }
        }
    }
}
