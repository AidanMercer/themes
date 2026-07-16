import QtQuick

// sailing: chart work — the dusk sea designed for beryl's chrome bands: the
// horizon blush rides up behind the tab strip, the deep water pools behind
// the status bar and the window margins, and the page sits on top like a
// chart laid over the water (it only shows mid-window when a transparent
// page lets it). deck chrome gathers at the stern: a taffrail + stanchions
// above the status line, the stern lamp in the opposite corner. every
// committed navigation is coming about — the whole sea rolls through the
// tack while the wake streams aft along the rail, then the water settles.
Item {
    id: chrome

    required property var pal
    property var host: null     // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBorder: Qt.alpha(pal.dim, 0.55)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 14   // porthole-round, the popup's corner

    readonly property string wordmark: "🧭 dead reckoning"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the whole sea in one pass — oversized so the come-about roll
            // never bares an edge; becalmed to a static draw when unfocused
            ShaderEffect {
                anchors.fill: parent
                anchors.margins: -30
                fragmentShader: Qt.resolvedUrl("sea.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake && bd.visible
                }
                // coming about: a committed navigation rolls the deck through
                // the tack and damp-settles back to level — one-shot
                SequentialAnimation on rotation {
                    id: comeAbout
                    running: false
                    NumberAnimation { from: -1.5; to: 0.85; duration: 440; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.85; to: -0.4; duration: 380; easing.type: Easing.InOutSine }
                    NumberAnimation { from: -0.4; to: 0; duration: 330; easing.type: Easing.OutSine }
                }
                Connections {
                    target: chrome.host
                    enabled: chrome.host !== null
                    function onNavIdChanged() { if (chrome.awake) comeAbout.restart() }
                }
            }

            // deck chrome at the stern, level while the sea rolls: the
            // taffrail runs in from the right above the status line, the
            // stern lamp burns bottom-left. one static draw — free at idle.
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
                    // taffrail: two hairlines + stanchion posts
                    const rw = w * 0.34, rx = w - 16 - rw, ry = h - 12
                    ctx.fillStyle = Qt.alpha(chrome.pal.text, 0.22)
                    ctx.fillRect(rx, ry, rw, 1)
                    ctx.fillStyle = Qt.alpha(chrome.pal.dim, 0.5)
                    ctx.fillRect(rx, ry + 4, rw, 1)
                    ctx.fillStyle = Qt.alpha(chrome.pal.text, 0.4)
                    for (let i = 0; i < 3; i++)
                        ctx.fillRect(rx + Math.round((rw - 2) * i / 2), ry, 2, 6)
                    // stern lamp: a brass point in a faint halo
                    const lx = 20, ly = h - 15
                    ctx.beginPath(); ctx.arc(lx, ly, 7, 0, Math.PI * 2)
                    ctx.fillStyle = Qt.alpha(chrome.pal.amber, 0.14); ctx.fill()
                    ctx.beginPath(); ctx.arc(lx, ly, 2.2, 0, Math.PI * 2)
                    ctx.fillStyle = Qt.alpha(chrome.pal.amber, 0.9); ctx.fill()
                }
            }
        }
    }

    // ── the wake: as she comes about the foam streams aft along the stern
    // band and dissolves — transient by design, nothing resident above the
    // page ──
    readonly property Component overlay: Component {
        Item {
            id: ov
            property real way: 0   // 1 the moment she answers the helm, 0 at rest
            visible: way > 0.01

            Repeater {
                model: 3
                Rectangle {
                    y: ov.height - 30 - index * 6
                    x: ov.width * (0.62 - 0.5 * ov.way + index * 0.05)
                    width: 54 + index * 22
                    height: 1.2
                    color: Qt.alpha(chrome.pal.text, (0.4 - index * 0.08) * ov.way)
                }
            }
            NumberAnimation {
                id: wake
                target: ov; property: "way"
                from: 1; to: 0; duration: 800
                easing.type: Easing.OutCubic
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) wake.restart() }
            }
        }
    }
}
