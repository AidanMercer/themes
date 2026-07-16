import QtQuick

// sailing: the radio watch — cobalt is where the calls happen, so the sea is
// becalmed: the same dusk water at a third of the pace and thinner light,
// surfacing through teams' stripped regions and faintly through the glass
// bars. an anchor light burns steady above the deck, a short railing rule
// over the status line. a rail switch is the only motion the watch allows —
// the boat swings gently on her cable, half a degree, and steadies.
// standing by on channel 16.
Item {
    id: chrome

    required property var pal
    property var host: null     // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property string wordmark: "⚓ standing by on 16"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the sea, becalmed: a third of the pace, a flat anchorage rather
            // than open water — and a static draw the moment focus leaves
            ShaderEffect {
                anchors.fill: parent
                anchors.margins: -16
                fragmentShader: Qt.resolvedUrl("sea.frag.qsb")
                opacity: 0.62
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 1200; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake && bd.visible
                }
                // a rail switch swings the bow gently — half a degree out and
                // back, the wake of a passing boat crossing the anchorage
                SequentialAnimation on rotation {
                    id: comeAbout
                    running: false
                    NumberAnimation { from: -0.5; to: 0.25; duration: 420; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.25; to: 0; duration: 460; easing.type: Easing.OutSine }
                }
                Connections {
                    target: chrome.host
                    enabled: chrome.host !== null
                    function onNavIdChanged() { if (chrome.awake) comeAbout.restart() }
                }
            }

            // the anchor light + a short railing rule over the status line —
            // one static draw, the only chrome the watch carries
            Canvas {
                id: deck
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    const w = width, h = height
                    ctx.reset()
                    // railing: two hairlines + stanchion posts, left-run
                    const rx = 14, rw = w * 0.26, ry = h - 11
                    ctx.fillStyle = Qt.alpha(chrome.pal.text, 0.2)
                    ctx.fillRect(rx, ry, rw, 1)
                    ctx.fillStyle = Qt.alpha(chrome.pal.dim, 0.45)
                    ctx.fillRect(rx, ry + 4, rw, 1)
                    ctx.fillStyle = Qt.alpha(chrome.pal.text, 0.35)
                    for (let i = 0; i < 3; i++)
                        ctx.fillRect(rx + Math.round((rw - 2) * i / 2), ry, 2, 6)
                    // anchor light: a brass point in a faint halo, top-right
                    const lx = w - 18, ly = 12
                    ctx.beginPath(); ctx.arc(lx, ly, 6, 0, Math.PI * 2)
                    ctx.fillStyle = Qt.alpha(chrome.pal.amber, 0.12); ctx.fill()
                    ctx.beginPath(); ctx.arc(lx, ly, 2, 0, Math.PI * 2)
                    ctx.fillStyle = Qt.alpha(chrome.pal.amber, 0.85); ctx.fill()
                }
            }
        }
    }
}
