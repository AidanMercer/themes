import QtQuick

// lonely-train: the window seat — beryl is the ride, every page the view from
// the glass. the carriage lives in the chrome bands the page leaves bare:
// sodium lamplight pools over the tab strip, dusk settles under the status
// bar, rain runs in the margins (and across any page that keeps its glass
// transparent), and a little route map ticks along the top edge — one more
// stop lights up with every navigation, because every navigation pulls into
// a station: its lights sweep the window and are gone before the doors open.
Item {
    id: chrome

    required property var pal
    property var host: null     // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBorder: Qt.alpha(pal.neon, 0.20)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "🚃 window seat"

    // ── the carriage, under the chrome — designed for the bands: tab strip,
    // the seam beneath it, the status bar, the window margins ──
    readonly property Component backdrop: Component {
        Item {
            // sodium lamp glow over the tab strip, top-right
            Canvas {
                width: 340; height: 260
                anchors { top: parent.top; right: parent.right }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = ctx.createRadialGradient(width - 40, 20, 0, width - 40, 20, 300)
                    g.addColorStop(0, Qt.alpha(chrome.pal.neon, 0.13))
                    g.addColorStop(1, "transparent")
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                Component.onCompleted: requestPaint()
            }

            // dusk settling at the floor, under the status bar
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 140
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.08) }
                }
            }

            // the route map above the carriage door — a thin line of stations
            // along the top edge; the lit stop advances every navigation,
            // one more station toward home
            Canvas {
                id: route
                property int stop: 0
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 12
                onStopChanged: requestPaint()
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    const w = width, y = 6.5, x0 = 34, x1 = w * 0.40, stops = 5
                    const cur = route.stop % stops
                    ctx.reset()
                    ctx.strokeStyle = Qt.alpha(chrome.pal.cyan, 0.30)
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(x0, y); ctx.lineTo(x1, y)
                    ctx.stroke()
                    for (let i = 0; i < stops; i++) {
                        const x = x0 + (x1 - x0) * i / (stops - 1)
                        ctx.beginPath()
                        ctx.arc(x, y, i === cur ? 2.4 : 1.6, 0, Math.PI * 2)
                        ctx.fillStyle = i === cur ? Qt.alpha(chrome.pal.neon, 0.75)
                                                  : Qt.alpha(chrome.pal.cyan, 0.45)
                        ctx.fill()
                    }
                }
                Connections {
                    target: chrome.host
                    enabled: chrome.host !== null
                    function onNavIdChanged() { route.stop = route.stop + 1 }
                }
            }

            // rain on the glass — full window; the page scrim covers the
            // middle seat, so it reads in the chrome bands and wherever a
            // page runs transparent
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("rain.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }
        }
    }

    // ── the station: every navigation pulls into one — lights sweep the
    // window above the page, then the glass goes dark again ──
    readonly property Component overlay: Component {
        Item {
            id: ov
            Rectangle {
                id: beam
                width: 190
                height: parent.height * 1.3
                y: -parent.height * 0.15
                x: -width
                rotation: 10
                opacity: 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.45; color: Qt.alpha(chrome.pal.neon, 0.10) }
                    GradientStop { position: 0.55; color: Qt.alpha(chrome.pal.text, 0.05) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            SequentialAnimation {
                id: sweep
                PropertyAction { target: beam; property: "opacity"; value: 1 }
                NumberAnimation {
                    target: beam; property: "x"
                    from: -beam.width; to: ov.width + beam.width
                    duration: 950
                    easing.type: Easing.InOutSine
                }
                PropertyAction { target: beam; property: "opacity"; value: 0 }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) sweep.restart() }
            }
        }
    }
}
