import QtQuick

// guts: manga-page chrome for pulse — the campaign ledger. The sheet is
// printed once and holds still: pulp grain, the Brand-red spine broken at the
// gutter, halftone in the corner, and a tally of felled processes cut into
// the margin in blood. The page darkens as the machine strains — an ink wash
// riding the smoothed load, never a ticking loop. A re-sort flicks a shallow
// burst of speedlines; a kill is the sword coming down: one heavy arc of ink,
// a line of blood beside it, a flash — then the ink settles.
Item {
    id: chrome

    required property var pal
    property var host: null    // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0
    readonly property int kills: host && host.killPulse !== undefined ? host.killPulse : 0

    // heavy ink frame on paper
    readonly property color cardBorder: Qt.alpha(pal.text, 0.45)
    readonly property int cardBorderWidth: 2
    readonly property int cardRadius: 12

    readonly property string wordmark: "⚔ the struggle"

    readonly property Component backdrop: Component {
        Item {
            // pulp grain + ink vignette pressed into the sheet — no time
            // uniform, so this is a single static draw like a printed page
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("paper.frag.qsb")
            }

            // ink wash: the page roughens as the machine strains — a slow
            // bind on host.load, not a timer; an idle machine reads clean
            Rectangle {
                anchors.fill: parent
                color: chrome.pal.text
                opacity: chrome.load * 0.09
            }

            // the spine — brand red, with a break like a cut panel gutter;
            // it flushes darker as the load climbs
            Rectangle {
                x: 2; y: 14
                width: 3
                height: parent.height * 0.42
                color: Qt.alpha(chrome.pal.neon, 0.45 + chrome.load * 0.3)
            }
            Rectangle {
                x: 2
                y: parent.height * 0.42 + 34
                width: 3
                height: parent.height - y - 14
                color: Qt.alpha(chrome.pal.neon, 0.25 + chrome.load * 0.2)
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

            // the tally — every process felled this session is scratched into
            // the margin: four strokes and a cross-slash, in blood. repaints
            // only when the count moves (event-driven, never a loop)
            Canvas {
                id: tally
                property int marks: chrome.kills
                width: 240; height: 26
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 20; bottomMargin: 232 }
                onMarksChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const n = Math.min(marks, 30)
                    if (n === 0) return
                    ctx.strokeStyle = chrome.pal.neon
                    ctx.lineCap = "round"
                    ctx.lineWidth = 1.4
                    ctx.globalAlpha = 0.55
                    for (var i = 0; i < n; i++) {
                        const group = Math.floor(i / 5), inGroup = i % 5
                        const gx = width - 20 - group * 36   // grows leftward from the corner
                        ctx.beginPath()
                        if (inGroup < 4) {
                            // hand-cut: each stroke leans a hair differently
                            const x = gx + inGroup * 5
                            ctx.moveTo(x + ((i * 7) % 3 - 1), 4)
                            ctx.lineTo(x - 1, 21)
                        } else {
                            ctx.moveTo(gx - 5, 18); ctx.lineTo(gx + 20, 6)
                        }
                        ctx.stroke()
                    }
                }
            }
        }
    }

    readonly property Component overlay: Component {
        Item {
            // ── light: a re-sort flicks speedlines across the table — the
            // family burst, shallow and brief ──
            Canvas {
                id: flick
                anchors.fill: parent
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
                        const r0 = 200 + (i % 5) * 70
                        const r1 = Math.max(width, height) * 1.6
                        ctx.globalAlpha = 0.08 + (i % 3) * 0.04
                        ctx.lineWidth = 0.7 + (i % 4) * 0.4
                        ctx.beginPath()
                        ctx.moveTo(ox + Math.cos(ang) * r0, oy + Math.sin(ang) * r0)
                        ctx.lineTo(ox + Math.cos(ang) * r1, oy + Math.sin(ang) * r1)
                        ctx.stroke()
                    }
                }
            }

            // ── heavy: the kill. one bold arc from shoulder to hip — the
            // dragonslayer's path — thin follow-through streaks behind it,
            // and the cut opening red along the blade side ──
            Canvas {
                id: cut
                anchors.fill: parent
                opacity: 0
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    ctx.lineCap = "round"
                    // the cut itself
                    ctx.strokeStyle = chrome.pal.text
                    ctx.globalAlpha = 0.55
                    ctx.lineWidth = 5
                    ctx.beginPath()
                    ctx.moveTo(w * 0.86, -30)
                    ctx.quadraticCurveTo(w * 0.52, h * 0.46, w * 0.10, h + 30)
                    ctx.stroke()
                    // follow-through streaks riding the same arc
                    ctx.lineWidth = 1.4
                    for (var i = 1; i <= 3; i++) {
                        ctx.globalAlpha = 0.30 - i * 0.07
                        ctx.beginPath()
                        ctx.moveTo(w * 0.86 + i * 15, -30)
                        ctx.quadraticCurveTo(w * 0.52 + i * 15, h * 0.46, w * 0.10 + i * 15, h + 30)
                        ctx.stroke()
                    }
                    // the bleed — arterial red opening along the blade side
                    ctx.strokeStyle = chrome.pal.magenta
                    ctx.globalAlpha = 0.50
                    ctx.lineWidth = 2
                    ctx.beginPath()
                    ctx.moveTo(w * 0.86 - 8, -30)
                    ctx.quadraticCurveTo(w * 0.52 - 8, h * 0.46, w * 0.10 - 8, h + 30)
                    ctx.stroke()
                }
            }

            // brand flare — the whole page flushes red for a breath
            Rectangle {
                id: flare
                anchors.fill: parent
                color: chrome.pal.magenta
                opacity: 0
            }

            SequentialAnimation {
                id: sortFlick
                NumberAnimation { target: flick; property: "opacity"; to: 0.35; duration: 60 }
                NumberAnimation { target: flick; property: "opacity"; to: 0; duration: 360; easing.type: Easing.OutQuad }
            }
            ParallelAnimation {
                id: killStorm
                SequentialAnimation {
                    NumberAnimation { target: cut; property: "opacity"; to: 1; duration: 60 }
                    NumberAnimation { target: cut; property: "opacity"; to: 0; duration: 740; easing.type: Easing.OutQuad }
                }
                SequentialAnimation {
                    NumberAnimation { target: flare; property: "opacity"; to: 0.10; duration: 50 }
                    NumberAnimation { target: flare; property: "opacity"; to: 0; duration: 550; easing.type: Easing.OutQuad }
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onSortIdChanged() { if (chrome.awake) sortFlick.restart() }
                function onKillPulseChanged() { if (chrome.awake) killStorm.restart() }
            }
        }
    }
}
