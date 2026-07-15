import QtQuick

// guts: the manga page. The sheet itself never moves — pulp grain, the
// Brand-red spine, a halftone screen in the corner, all pressed under a heavy
// ink frame. The only event is the page turn: rendering a page cuts a burst of
// speedlines across the sheet, then the ink settles again.
Item {
    id: chrome

    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page

    // heavy ink frame on paper
    readonly property color cardBorder: Qt.alpha(pal.text, 0.45)
    readonly property int cardBorderWidth: 2
    readonly property int cardRadius: 12

    readonly property Component backdrop: Component {
        Item {
            // pulp grain + ink vignette pressed into the sheet — no time
            // uniform, so this is a single static draw like a printed page
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("paper.frag.qsb")
            }

            // the spine — brand red, with a break like a cut panel gutter
            Rectangle {
                x: 2; y: 14
                width: 3
                height: parent.height * 0.42
                color: Qt.alpha(chrome.pal.neon, 0.55)
            }
            Rectangle {
                x: 2
                y: parent.height * 0.42 + 34
                width: 3
                height: parent.height - y - 14
                color: Qt.alpha(chrome.pal.neon, 0.30)
            }

            // halftone screen, bottom-right
            Canvas {
                width: 300; height: 220
                anchors { right: parent.right; bottom: parent.bottom }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = chrome.pal.text
                    const step = 13
                    for (var gx = 0; gx < width; gx += step) {
                        for (var gy = 0; gy < height; gy += step) {
                            // dots grow toward the corner, thin out away from it
                            const t = Math.min(1, Math.hypot(width - gx, height - gy) / 320)
                            const r = (1 - t) * 2.4
                            if (r < 0.35) continue
                            ctx.globalAlpha = 0.10 * (1 - t) + 0.02
                            ctx.beginPath()
                            ctx.arc(gx + (gy % (step * 2) ? step / 2 : 0), gy, r, 0, Math.PI * 2)
                            ctx.fill()
                        }
                    }
                }
                Component.onCompleted: requestPaint()
            }
        }
    }

    // ── speedlines: ink rays flash from the right edge as the page turns ──
    readonly property Component overlay: Component {
        Canvas {
            id: lines
            opacity: 0
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const ox = width + 60, oy = height * 0.5
                ctx.strokeStyle = chrome.pal.text
                for (var i = 0; i < 30; i++) {
                    const ang = Math.PI * 0.62 + (i / 30) * Math.PI * 0.76
                    const r0 = 180 + (i % 5) * 60
                    const r1 = Math.max(width, height) * 1.6
                    ctx.globalAlpha = 0.10 + (i % 3) * 0.05
                    ctx.lineWidth = 0.8 + (i % 4) * 0.5
                    ctx.beginPath()
                    ctx.moveTo(ox + Math.cos(ang) * r0, oy + Math.sin(ang) * r0)
                    ctx.lineTo(ox + Math.cos(ang) * r1, oy + Math.sin(ang) * r1)
                    ctx.stroke()
                }
            }
            // shallower than mica's slash — this one lands over prose
            SequentialAnimation {
                id: slash
                NumberAnimation { target: lines; property: "opacity"; to: 0.55; duration: 70 }
                NumberAnimation { target: lines; property: "opacity"; to: 0; duration: 520; easing.type: Easing.OutQuad }
            }
            Connections {
                target: chrome
                function onPageChanged() { if (chrome.stirring) slash.restart() }
            }
        }
    }
}
