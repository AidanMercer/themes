import QtQuick

// sailing: dusk at sea behind the miller columns — a lavender horizon low in
// the frame and one long swell rolling through it while the window is awake;
// the water goes still when you look away. Stepping into a new directory
// takes a swell: the whole sea rolls a degree or two and damp-settles back
// to level. Deck chrome stays level while it does — a railing rule under the
// breadcrumb row and a brass masthead lamp in the top-right corner, drawn
// once and left alone.
Item {
    id: chrome

    required property var pal
    property var host: null     // mica window — active (focus), navId (cwd)

    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBorder: Qt.alpha(pal.dim, 0.55)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 14   // porthole-round, the popup's corner

    readonly property string wordmark: "⚓ adrift"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the whole sea in one pass: horizon blush, rolling wave contours,
            // deep water at the hull — becalmed to a static draw when you look
            // away. Oversized so the swell roll never bares an edge.
            ShaderEffect {
                id: sea
                anchors.fill: parent
                anchors.margins: -28
                fragmentShader: Qt.resolvedUrl("sea.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake && bd.visible
                }
                // the swell: a new directory rolls the deck, then it steadies —
                // one-shot, same damping the wheelhouse card takes on reveal
                SequentialAnimation on rotation {
                    id: swell
                    running: false
                    NumberAnimation { from: -1.4; to: 0.8; duration: 420; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.8; to: -0.35; duration: 360; easing.type: Easing.InOutSine }
                    NumberAnimation { from: -0.35; to: 0; duration: 320; easing.type: Easing.OutSine }
                }
                Connections {
                    target: chrome.host
                    enabled: chrome.host !== null
                    function onNavIdChanged() { if (chrome.awake) swell.restart() }
                }
            }

            // deck chrome, level while the sea rolls: the railing rule under
            // the breadcrumb row + the masthead lamp top-right. One static
            // draw — costs nothing at idle.
            Canvas {
                id: deck
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    const w = width
                    ctx.reset()
                    // railing: two hairlines + stanchion posts, sysinfo's rule
                    const rx = 16, rw = w * 0.38, ry = 9
                    ctx.fillStyle = Qt.alpha(chrome.pal.text, 0.22)
                    ctx.fillRect(rx, ry, rw, 1)
                    ctx.fillStyle = Qt.alpha(chrome.pal.dim, 0.5)
                    ctx.fillRect(rx, ry + 4, rw, 1)
                    ctx.fillStyle = Qt.alpha(chrome.pal.text, 0.4)
                    for (let i = 0; i < 3; i++)
                        ctx.fillRect(rx + Math.round((rw - 2) * i / 2), ry, 2, 6)
                    // masthead lamp: a brass point in a faint halo
                    const lx = w - 20, ly = 13
                    ctx.beginPath(); ctx.arc(lx, ly, 7, 0, Math.PI * 2)
                    ctx.fillStyle = Qt.alpha(chrome.pal.amber, 0.14); ctx.fill()
                    ctx.beginPath(); ctx.arc(lx, ly, 2.2, 0, Math.PI * 2)
                    ctx.fillStyle = Qt.alpha(chrome.pal.amber, 0.9); ctx.fill()
                }
            }
        }
    }
}
