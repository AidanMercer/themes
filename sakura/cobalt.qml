import QtQuick

// sakura: hanami chrome for cobalt — deliberately the quietest room under
// the tree (calls happen here). The backdrop is only still light: canopy
// pink through the stripped Teams regions, dusk at the status line. The one
// moving thing is a single petal that crosses the top band when the SPA
// navigates, and even that sits out while a call might be up.
Item {
    id: chrome

    required property var pal      // snapshot semantics — reload retints
    property var host: null        // active, navId, loading, width/height

    readonly property bool awake: host ? host.active === true : false

    readonly property string wordmark: "❀"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 80
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(chrome.pal.neon, 0.07) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 60
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.glass, 0.4) }
                }
            }

            // one petal across the top band on navigation — nothing more
            Canvas {
                id: navPetal
                width: 13; height: 13
                property real t: 0
                visible: t > 0 && t < 1
                readonly property real px: bd.width * 0.2 + bd.width * 0.6 * t
                readonly property real py: 16 + 26 * t + 8 * Math.sin(t * 6)
                onTChanged: { x = px; y = py; rotation = t * 200; opacity = t < 0.7 ? 0.6 : 0.6 * (1 - (t - 0.7) / 0.3) }
                NumberAnimation on t {
                    id: drift
                    running: false
                    from: 0.01; to: 1
                    duration: 2600
                    easing.type: Easing.InOutSine
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const r = 5.5
                    ctx.translate(width / 2, height / 2)
                    ctx.beginPath()
                    ctx.moveTo(0, r * 0.5)
                    ctx.bezierCurveTo(-r * 0.8, 0, -r * 0.6, -r * 0.8, -r * 0.14, -r * 0.9)
                    ctx.lineTo(0, -r * 0.76)
                    ctx.lineTo(r * 0.14, -r * 0.9)
                    ctx.bezierCurveTo(r * 0.6, -r * 0.8, r * 0.8, 0, 0, r * 0.5)
                    ctx.closePath()
                    ctx.fillStyle = String(Qt.alpha(chrome.pal.neon, 0.8))
                    ctx.fill()
                }
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.host
                    function onNavIdChanged() { if (chrome.awake) drift.restart() }
                }
            }
        }
    }
}
