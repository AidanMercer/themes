import QtQuick
import "chalk.js" as Chalk

// homeroom: notifications are notes taped to the notice board. Each card
// gets a tape tab up top, a thumbtack head in the urgency color, a faint
// hand-chalked frame and a pool of morning sun; hover and the tack presses
// in brighter. The notification center is the whole board — bunting strung
// across the top (it dims under quiet hours), the day's count kept in chalk
// tallies at the foot, and a chalk "quiet hours" note when DND is on. The
// shell keeps the daemon, stacking, text and actions; this only dresses.
Item {
    id: root
    required property var pal

    function chalkA(a) { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function slateA(a) { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function sunA(a)   { return Qt.rgba(pal.amber.r, pal.amber.g, pal.amber.b, a) }
    function glassA(a) { return Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, a) }

    property color cardBg: glassA(0.94)
    property color cardBorder: slateA(0.6)
    property int cardBorderWidth: 1
    property int cardRadius: 3
    property bool cardSpine: false  // the thumbtack carries the urgency instead

    // notification center: the notice board itself
    property color panelBg: glassA(0.96)
    property color panelBorder: slateA(0.7)
    property int panelBorderWidth: 1
    property int panelRadius: 5
    property string panelTitle: "notice board"
    property Component panelBackdrop: Component {
        Item {
            id: board
            property var panel: null
            readonly property bool quiet: panel ? panel.dnd : false
            readonly property int count: panel ? panel.count : 0

            // bunting strung across the top — dims for quiet hours
            Row {
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 6; leftMargin: 16; rightMargin: 16 }
                spacing: 9
                Repeater {
                    model: Math.max(3, Math.floor((board.width - 32) / 21))
                    delegate: Canvas {
                        required property int index
                        width: 12; height: 13
                        opacity: board.quiet ? 0.22 : 0.6
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const col = index % 3 === 0 ? root.pal.magenta
                                      : index % 3 === 1 ? root.pal.neon : root.pal.text
                            ctx.beginPath()
                            ctx.moveTo(0, 1); ctx.lineTo(12, 1); ctx.lineTo(6, 12)
                            ctx.closePath()
                            ctx.fillStyle = String(Qt.rgba(col.r, col.g, col.b, 0.8))
                            ctx.fill()
                        }
                        Component.onCompleted: requestPaint()
                    }
                }
            }
            // the string the bunting hangs from
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 6; leftMargin: 10; rightMargin: 10 }
                height: 1
                color: root.chalkA(0.25)
            }

            // morning sun pooling from the top
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
                height: Math.min(46, parent.height * 0.2)
                radius: 4
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.sunA(board.quiet ? 0.03 : 0.08) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // the day's tally, kept in chalk at the foot
            Canvas {
                id: tallyFoot
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 14; bottomMargin: 8 }
                width: 96; height: 18
                opacity: 0.55
                property int n: Math.min(12, board.count)
                onNChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    for (let i = 0; i < n; i++) {
                        const grp = Math.floor(i / 5)
                        const pos = i % 5
                        const gx = 4 + grp * 40
                        if (pos < 4)
                            Chalk.strokePath(ctx, [[gx + pos * 7, 3], [gx + pos * 7 + 1, 15]],
                                { seed: 901 + i * 7, color: String(root.chalkA(1)), alpha: 0.9, width: 1.7, ghost: false, dust: 0 })
                        else
                            Chalk.strokePath(ctx, [[gx - 3, 13], [gx + 24, 4]],
                                { seed: 931 + i * 5, color: String(root.chalkA(1)), alpha: 0.9, width: 1.8, ghost: false, dust: 0 })
                    }
                }
            }

            // quiet hours, in chalk
            Text {
                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 16; bottomMargin: 7 }
                visible: board.quiet
                text: "quiet hours"
                font.family: root.pal.fontMono
                font.pixelSize: 10
                font.letterSpacing: 2
                color: root.chalkA(0.5)
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: dress
            property var note: null   // injected by the shell: the card delegate
            readonly property color tint: note ? note.accentCol : root.pal.neon
            readonly property bool hot: note ? note.hovered === true : false
            function tintA(a) { return Qt.rgba(tint.r, tint.g, tint.b, a) }

            // the tape tab, top-left, slightly crooked
            Rectangle {
                x: 10; y: -3
                width: 22; height: 8
                rotation: -34
                color: root.chalkA(dress.hot ? 0.55 : 0.38)
                Behavior on color { ColorAnimation { duration: 180 } }
            }
            // the thumbtack, top-right, pressed in the urgency color
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 10
                y: 7
                width: 9; height: 9; radius: 4.5
                color: dress.tintA(dress.hot ? 1 : 0.75)
                Behavior on color { ColorAnimation { duration: 180 } }
                Rectangle {   // its little shadow on the paper
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 1.5
                    anchors.verticalCenterOffset: 1.5
                    z: -1
                    width: 9; height: 9; radius: 4.5
                    color: Qt.rgba(0, 0, 0, 0.3)
                }
            }
            // morning sun pooled inside the top of the note
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: Math.min(26, parent.height * 0.45)
                radius: root.cardRadius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.sunA(0.09) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            // the faint chalked frame
            Canvas {
                id: noteFrame
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    const w = width, h = height, m = 5
                    Chalk.strokePath(ctx, [[m, m], [w - m, m + 1], [w - m - 1, h - m], [m + 1, h - m - 1], [m, m]], {
                        seed: 41 + Math.round(w), color: String(root.chalkA(1)), alpha: 0.16,
                        width: 1.6, ghost: false, dust: 0
                    })
                }
            }
        }
    }
}
