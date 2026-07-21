import QtQuick

// road8: roadside-marker notification chrome. Each card is a mile marker
// planted at the edge of the night: square-cornered night glass with pixel
// notch squares punched into all four corners (the 8-bit dialog cut), a
// taillight lamp burning in the urgency color at the top of a dashed
// guide-line down the left rail, and light pooling in from the top edge.
// Hover and the lamp burns brighter — headlights catching the marker. The
// shell keeps the daemon, stacking, text and actions; this only dresses
// the card.
Item {
    id: root
    required property var pal

    function inkA(a)   { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function slateA(a) { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function amberA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }

    property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.94)
    property color cardBorder: slateA(0.65)
    property int cardBorderWidth: 1
    property int cardRadius: 2      // pixel-square, no soft corners on this road
    property bool cardSpine: false  // the taillight rail below replaces it

    // notification center: the trip log — night glass, a strip of city
    // windows along the top that goes dark when do-not-disturb parks the
    // radio, and the little car waiting at the foot of the list
    property color panelBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.96)
    property color panelBorder: slateA(0.75)
    property int panelBorderWidth: 1
    property int panelRadius: 4
    property string panelTitle: "Notifications"
    property Component panelBackdrop: Component {
        Item {
            id: log
            property var panel: null
            readonly property bool quiet: panel ? panel.dnd : false

            // the city along the top of the log — asleep under DND
            Row {
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 7; leftMargin: 14; rightMargin: 14 }
                spacing: 7
                Repeater {
                    model: Math.max(4, Math.floor((log.width - 28) / 13))
                    Rectangle {
                        required property int index
                        width: 3; height: 3
                        // a deterministic skyline: some windows lit, some dark
                        readonly property real seed: ((index * 0.61803) % 1)
                        color: seed < 0.55 ? root.pal.neon : root.slateA(1)
                        opacity: log.quiet ? (seed < 0.55 ? 0.18 : 0.3)
                                           : (seed < 0.55 ? 0.5 + seed * 0.4 : 0.45)
                    }
                }
            }

            // light pooling from the top
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
                height: Math.min(42, parent.height * 0.2)
                radius: 3
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.amberA(log.quiet ? 0.03 : 0.08) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // the car waits at the bottom; DND switches everything off
            Item {
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 12; bottomMargin: 8 }
                width: 22; height: 10
                opacity: 0.45
                Rectangle { x: 1; y: 4; width: 20; height: 4; color: root.slateA(1) }
                Rectangle { x: 6; y: 1; width: 10; height: 3; color: root.slateA(1) }
                Rectangle { x: 4; y: 8; width: 3; height: 2; color: Qt.rgba(0, 0, 0, 0.9) }
                Rectangle { x: 15; y: 8; width: 3; height: 2; color: Qt.rgba(0, 0, 0, 0.9) }
                Rectangle { x: 0; y: 4; width: 2; height: 3; color: log.quiet ? root.slateA(1) : root.pal.magenta }
                Rectangle { x: 20; y: 4; width: 2; height: 3; color: log.quiet ? root.slateA(1) : root.pal.neon }
            }
            Text {
                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 14; bottomMargin: 7 }
                visible: log.quiet
                text: "do not disturb"
                font.family: root.pal.fontMono
                font.pixelSize: 10
                font.letterSpacing: 2
                color: root.slateA(1)
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: marker
            property var note: null   // injected by the shell: the card delegate
            readonly property color tint: note ? note.accentCol : root.pal.neon
            function tintA(a) { return Qt.rgba(tint.r, tint.g, tint.b, a) }

            // urgency-tinted edge, brighter under the pointer
            Rectangle {
                anchors.fill: parent
                radius: root.cardRadius
                color: "transparent"
                border.width: 1
                border.color: marker.tintA(marker.note && marker.note.hovered ? 0.85 : 0.45)
                Behavior on border.color { ColorAnimation { duration: 180 } }
            }
            // the four corner notches — the pixel cut, punched as solid squares
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 4; height: 4
                    x: index % 2 === 0 ? 2 : marker.width - 6
                    y: index < 2 ? 2 : marker.height - 6
                    color: marker.tintA(0.55)
                }
            }
            // light pooled inside the top of the card
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: Math.min(30, parent.height * 0.45)
                radius: root.cardRadius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: marker.tintA(0.10) }
                    GradientStop { position: 1.0; color: marker.tintA(0.0) }
                }
            }

            // dashed guide-line down the left rail
            Column {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 24
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                spacing: 5
                clip: true
                Repeater {
                    model: Math.max(2, Math.floor((marker.height - 32) / 9))
                    Rectangle {
                        width: 2; height: 4
                        color: root.inkA(0.25)
                    }
                }
            }
            // the taillight lamp at the top of the rail, lit in urgency color
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 9
                width: 6; height: 6
                color: marker.tint
                // halo pixel ring
                Rectangle {
                    anchors.centerIn: parent
                    width: 12; height: 12
                    color: "transparent"
                    border.width: 1
                    border.color: marker.tintA(marker.note && marker.note.hovered ? 0.5 : 0.25)
                    Behavior on border.color { ColorAnimation { duration: 180 } }
                }
            }
        }
    }
}
