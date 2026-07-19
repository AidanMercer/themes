import QtQuick

// thicket: SOMETHING MOVED — notification chrome. Each card is a rustle at
// the edge of your vision: foliage glass with a leaf silhouette lying over
// each corner, a single eyeshine glint burning in the urgency color at the
// head of a stem running down the left rail. Hover and the glint widens —
// you've met its eye. The shell keeps the daemon, stacking, text and
// actions; this only dresses the card. The notification center (Super+I) is
// the watcher's ledger: FIELD SIGHTINGS, with a row of closed eyes across
// the top that shut tighter under do-not-disturb.
Item {
    id: root
    required property var pal

    function inkA(a)   { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function leafA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function emberA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function irisA(a)  { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }

    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.94)
    property color cardBorder: leafA(0.6)
    property int cardBorderWidth: 1
    property int cardRadius: 9
    property bool cardSpine: false  // the glint-and-stem rail below replaces it

    // notification center: the watcher's ledger
    property color panelBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.96)
    property color panelBorder: leafA(0.7)
    property int panelBorderWidth: 1
    property int panelRadius: 11
    property string panelTitle: "Field sightings"
    property Component panelBackdrop: Component {
        Item {
            id: ledger
            property var panel: null
            readonly property bool quiet: panel ? panel.dnd : false

            // a row of eyes along the top — half-lidded, shut under DND
            Row {
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 8; leftMargin: 16; rightMargin: 16 }
                spacing: 12
                Repeater {
                    model: Math.max(3, Math.floor((ledger.width - 32) / 26))
                    Rectangle {
                        required property int index
                        width: 7
                        height: ledger.quiet ? 1.5 : 4
                        radius: height / 2
                        color: ledger.quiet ? root.leafA(0.9) : root.irisA(0.3 + root.rnd(index * 7) * 0.35)
                        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                    }
                }
            }

            // dapple pooling from the top
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
                height: Math.min(42, parent.height * 0.2)
                radius: 10
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(root.pal.amber.r, root.pal.amber.g, root.pal.amber.b, ledger.quiet ? 0.03 : 0.08) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // corner leaves — one draw
            Canvas {
                anchors.fill: parent
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    const w = width, h = height
                    function leafShape(x, y, len, wid, ang, fill) {
                        ctx.save()
                        ctx.translate(x, y); ctx.rotate(ang)
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.quadraticCurveTo(len * 0.42, -wid, len, -wid * 0.08)
                        ctx.quadraticCurveTo(len * 0.46, wid * 0.9, 0, 0)
                        ctx.closePath()
                        ctx.fillStyle = fill
                        ctx.fill()
                        ctx.restore()
                    }
                    leafShape(3, h * 0.3, 22, 6, 0.9, "rgba(6,10,8,0.9)")
                    leafShape(w - 3, h * 0.7, 22, 6, Math.PI - 0.9, "rgba(23,44,38,0.88)")
                    leafShape(w * 0.4, h - 2, 18, 5, -Math.PI / 2 + 0.6, "rgba(6,10,8,0.88)")
                }
            }

            Text {
                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 16; bottomMargin: 8 }
                visible: ledger.quiet
                text: "eyes closed"
                font.family: "Noto Serif Display"
                font.italic: true
                font.pixelSize: 10
                color: root.leafA(1)
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: sighting
            property var note: null   // injected by the shell: the card delegate
            readonly property color tint: note ? note.accentCol : root.pal.neon
            readonly property bool hot: note ? note.hovered === true : false
            function tintA(a) { return Qt.rgba(tint.r, tint.g, tint.b, a) }

            // urgency-tinted rim, warmer under the pointer
            Rectangle {
                anchors.fill: parent
                radius: root.cardRadius
                color: "transparent"
                border.width: 1
                border.color: sighting.tintA(sighting.hot ? 0.8 : 0.4)
                Behavior on border.color { ColorAnimation { duration: 180 } }
            }
            // dapple pooled inside the top of the card
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: Math.min(28, parent.height * 0.45)
                radius: root.cardRadius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: sighting.tintA(0.10) }
                    GradientStop { position: 1.0; color: sighting.tintA(0.0) }
                }
            }

            // the stem down the left rail
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 24
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                width: 1
                color: root.inkA(0.18)
            }
            // two leaflets off the stem
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 8
                y: parent.height * 0.5
                width: 7; height: 3; radius: 1.5
                rotation: -28
                color: root.leafA(0.9)
            }
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 12
                y: parent.height * 0.72
                width: 7; height: 3; radius: 1.5
                rotation: 208
                color: root.leafA(0.9)
            }
            // the glint at the head of the stem — the sighting itself.
            // hover = you meet its eye and it widens
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 9
                anchors.top: parent.top
                anchors.topMargin: 10
                width: sighting.hot ? 9 : 7
                height: sighting.hot ? 6 : 4.5
                radius: height / 2
                color: sighting.tint
                Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutQuint } }
                Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutQuint } }
                Rectangle {
                    x: 2; y: 1
                    width: 2; height: 2; radius: 1
                    color: Qt.rgba(1, 1, 1, 0.85)
                }
            }
            // a leaf lying over the card's top-right corner
            Canvas {
                anchors.fill: parent
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    ctx.save()
                    ctx.translate(width - 4, 4); ctx.rotate(Math.PI - 0.7)
                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    ctx.quadraticCurveTo(8, -5.5, 19, -1.5)
                    ctx.quadraticCurveTo(8.5, 4.5, 0, 0)
                    ctx.closePath()
                    ctx.fillStyle = "rgba(6,10,8,0.9)"
                    ctx.fill()
                    ctx.restore()
                }
            }
        }
    }
}
