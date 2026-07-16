import QtQuick

// guts: manga-page chrome for cobalt — the war council's page. Deliberately
// the quietest sheet in the theme, because this is the app the calls happen
// in: pulp grain under the glass bars, the Brand-red spine broken at the
// gutter, one caption rule under the titlebar, a whisper of halftone in the
// corner. Nothing moves at rest. A rail hop turns the page — a sparse flick
// of speedlines, shallower and shorter than anywhere else — then still again.
Item {
    id: chrome

    required property var pal
    property var host: null    // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property string wordmark: "⚔ war council"

    readonly property Component backdrop: Component {
        Item {
            // pulp grain + ink vignette pressed into the sheet — no time
            // uniform, so this is a single static draw like a printed page
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("paper.frag.qsb")
            }

            // the spine — brand red, gutter break; dimmer here than the
            // rest of the family — the council keeps its voice down
            Rectangle {
                x: 2; y: 14
                width: 3
                height: parent.height * 0.42
                color: Qt.alpha(chrome.pal.neon, 0.42)
            }
            Rectangle {
                x: 2
                y: parent.height * 0.42 + 34
                width: 3
                height: parent.height - y - 14
                color: Qt.alpha(chrome.pal.neon, 0.22)
            }

            // a single caption rule under the titlebar, like the box above
            // a panel that says where the scene is
            Rectangle {
                x: 16; y: 10
                width: parent.width * 0.30
                height: 1
                color: Qt.alpha(chrome.pal.text, 0.30)
            }

            // halftone whisper, bottom-right — smaller and fainter than the
            // family screen
            Canvas {
                width: 180; height: 130
                anchors { right: parent.right; bottom: parent.bottom }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = chrome.pal.text
                    const step = 13
                    for (var gx = 0; gx < width; gx += step) {
                        for (var gy = 0; gy < height; gy += step) {
                            // dots grow toward the corner, thin out away from it
                            const t = Math.min(1, Math.hypot(width - gx, height - gy) / 210)
                            const r = (1 - t) * 2.0
                            if (r < 0.35) continue
                            ctx.globalAlpha = 0.07 * (1 - t) + 0.015
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

    // ── the page turn, restrained: a rail hop flicks a sparse handful of
    // speedlines over the page, then the sheet holds still again ──
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
                for (var i = 0; i < 14; i++) {
                    const ang = Math.PI * 0.66 + (i / 14) * Math.PI * 0.68
                    const r0 = 220 + (i % 5) * 70
                    const r1 = Math.max(width, height) * 1.6
                    ctx.globalAlpha = 0.06 + (i % 3) * 0.03
                    ctx.lineWidth = 0.7 + (i % 3) * 0.4
                    ctx.beginPath()
                    ctx.moveTo(ox + Math.cos(ang) * r0, oy + Math.sin(ang) * r0)
                    ctx.lineTo(ox + Math.cos(ang) * r1, oy + Math.sin(ang) * r1)
                    ctx.stroke()
                }
            }
            SequentialAnimation {
                id: slash
                NumberAnimation { target: lines; property: "opacity"; to: 0.35; duration: 60 }
                NumberAnimation { target: lines; property: "opacity"; to: 0; duration: 380; easing.type: Easing.OutQuad }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) slash.restart() }
            }
        }
    }
}
