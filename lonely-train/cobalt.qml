import QtQuick

// lonely-train: the quiet car — cobalt is where the work calls happen, so the
// carriage keeps its head down. lamplight pools soft over the titlebar, dusk
// settles under the status line, the rain is barely a whisper on the stripped
// teams glass, and a station slides past — gently, half speed — whenever the
// rail changes channel. nothing here moves fast; the ride does the talking.
Item {
    id: chrome

    required property var pal
    property var host: null     // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property string wordmark: "🚃 quiet car"

    // ── the carriage, under the glass bars and the stripped teams regions ──
    readonly property Component backdrop: Component {
        Item {
            // sodium lamp glow, top-right — turned down for the quiet car
            Canvas {
                width: 340; height: 260
                anchors { top: parent.top; right: parent.right }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = ctx.createRadialGradient(width - 40, 20, 0, width - 40, 20, 300)
                    g.addColorStop(0, Qt.alpha(chrome.pal.neon, 0.10))
                    g.addColorStop(1, "transparent")
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                Component.onCompleted: requestPaint()
            }

            // dusk settling at the floor of the carriage
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 140
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.06) }
                }
            }

            // rain on the window, kept to a whisper — you're on a call
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("rain.frag.qsb")
                property real time: 0
                opacity: 0.55
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }
        }
    }

    // ── the station: a rail change pulls into one — its lights slide slow
    // and soft across the glass, then the quiet comes back ──
    readonly property Component overlay: Component {
        Item {
            id: ov
            Rectangle {
                id: beam
                width: 200
                height: parent.height * 1.3
                y: -parent.height * 0.15
                x: -width
                rotation: 10
                opacity: 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.alpha(chrome.pal.neon, 0.06) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            SequentialAnimation {
                id: sweep
                PropertyAction { target: beam; property: "opacity"; value: 1 }
                NumberAnimation {
                    target: beam; property: "x"
                    from: -beam.width; to: ov.width + beam.width
                    duration: 1100
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
