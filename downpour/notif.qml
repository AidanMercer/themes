import QtQuick

// downpour: each notification is a breath on the glass — a soft-cornered
// condensation card, a bead in the urgency color condensing at its top-left
// and spending itself in one run down the card's rim as the card arrives.
// Urgent news runs warm — the rose of the thing she hasn't said. The shell
// keeps the daemon, stacking, text and actions; this only dresses the card.
Item {
    id: root
    required property var pal

    readonly property string serif: "Noto Serif"
    function inkA(a)   { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function slateA(a) { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function paneA(a)  { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }

    property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.93)
    property color cardBorder: inkA(0.13)
    property int cardBorderWidth: 1
    property int cardRadius: 18      // a breath mark, not a box
    property bool cardSpine: false   // the bead below replaces it

    // notification center: what the glass held while you were away —
    // fogged deeper under do-not-disturb, when the pane stops passing
    // anything through
    property color panelBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.96)
    property color panelBorder: inkA(0.13)
    property int panelBorderWidth: 1
    property int panelRadius: 22
    property string panelTitle: "while you were away"
    property Component panelBackdrop: Component {
        Item {
            id: pane
            property var panel: null
            readonly property bool quiet: panel ? panel.dnd : false

            // the breath pooling at the top of the pane
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
                height: Math.min(56, parent.height * 0.22)
                radius: 21
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.inkA(pane.quiet ? 0.02 : 0.05) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // beads resting along the pane's left rim
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    x: 7
                    y: 40 + index * ((pane.height - 80) / 4)
                    width: 3.6 + (index % 2) * 1.4
                    height: width * 1.25
                    radius: width / 2
                    color: root.paneA(pane.quiet ? 0.14 : 0.32)
                }
            }

            // under DND the glass fogs over completely
            Rectangle {
                anchors.fill: parent
                radius: 22
                color: root.inkA(pane.quiet ? 0.04 : 0)
                Behavior on color { ColorAnimation { duration: 700 } }
            }
            Text {
                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 16; bottomMargin: 9 }
                visible: pane.quiet
                text: "the glass is fogged — nothing gets through"
                font.family: root.serif
                font.italic: true
                font.pixelSize: 10
                color: root.slateA(1)
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: mark
            property var note: null   // injected by the shell: the card delegate
            readonly property color tint: note ? note.accentCol : root.pal.neon
            function tintA(a) { return Qt.rgba(tint.r, tint.g, tint.b, a) }

            // rim, breathed a little brighter under the pointer
            Rectangle {
                anchors.fill: parent
                radius: root.cardRadius
                color: "transparent"
                border.width: 1
                border.color: mark.tintA(mark.note && mark.note.hovered ? 0.55 : 0.26)
                Behavior on border.color { ColorAnimation { duration: 300 } }
            }
            // the breath inside the card's top
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: Math.min(30, parent.height * 0.45)
                radius: root.cardRadius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: mark.tintA(0.08) }
                    GradientStop { position: 1.0; color: mark.tintA(0.0) }
                }
            }

            // the bead: condenses at the top-left, then spends one run down
            // the rim as the card arrives
            Item {
                x: 10
                y: 9
                Rectangle {
                    id: bead
                    x: -2.6
                    y: arrival.t * Math.max(0, mark.height - 26)
                    width: 5.2; height: 6.6
                    radius: 2.6
                    color: mark.tintA(0.95 - arrival.t * 0.35)
                    Rectangle { x: 1; y: 1.2; width: 1.6; height: 1.6; radius: 0.8; color: root.inkA(0.85) }
                }
                Rectangle {
                    x: -1.4
                    y: 0
                    width: 1.4
                    height: bead.y
                    opacity: 0.4 * (1 - arrival.t * 0.7)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: mark.tintA(0.0) }
                        GradientStop { position: 1.0; color: mark.tintA(0.8) }
                    }
                }
                Item { id: arrival; property real t: 0 }
                SequentialAnimation {
                    running: true   // once, as the card condenses into being
                    PauseAnimation { duration: 350 }
                    NumberAnimation { target: arrival; property: "t"; from: 0; to: 0.55; duration: 700; easing.type: Easing.InQuad }
                    NumberAnimation { target: arrival; property: "t"; from: 0.55; to: 0.62; duration: 900; easing.type: Easing.OutSine }
                }
            }
        }
    }
}
