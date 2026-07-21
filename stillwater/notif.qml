import QtQuick

// stillwater: a light across the water. Each notification card is a small
// piece of the evening: deep-water glass with the card's own waterline near
// its foot, and one lamp — lit in the urgency color — standing on that line
// at the left, doubled beneath it as a broken streak. Hover and the lamp
// leans closer (brighter, longer streak). The shell keeps the daemon,
// stacking, text and actions; this only dresses the card.
Item {
    id: root
    required property var pal

    function inkA(a)   { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function skyA(a)   { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function slateA(a) { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function lampA(a)  { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }

    property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.93)
    property color cardBorder: skyA(0.30)
    property int cardBorderWidth: 1
    property int cardRadius: 10
    property bool cardSpine: false  // the lamp on the waterline replaces it

    // notification center: the evening's ledger — a strip of far-shore lamps
    // along the top that go dark under do-not-disturb, and a waterline near
    // the panel's foot with the whole shore doubled beneath it
    property color panelBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.96)
    property color panelBorder: skyA(0.35)
    property int panelBorderWidth: 1
    property int panelRadius: 12
    property string panelTitle: "Notifications"
    property Component panelBackdrop: Component {
        Item {
            id: ledger
            property var panel: null
            readonly property bool quiet: panel ? panel.dnd : false

            // the far shore along the top of the panel — asleep under DND
            Item {
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 9; leftMargin: 16; rightMargin: 16 }
                height: 10
                Rectangle { y: 5; width: parent.width; height: 1; color: root.skyA(ledger.quiet ? 0.12 : 0.22) }
                Repeater {
                    model: Math.max(4, Math.floor((ledger.width - 32) / 26))
                    Item {
                        required property int index
                        readonly property real seed: ((index * 0.61803) % 1)
                        x: index * 26 + 4
                        y: 5
                        Rectangle {
                            x: -1.5; y: -2
                            width: 3; height: 3
                            radius: 1.5
                            color: seed < 0.6 ? root.pal.neon : root.slateA(1)
                            opacity: ledger.quiet ? (seed < 0.6 ? 0.15 : 0.3)
                                                  : (seed < 0.6 ? 0.4 + seed * 0.5 : 0.4)
                        }
                        Rectangle {
                            x: -1; y: 3
                            width: 2; height: 2
                            visible: seed < 0.6
                            color: root.lampA(ledger.quiet ? 0.06 : 0.2)
                        }
                    }
                }
            }

            // dusk pooling from the top
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
                height: Math.min(46, parent.height * 0.2)
                radius: 11
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(root.pal.magenta.r, root.pal.magenta.g, root.pal.magenta.b, ledger.quiet ? 0.02 : 0.06) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // DND: the shore has gone dark
            Text {
                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 16; bottomMargin: 8 }
                visible: ledger.quiet
                text: "do not disturb"
                font.family: root.pal.fontMono
                font.pixelSize: 10
                font.letterSpacing: 2
                color: root.slateA(1)
            }
            // the count, floating on the water at the foot
            Text {
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 16; bottomMargin: 8 }
                visible: ledger.panel !== null && !ledger.quiet
                text: (ledger.panel ? ledger.panel.count : 0) + ((ledger.panel && ledger.panel.count === 1) ? " notification" : " notifications")
                font.family: root.pal.fontMono
                font.pixelSize: 10
                font.letterSpacing: 2
                color: root.skyA(0.7)
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: card
            property var note: null   // injected by the shell: the card delegate
            readonly property color tint: note ? note.accentCol : root.pal.neon
            readonly property bool hot: note ? note.hovered === true : false
            function tintA(a) { return Qt.rgba(tint.r, tint.g, tint.b, a) }
            // the card's waterline sits low; short history rows keep it sane
            readonly property real wl: Math.max(18, height - 14)

            // dusk glow inside the top edge
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: Math.min(26, parent.height * 0.4)
                radius: root.cardRadius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: card.tintA(0.08) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // the waterline
            Rectangle {
                x: 10; y: card.wl
                width: parent.width - 20
                height: 1
                color: root.skyA(0.22)
            }
            // the lamp standing on it, in urgency color
            Rectangle {
                x: 14; y: card.wl - 3
                width: 5; height: 5
                radius: 2.5
                color: card.tint
                opacity: card.hot ? 1 : 0.85
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
            // upward glow when the light is looked at
            Rectangle {
                x: 15.5; y: card.wl - 10
                width: 2
                height: 7
                opacity: card.hot ? 0.6 : 0.25
                Behavior on opacity { NumberAnimation { duration: 200 } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: card.tintA(0.9) }
                }
            }
            // the streak beneath — longer under the pointer
            Column {
                x: 15; y: card.wl + 4
                spacing: 2
                Repeater {
                    model: card.hot ? 3 : 2
                    Rectangle {
                        required property int index
                        width: 3 - (index > 1 ? 1 : 0); height: 2
                        color: card.tintA((card.hot ? 0.45 : 0.3) - index * 0.1)
                    }
                }
            }
        }
    }
}
