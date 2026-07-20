import QtQuick

// sakura: hanami chrome for beryl. The page covers the middle, so the theme
// lives in the chrome bands: canopy light bleeding down from the tab strip,
// a pink hairline seam under it, dusk along the status bar — and each
// committed navigation lets one petal fall down the window's right margin
// (law 2: the page turn is a petal released). Backdrop only, click-through.
Item {
    id: chrome

    required property var pal      // snapshot semantics — reload retints
    property var host: null        // active, fs, navId, width/height

    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.94)
    readonly property color cardBorder: Qt.alpha(pal.neon, 0.28)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 12

    readonly property string wordmark: "❀ out on the wind"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // canopy light down from the tab strip
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 64
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(chrome.pal.neon, 0.10) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            // the seam under the tab strip
            Rectangle {
                anchors { left: parent.left; right: parent.right }
                y: 40
                height: 1
                color: Qt.alpha(chrome.pal.neon, 0.22)
            }
            // dusk along the status bar
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 46
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.glass, 0.5) }
                }
            }

            // the petal that falls down the right margin on navigation
            Canvas {
                id: navPetal
                width: 15; height: 15
                property real t: 0
                visible: t > 0 && t < 1
                readonly property real px: bd.width - 22 - 10 * Math.sin(t * 5)
                readonly property real py: 34 + (bd.height - 90) * t * t
                onTChanged: { x = px; y = py; rotation = t * 240; opacity = t < 0.7 ? 0.85 : 0.85 * (1 - (t - 0.7) / 0.3) }
                NumberAnimation on t {
                    id: fall
                    running: false
                    from: 0.01; to: 1
                    duration: 2200
                    easing.type: Easing.InSine
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const r = 6.5
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
