import QtQuick

// sakura: hanami chrome for pulse. The monitor's heartbeat is a single
// blossom in the footer corner that opens with CPU load — still air is a
// bud, a working machine is a full pink bloom, and past 85% it blushes
// rose (law 1: numbers are bloom). Sending a signal to a process is the
// violent moment: the blossom flings all five petals (law 2) and regrows.
// Everything gates on window focus.
Item {
    id: chrome

    required property var pal      // snapshot semantics — reload retints
    property var host: null        // active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host ? (host.load || 0) : 0

    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.94)
    readonly property color cardBorder: Qt.alpha(pal.neon, 0.28)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 14

    readonly property string wordmark: "❀ the tree keeps count"

    readonly property Component overlay: Component {
        Item {
            id: ov

            // the load blossom, bottom-right above the footer
            Canvas {
                id: heart
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 14; bottomMargin: 40 }
                width: 30; height: 30
                // ease toward the live load so the flower breathes, not twitches
                property real bloom: 0
                property real scatterT: 0
                Timer {
                    interval: 500; repeat: true
                    running: chrome.awake && ov.visible
                    onTriggered: heart.bloom = heart.bloom + (chrome.load - heart.bloom) * 0.4
                }
                onBloomChanged: requestPaint()
                onScatterTChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const r = 12, bl = Math.max(0.06, bloom)
                    const hot = bloom > 0.85
                    const col = hot ? chrome.pal.magenta : chrome.pal.neon
                    ctx.translate(width / 2, height / 2)
                    if (bl < 0.1 && scatterT === 0) {
                        ctx.beginPath()
                        ctx.arc(0, 0, 3.4, 0, 2 * Math.PI)
                        ctx.fillStyle = String(Qt.alpha(col, 0.75))
                        ctx.fill()
                        return
                    }
                    const pr = r * (0.4 + 0.6 * bl)
                    const w = pr * 0.55 * (0.55 + 0.45 * bl)
                    for (let i = 0; i < 5; i++) {
                        ctx.save()
                        ctx.rotate(i * Math.PI * 2 / 5)
                        if (scatterT > 0) {
                            ctx.translate(0, -r * 1.6 * scatterT)
                            ctx.rotate(scatterT * (i % 2 === 0 ? 1 : -1))
                            ctx.globalAlpha = Math.max(0, 1 - scatterT * 1.15)
                        }
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.bezierCurveTo(-w, -pr * 0.35, -w * 0.9, -pr * 0.85, -pr * 0.16, -pr * 0.97)
                        ctx.lineTo(0, -pr * 0.85)
                        ctx.lineTo(pr * 0.16, -pr * 0.97)
                        ctx.bezierCurveTo(w * 0.9, -pr * 0.85, w, -pr * 0.35, 0, 0)
                        ctx.closePath()
                        ctx.fillStyle = String(Qt.alpha(col, 0.55 + bl * 0.4))
                        ctx.fill()
                        ctx.restore()
                    }
                    ctx.globalAlpha = 1
                    ctx.beginPath()
                    ctx.arc(0, 0, 2.4, 0, 2 * Math.PI)
                    ctx.fillStyle = String(Qt.rgba(chrome.pal.text.r, chrome.pal.text.g, chrome.pal.text.b, 0.9))
                    ctx.fill()
                }

                // a kill scatters the petals — the one violent gesture
                Connections {
                    target: chrome.host
                    function onKillPulseChanged() { if (chrome.awake) scatter.restart() }
                }
                SequentialAnimation {
                    id: scatter
                    NumberAnimation { target: heart; property: "scatterT"; from: 0; to: 1; duration: 560; easing.type: Easing.OutSine }
                    NumberAnimation { target: heart; property: "scatterT"; to: 0; duration: 0 }
                }
            }
        }
    }
}
