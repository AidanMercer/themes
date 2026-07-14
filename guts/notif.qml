import QtQuick

// guts: notification chrome — each card is a torn manga panel. Paper card,
// rough hand-ruled ink border with a ripped notch out of the top-right
// corner, screentone shading in the lower corner, and the urgency told by
// the size of the red ink splash thrown up the left spine: a fleck for low,
// a splash for normal, a burst with satellites for critical. The shell
// keeps the daemon/stack/text; this only dresses the card.
Item {
    id: root
    required property var pal

    readonly property color ink:   pal.text
    readonly property color paper: pal.glass
    function inkA(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    property color cardBg: Qt.rgba(paper.r, paper.g, paper.b, 0.97)
    property color cardBorder: "transparent"     // the backdrop rules the frame
    property int cardBorderWidth: 0
    property int cardRadius: 0
    property bool cardSpine: false               // the splash replaces it

    // notification center: the full manga page the panels are pasted onto —
    // hand-ruled double frame, screentone up the top-right, page number
    property color panelBg: Qt.rgba(paper.r, paper.g, paper.b, 0.98)
    property color panelBorder: "transparent"    // the backdrop rules this frame too
    property int panelBorderWidth: 0
    property int panelRadius: 0
    property string panelTitle: "Dispatches"
    property Component panelBackdrop: Component {
        Item {
            id: page
            property var panel: null

            Canvas {
                id: pcv
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: root.pal
                    function onTextChanged() { pcv.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    if (w <= 0 || h <= 0) return

                    // hand-ruled outer frame, same waver as the cards
                    ctx.strokeStyle = root.inkA(0.9)
                    ctx.lineWidth = 2.5
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(1.5, 1.5)
                    for (let x = 1.5; x < w; x += 11) ctx.lineTo(x, 1.5 + Math.sin(x * 0.07) * 1.1)
                    ctx.lineTo(w - 1.5, 1.5)
                    for (let y = 1.5; y < h; y += 11) ctx.lineTo(w - 1.5 + Math.sin(y * 0.08) * 1.1, y)
                    ctx.lineTo(w - 1.5, h - 1.5)
                    for (let x = w - 1.5; x > 1.5; x -= 11) ctx.lineTo(x, h - 1.5 + Math.sin(x * 0.06) * 1.1)
                    ctx.lineTo(1.5, h - 1.5)
                    ctx.closePath()
                    ctx.stroke()
                    // thin inner rule
                    ctx.strokeStyle = root.inkA(0.35)
                    ctx.lineWidth = 1
                    ctx.strokeRect(6.5, 6.5, w - 13, h - 13)

                    // screentone wedge, top-right (clear of the cards' torn corners)
                    ctx.fillStyle = root.inkA(0.10)
                    const rad = Math.min(w, h) * 0.30
                    for (let gy = 9; gy < rad; gy += 6) {
                        for (let gx = w - 9; gx > w - rad; gx -= 6) {
                            const dd = Math.hypot(w - gx, gy) / rad
                            if (dd > 1) continue
                            ctx.beginPath()
                            ctx.arc(gx + ((gy / 6) % 2 ? 3 : 0), gy, 1.3 * (1 - dd), 0, Math.PI * 2)
                            ctx.fill()
                        }
                    }
                }
            }

            // page number, bottom-center, like a tankōbon leaf
            Text {
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 8 }
                text: "— " + (page.panel ? page.panel.count : 0) + " —"
                color: root.inkA(0.45)
                font.family: root.pal.fontMono
                font.pixelSize: 8
                font.letterSpacing: 2
            }
        }
    }

    property Component backdrop: Component {
        Item {
            id: chassis
            property var note: null   // injected by the shell: urgency, accentCol, hovered

            readonly property int urg: note ? Number(note.urgency) : 1
            readonly property color splashCol: note && note.accentCol ? note.accentCol : root.pal.neon

            Canvas {
                id: cv
                anchors.fill: parent
                readonly property color tint: chassis.splashCol
                readonly property int urgLvl: chassis.urg
                readonly property bool hov: chassis.note ? chassis.note.hovered === true : false
                onTintChanged: requestPaint()
                onUrgLvlChanged: requestPaint()
                onHovChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: root.pal
                    function onTextChanged() { cv.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    if (w <= 0 || h <= 0) return
                    const notch = 13   // the torn corner, top-right

                    // hand-ruled border that routes around the tear
                    ctx.strokeStyle = root.inkA(cv.hov ? 0.95 : 0.85)
                    ctx.lineWidth = 2
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(1.5, 1.5)
                    for (let x = 1.5; x < w - notch; x += 9)
                        ctx.lineTo(x, 1.5 + Math.sin(x * 0.11) * 0.9)
                    // the tear: jagged steps into the corner
                    ctx.lineTo(w - notch, 3)
                    ctx.lineTo(w - notch * 0.55, notch * 0.45)
                    ctx.lineTo(w - notch * 0.75, notch * 0.7)
                    ctx.lineTo(w - 2, notch)
                    for (let y = notch; y < h - 2; y += 9)
                        ctx.lineTo(w - 1.5 + Math.sin(y * 0.13) * 0.9, y)
                    ctx.lineTo(w - 1.5, h - 1.5)
                    for (let x = w - 1.5; x > 2; x -= 9)
                        ctx.lineTo(x, h - 1.5 + Math.sin(x * 0.09) * 0.9)
                    ctx.lineTo(1.5, h - 1.5)
                    ctx.closePath()
                    ctx.stroke()
                    // paper shows white inside the tear
                    ctx.fillStyle = Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 1)
                    ctx.beginPath()
                    ctx.moveTo(w - notch, 0); ctx.lineTo(w, 0); ctx.lineTo(w, notch)
                    ctx.lineTo(w - notch * 0.75, notch * 0.7)
                    ctx.lineTo(w - notch * 0.55, notch * 0.45)
                    ctx.closePath()
                    ctx.fill()
                    ctx.strokeStyle = root.inkA(0.5)
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(w - notch, 1); ctx.lineTo(w - notch * 0.55, notch * 0.45)
                    ctx.lineTo(w - notch * 0.75, notch * 0.7); ctx.lineTo(w - 1, notch)
                    ctx.stroke()

                    // screentone shading, bottom-right corner
                    ctx.fillStyle = root.inkA(0.13)
                    const rad = Math.min(w, h) * 0.42
                    for (let gy = h - 5; gy > h - rad; gy -= 6) {
                        for (let gx = w - 5; gx > w - rad; gx -= 6) {
                            const dd = Math.hypot(w - gx, h - gy) / rad
                            if (dd > 1) continue
                            ctx.beginPath()
                            ctx.arc(gx + (((h - gy) / 6) % 2 ? 3 : 0), gy, 1.4 * (1 - dd), 0, Math.PI * 2)
                            ctx.fill()
                        }
                    }

                    // ── the splash: urgency written in blood on the spine ──
                    const t = cv.tint
                    const cx = 7, cy = h * 0.32
                    const r0 = cv.urgLvl >= 2 ? 8 : cv.urgLvl === 1 ? 5 : 2.8
                    ctx.fillStyle = Qt.rgba(t.r, t.g, t.b, 0.9)
                    // main blob, slightly lopsided
                    ctx.beginPath()
                    ctx.moveTo(cx - r0, cy)
                    ctx.quadraticCurveTo(cx - r0, cy - r0 * 1.15, cx, cy - r0)
                    ctx.quadraticCurveTo(cx + r0 * 1.2, cy - r0 * 0.8, cx + r0 * 0.9, cy + r0 * 0.3)
                    ctx.quadraticCurveTo(cx + r0 * 0.5, cy + r0 * 1.2, cx - r0 * 0.3, cy + r0 * 0.9)
                    ctx.quadraticCurveTo(cx - r0, cy + r0 * 0.6, cx - r0, cy)
                    ctx.closePath()
                    ctx.fill()
                    // a run of ink sliding down from the blob
                    ctx.fillRect(cx - 0.8, cy, 1.6, r0 * (cv.urgLvl >= 2 ? 4.5 : 2.6))
                    // satellites — more, and flung further, when critical
                    const sats = cv.urgLvl >= 2 ? 5 : cv.urgLvl === 1 ? 2 : 1
                    for (let i = 0; i < sats; i++) {
                        const a = 0.5 + i * 1.25
                        const dd = r0 * (1.6 + (i % 3) * 0.8)
                        ctx.beginPath()
                        ctx.arc(cx + Math.cos(a) * dd, cy + Math.sin(a) * dd,
                                1 + ((i + cv.urgLvl) % 3) * 0.7, 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
            }
        }
    }
}
