import QtQuick

// gunsmoke: notifications arrive as TELEGRAM SLIPS torn off the wire. Each
// card: iron-dark paper, a double rule under the top edge with a run of
// morse dashes riding it, a wax seal at the top-left in the urgency color
// (the shell's accent — critical bleeds oxblood, and the seal is the only
// place a slip ever shows it), and a TORN bottom edge cut by Canvas — the
// slip was ripped off the roll. Hover and the seal presses darker.
// The Super+I drawer is the DISPATCHES ledger: unread counted in gate-tally
// strokes, and under do-not-disturb the wire goes silent.
Item {
    id: root
    required property var pal

    readonly property string serif: "Noto Serif"
    function boneA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function ashA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.94)
    property color cardBorder: ashA(0.6)
    property int cardBorderWidth: 1
    property int cardRadius: 2      // paper, not glass
    property bool cardSpine: false  // the wax seal replaces the urgency stripe

    // the dispatches ledger (Super+I)
    property color panelBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.96)
    property color panelBorder: ashA(0.75)
    property int panelBorderWidth: 1
    property int panelRadius: 3
    property string panelTitle: "Dispatches"
    property Component panelBackdrop: Component {
        Item {
            id: ledger
            property var panel: null
            readonly property bool quiet: panel ? panel.dnd : false
            readonly property int count: panel ? panel.count : 0

            // double rule under the drawer's head
            Rectangle { x: 12; y: 6; width: parent.width - 24; height: 1; color: root.boneA(quiet ? 0.15 : 0.35) }
            Rectangle { x: 12; y: 9; width: parent.width - 24; height: 1; color: root.boneA(quiet ? 0.06 : 0.13) }

            // the tally: dispatches on file, counted in gate strokes
            Canvas {
                id: tally
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 14
                anchors.topMargin: 14
                width: 130; height: 14
                opacity: ledger.quiet ? 0.3 : 0.8
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = String(root.boneA(0.75))
                    ctx.lineWidth = 1.6
                    ctx.lineCap = "round"
                    const n = Math.min(20, ledger.count)
                    for (let i = 0; i < n; i++) {
                        const grp = Math.floor(i / 5), pos = i % 5
                        if (pos < 4) {
                            const gx = width - 4 - grp * 26 - pos * 5
                            const lean = ((i * 7) % 3) - 1
                            ctx.beginPath()
                            ctx.moveTo(gx + lean, 2)
                            ctx.lineTo(gx - lean, 12)
                            ctx.stroke()
                        } else {
                            const gx = width - 4 - grp * 26
                            ctx.beginPath()
                            ctx.moveTo(gx + 2, 11)
                            ctx.lineTo(gx - 17, 4)
                            ctx.stroke()
                        }
                    }
                }
                Connections {
                    target: ledger
                    function onCountChanged() { tally.requestPaint() }
                }
                Component.onCompleted: requestPaint()
            }

            // do-not-disturb: the wire is cut
            Row {
                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 14; bottomMargin: 8 }
                spacing: 8
                visible: ledger.quiet
                // a cut telegraph line: dash, gap, dash
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Rectangle { width: 10; height: 1.5; color: root.ashA(1); anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { width: 3; height: 1.5; color: "transparent" }
                    Rectangle { width: 10; height: 1.5; color: root.ashA(1); anchors.verticalCenter: parent.verticalCenter }
                }
                Text {
                    text: "WIRE SILENT"
                    font.family: root.serif
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    font.letterSpacing: 3
                    color: root.ashA(1)
                }
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: slip
            property var note: null   // injected by the shell: the card delegate
            readonly property color seal: note ? note.accentCol : root.pal.neon
            function sealA(a) { return Qt.rgba(seal.r, seal.g, seal.b, a) }

            // double rule under the top edge, with morse dashes riding it
            Rectangle { x: 10; y: 6; width: parent.width - 20; height: 1; color: root.boneA(0.30) }
            Rectangle { x: 10; y: 9; width: parent.width - 20; height: 1; color: root.boneA(0.11) }
            Row {
                x: 34; y: 4
                spacing: 4
                Repeater {
                    model: 6
                    Rectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: index % 3 === 2 ? 2 : 7
                        height: 1.5
                        color: slip.sealA(0.55)
                    }
                }
            }

            // the wax seal, top-left — urgency color; presses darker on hover
            Rectangle {
                x: 12; y: 12
                width: 11; height: 11; radius: 5.5
                color: slip.sealA(slip.note && slip.note.hovered ? 1 : 0.8)
                Behavior on color { ColorAnimation { duration: 180 } }
                // the press mark in the wax
                Rectangle {
                    anchors.centerIn: parent
                    width: 4; height: 4; radius: 2
                    color: Qt.rgba(0, 0, 0, 0.4)
                }
            }

            // the torn foot: a jagged rip cut across the bottom edge
            Canvas {
                id: torn
                anchors.bottom: parent.bottom
                width: parent.width
                height: 7
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0) return
                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    let x = 0, i = 0
                    while (x < width) {
                        const step = 7 + ((i * 13) % 9)
                        x += step
                        ctx.lineTo(Math.min(x, width), (i % 2) === 0 ? 4.5 : 1.5)
                        i++
                    }
                    ctx.lineTo(width, 0)
                    ctx.strokeStyle = String(root.boneA(0.28))
                    ctx.lineWidth = 1
                    ctx.stroke()
                }
            }
        }
    }
}
