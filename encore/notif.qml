import QtQuick

// encore: STAGE NOTES — notification chrome. Each card is a note passed to
// the desk mid-show: a stage-black capsule with one piano-roll lane running
// down its left edge and a single note block sitting on the lane, tinted by
// urgency and lighting to full when the card is under the pointer (the
// follow-spot finds it). The notification center is the same black slab,
// a lane across its head carrying one note block per pending card, and a
// magenta dnd block when do-not-disturb has the crowd hushed.
// The shell keeps the daemon, stacking, text layout and actions.
Item {
    id: root
    required property var pal

    property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.93)
    property color cardBorder: Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, 0.32)
    property int cardRadius: 13
    property int cardBorderWidth: 1
    property bool cardSpine: false   // the lane below replaces it

    // notification center
    property color panelBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.96)
    property color panelBorder: Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, 0.4)
    property int panelBorderWidth: 1
    property int panelRadius: 15
    property string panelTitle: "notifications"
    property Component panelBackdrop: Component {
        Item {
            id: deck
            property var panel: null
            readonly property bool hushed: panel ? panel.dnd === true : false
            readonly property int pending: panel ? Math.min(8, panel.count || 0) : 0

            // the head lane the pending cards sit on
            Rectangle {
                id: headLane
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 10 }
                anchors.topMargin: 14
                height: 1
                color: Qt.rgba(root.pal.dim.r, root.pal.dim.g, root.pal.dim.b, 0.7)
            }
            // one note block per waiting notification, left to right on the lane
            Row {
                anchors.left: headLane.left
                anchors.leftMargin: 2
                y: headLane.y - 4
                spacing: 5
                Repeater {
                    model: deck.pending
                    Rectangle {
                        width: 14; height: 7; radius: 3.5
                        color: Qt.rgba(root.pal.neon.r, root.pal.neon.g, root.pal.neon.b, 0.85)
                    }
                }
            }
            // hushed: the crowd's dnd block parks at the right of the lane
            Rectangle {
                visible: deck.hushed
                anchors.right: headLane.right
                anchors.rightMargin: 2
                y: headLane.y - 4
                width: 26; height: 7; radius: 3.5
                color: root.pal.magenta
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 3
                    text: "dnd"
                    font.family: root.pal.fontMono
                    font.pixelSize: 10
                    font.letterSpacing: 2
                    color: root.pal.magenta
                }
            }
            // the teal edge-strip foot
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 40
                height: 2
                radius: 1
                color: Qt.rgba(root.pal.neon.r, root.pal.neon.g, root.pal.neon.b, 0.45)
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: chassis
            property var note: null   // injected by the shell: the card delegate
            readonly property color tint: note ? note.accentCol : root.pal.neon
            readonly property bool lit: note ? note.hovered === true : false

            // the lane: one ruled piano-roll row down the left edge
            Item {
                id: lane
                width: 16
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 7 }
                // the rule
                Rectangle {
                    x: 7
                    width: 1
                    height: parent.height
                    color: Qt.rgba(root.pal.dim.r, root.pal.dim.g, root.pal.dim.b, 0.8)
                }
                // beat ticks on the rule — printed, not blinking
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        x: 5
                        y: (index + 1) * lane.height / 5
                        width: 5; height: 1
                        color: Qt.rgba(root.pal.dim.r, root.pal.dim.g, root.pal.dim.b, 0.8)
                    }
                }
                // the note block: this message's note, sung when the spot hits
                Rectangle {
                    x: 2
                    y: parent.height * 0.18
                    width: 11
                    height: Math.max(14, parent.height * 0.26)
                    radius: width / 2
                    color: chassis.lit ? chassis.tint
                                       : Qt.rgba(chassis.tint.r, chassis.tint.g, chassis.tint.b, 0.45)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            // the card's teal foot, tinted by urgency
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 34
                height: 2
                radius: 1
                color: Qt.rgba(chassis.tint.r, chassis.tint.g, chassis.tint.b, chassis.lit ? 0.8 : 0.4)
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
    }
}
