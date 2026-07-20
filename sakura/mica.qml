import QtQuick

// sakura: hanami chrome for mica. The miller columns browse under the same
// canopy: pink light along the top, dusk at the sill, and every directory
// change lets one petal go — a single notched petal falls across the glass
// and fades (law 2: navigation is a petal released). Focus-gated; a mica
// window in the background holds perfectly still.
Item {
    id: chrome

    required property var pal      // snapshot semantics — reload retints
    property var host: null        // mica's window: active, navId, width/height

    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.93)
    readonly property color cardBorder: Qt.alpha(pal.neon, 0.28)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 14

    readonly property string wordmark: "❀ drifting through"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 90
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(chrome.pal.neon, 0.08) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 110
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.glass, 0.45) }
                }
            }

            // the one petal released on each directory change
            Canvas {
                id: navPetal
                width: 16; height: 16
                property real t: 0
                visible: t > 0 && t < 1
                readonly property real px: bd.width * 0.5 + bd.width * 0.3 * t
                readonly property real py: -10 + (bd.height * 0.7) * t * t + 24 * Math.sin(t * 4)
                onTChanged: { x = px; y = py; rotation = t * 260; opacity = t < 0.7 ? 0.8 : 0.8 * (1 - (t - 0.7) / 0.3) }
                NumberAnimation on t {
                    id: fall
                    running: false
                    from: 0.01; to: 1
                    duration: 2400
                    easing.type: Easing.InSine
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const r = 7
                    ctx.translate(width / 2, height / 2)
                    ctx.beginPath()
                    ctx.moveTo(0, r * 0.5)
                    ctx.bezierCurveTo(-r * 0.8, 0, -r * 0.6, -r * 0.8, -r * 0.14, -r * 0.9)
                    ctx.lineTo(0, -r * 0.76)
                    ctx.lineTo(r * 0.14, -r * 0.9)
                    ctx.bezierCurveTo(r * 0.6, -r * 0.8, r * 0.8, 0, 0, r * 0.5)
                    ctx.closePath()
                    ctx.fillStyle = String(Qt.alpha(chrome.pal.neon, 0.85))
                    ctx.fill()
                }
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.host
                    function onNavIdChanged() { if (chrome.awake) fall.restart() }
                }
            }
        }
    }
}
