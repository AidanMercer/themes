import QtQuick

// nature — "golden hour" notification chrome: pressed-flower stationery.
//
// Dark pine paper (the shell's text tokens are warm cream, so the page is
// evening-dark) with a deckle-cream hairline, an organic flower stalk grown
// down the left edge in place of the default urgency stripe, and a pressed
// daisy in the corner whose petals take the urgency tint — gold for normal,
// leaf-green for low, dusty rose for critical (via note.accentCol). The
// shell keeps the daemon, stacking, text and actions; this only dresses
// the card.
Item {
    id: root
    required property var pal

    readonly property color cream: pal.text
    readonly property color pine:  pal.glass
    function creamA(a) { return Qt.rgba(cream.r, cream.g, cream.b, a) }

    // evening paper: pine glass warmed a touch toward cream
    readonly property color paper: Qt.rgba(
        pine.r + (cream.r - pine.r) * 0.05,
        pine.g + (cream.g - pine.g) * 0.05,
        pine.b + (cream.b - pine.b) * 0.05, 1)

    property color cardBg: Qt.rgba(paper.r, paper.g, paper.b, 0.94)
    property color cardBorder: creamA(0.20)
    property int cardBorderWidth: 1
    property int cardRadius: Math.round(12 * pal.uiScale)
    property bool cardSpine: false   // the stalk below replaces it

    // notification center: the flower press itself — evening paper with a
    // deckle double edge, sun catching the top of the page, one pressed
    // daisy in the foot corner keeping gold
    property color panelBg: Qt.rgba(paper.r, paper.g, paper.b, 0.96)
    property color panelBorder: creamA(0.24)
    property int panelBorderWidth: 1
    property int panelRadius: 14
    property string panelTitle: "Field notes"
    property Component panelBackdrop: Component {
        Item {
            property var panel: null

            Rectangle {
                anchors.fill: parent
                anchors.margins: 5
                radius: 10
                color: "transparent"
                border.width: 1
                border.color: root.creamA(0.10)
            }

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 26
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(root.pal.neon.r, root.pal.neon.g, root.pal.neon.b, 0.06) }
                    GradientStop { position: 1.0; color: Qt.rgba(root.pal.neon.r, root.pal.neon.g, root.pal.neon.b, 0) }
                }
            }

            Canvas {
                id: pressDaisy
                width: 30; height: 30
                anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
                opacity: 0.55
                Connections {
                    target: root.pal
                    function onNeonChanged() { pressDaisy.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const c = width / 2, pr = width * 0.3
                    const t = root.pal.neon
                    ctx.fillStyle = Qt.rgba(t.r, t.g, t.b, 0.45)
                    for (let i = 0; i < 5; i++) {
                        const a = -Math.PI / 2 + 0.3 + i * Math.PI * 2 / 5
                        ctx.save()
                        ctx.translate(c + Math.cos(a) * pr * 0.8, c + Math.sin(a) * pr * 0.8)
                        ctx.rotate(a + Math.PI / 2)
                        ctx.beginPath()
                        ctx.ellipse(-pr * 0.34, -pr * 0.8, pr * 0.68, pr * 1.6)
                        ctx.fill()
                        ctx.restore()
                    }
                    ctx.beginPath()
                    ctx.arc(c, c, pr * 0.34, 0, Math.PI * 2)
                    ctx.fillStyle = root.creamA(0.6)
                    ctx.fill()
                }
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: chassis
            property var note: null   // injected by the shell: the card delegate
            readonly property color tint: note ? note.accentCol : root.pal.neon

            // the flower stalk down the left edge, urgency-tinted
            Canvas {
                id: stalk
                width: Math.round(16 * root.pal.uiScale)
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                    margins: Math.round(6 * root.pal.uiScale)
                }
                onHeightChanged: requestPaint()
                Connections {
                    target: chassis
                    function onTintChanged() { stalk.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    if (h <= 0) return
                    const ui = root.pal.uiScale
                    const t = chassis.tint
                    // curved stem, rooted at the bottom
                    ctx.strokeStyle = Qt.rgba(t.r, t.g, t.b, 0.8)
                    ctx.lineWidth = 1.5 * ui
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.moveTo(w * 0.45, h)
                    ctx.bezierCurveTo(w * 0.15, h * 0.65, w * 0.7, h * 0.4, w * 0.4, h * 0.12)
                    ctx.stroke()
                    // two leaves off the stem
                    ctx.fillStyle = Qt.rgba(t.r, t.g, t.b, 0.55)
                    ctx.save()
                    ctx.translate(w * 0.35, h * 0.68)
                    ctx.rotate(-1.1)
                    ctx.beginPath()
                    ctx.ellipse(0, -2.2 * ui, 8 * ui, 4.4 * ui)
                    ctx.fill()
                    ctx.restore()
                    ctx.save()
                    ctx.translate(w * 0.5, h * 0.42)
                    ctx.rotate(0.5)
                    ctx.beginPath()
                    ctx.ellipse(0, -2 * ui, 7 * ui, 4 * ui)
                    ctx.fill()
                    ctx.restore()
                    // the bud at the tip
                    ctx.beginPath()
                    ctx.ellipse(w * 0.4 - 2.6 * ui, h * 0.12 - 3.6 * ui, 5.2 * ui, 7.2 * ui)
                    ctx.fillStyle = Qt.rgba(t.r, t.g, t.b, 0.95)
                    ctx.fill()
                }
            }

            // pressed daisy in the bottom-right corner, urgency-tinted petals
            Canvas {
                id: daisy
                width: Math.round(26 * root.pal.uiScale)
                height: Math.round(26 * root.pal.uiScale)
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    margins: Math.round(8 * root.pal.uiScale)
                }
                opacity: 0.6
                Connections {
                    target: chassis
                    function onTintChanged() { daisy.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const c = width / 2, pr = width * 0.3
                    const t = chassis.tint
                    ctx.fillStyle = Qt.rgba(t.r, t.g, t.b, 0.45)
                    for (let i = 0; i < 5; i++) {
                        const a = -Math.PI / 2 + 0.3 + i * Math.PI * 2 / 5
                        ctx.save()
                        ctx.translate(c + Math.cos(a) * pr * 0.8, c + Math.sin(a) * pr * 0.8)
                        ctx.rotate(a + Math.PI / 2)
                        ctx.beginPath()
                        ctx.ellipse(-pr * 0.34, -pr * 0.8, pr * 0.68, pr * 1.6)
                        ctx.fill()
                        ctx.restore()
                    }
                    ctx.beginPath()
                    ctx.arc(c, c, pr * 0.34, 0, Math.PI * 2)
                    ctx.fillStyle = root.creamA(0.6)
                    ctx.fill()
                }
            }

            // a faint golden press-mark along the top, like sun caught the page
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Math.round(20 * root.pal.uiScale)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(root.pal.neon.r, root.pal.neon.g, root.pal.neon.b, 0.05) }
                    GradientStop { position: 1.0; color: Qt.rgba(root.pal.neon.r, root.pal.neon.g, root.pal.neon.b, 0) }
                }
            }
        }
    }
}
