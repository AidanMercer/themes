import QtQuick

// guts: manga-page chrome for beryl — the page is a panel. Ink frame strokes
// hand-ruled into the window margins (each one overshoots its corner the way
// a loaded nib does), the Brand-red spine broken at the gutter, pulp grain
// that surfaces wherever a page runs transparent, halftone under the status
// line. Everything lives in the chrome bands — the page scrim owns the
// center. Static at rest; the only motion is the page turn: a navigation
// slashes speedlines across the sheet, one of them in blood, then the ink
// settles.
Item {
    id: chrome

    required property var pal
    property var host: null    // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    // heavy ink frame on paper
    readonly property color cardBorder: Qt.alpha(pal.text, 0.45)
    readonly property int cardBorderWidth: 2
    readonly property int cardRadius: 12

    readonly property string wordmark: "⚔ wanderer"

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

            // the panel frame — heavy strokes ruled in the margins, riding
            // under the tab strip and status bar; corners overshoot like
            // hand-inked panel borders. drawn once, never moves
            Canvas {
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height, m = 12, over = 10
                    ctx.strokeStyle = chrome.pal.text
                    ctx.lineCap = "square"
                    // outer strokes — each runs past its corners
                    ctx.lineWidth = 2.2
                    ctx.globalAlpha = 0.40
                    ctx.beginPath(); ctx.moveTo(m - over, m); ctx.lineTo(w - m + over, m); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(m - over, h - m); ctx.lineTo(w - m + over, h - m); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(m, m - over); ctx.lineTo(m, h - m + over); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(w - m, m - over); ctx.lineTo(w - m, h - m + over); ctx.stroke()
                    // thin inner rule, clean
                    ctx.lineWidth = 1
                    ctx.globalAlpha = 0.16
                    ctx.strokeRect(m + 5, m + 5, w - (m + 5) * 2, h - (m + 5) * 2)
                }
            }

            // halftone screen tucked under the status line, bottom-right
            Canvas {
                width: 260; height: 120
                anchors { right: parent.right; bottom: parent.bottom }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = chrome.pal.text
                    const step = 13
                    for (var gx = 0; gx < width; gx += step) {
                        for (var gy = 0; gy < height; gy += step) {
                            // dots grow toward the corner, thin out away from it
                            const t = Math.min(1, Math.hypot(width - gx, height - gy) / 260)
                            const r = (1 - t) * 2.2
                            if (r < 0.35) continue
                            ctx.globalAlpha = 0.09 * (1 - t) + 0.02
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

    // ── the page turn: navigation slashes speedlines from the right edge,
    // above the page — one stroke in blood among the ink — then quiet ──
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
                for (var i = 0; i < 30; i++) {
                    const ang = Math.PI * 0.62 + (i / 30) * Math.PI * 0.76
                    const r0 = 180 + (i % 5) * 60
                    const r1 = Math.max(width, height) * 1.6
                    // one ray runs red — the drop of blood on the page
                    ctx.strokeStyle = (i === 12) ? chrome.pal.neon : chrome.pal.text
                    ctx.globalAlpha = (i === 12) ? 0.22 : 0.10 + (i % 3) * 0.05
                    ctx.lineWidth = 0.8 + (i % 4) * 0.5
                    ctx.beginPath()
                    ctx.moveTo(ox + Math.cos(ang) * r0, oy + Math.sin(ang) * r0)
                    ctx.lineTo(ox + Math.cos(ang) * r1, oy + Math.sin(ang) * r1)
                    ctx.stroke()
                }
            }
            // lands over live pages — a shade gentler than mica's slash
            SequentialAnimation {
                id: slash
                NumberAnimation { target: lines; property: "opacity"; to: 0.6; duration: 70 }
                NumberAnimation { target: lines; property: "opacity"; to: 0; duration: 500; easing.type: Easing.OutQuad }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) slash.restart() }
            }
        }
    }
}
