import QtQuick

// lonely-train: the late carriage behind the miller columns — sodium lamplight
// pooling in the top-right corner, dusk blue settling at the floor, rain on the
// window while you ride, and the lights of a passing station sweeping across
// each time you step into a new folder.
Item {
    id: chrome

    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBorder: Qt.alpha(pal.neon, 0.20)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "🚃 night line"

    // ── rain on the window glass, over everything, while the window is awake ──
    readonly property Component overlay: Component {
        ShaderEffect {
            fragmentShader: Qt.resolvedUrl("rain.frag.qsb")
            property real time: 0
            NumberAnimation on time {
                from: 0; to: 3600; duration: 3600000
                loops: Animation.Infinite
                running: chrome.awake
            }
        }
    }

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // sodium lamp glow, top-right
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

            // dusk settling at the floor of the carriage
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 140
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.08) }
                }
            }

            // the passing station lights — one sweep each time you change folder
            Rectangle {
                id: beam
                width: 170
                height: parent.height * 1.3
                y: -parent.height * 0.15
                x: -width
                rotation: 10
                opacity: 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.alpha(chrome.pal.neon, 0.07) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                SequentialAnimation {
                    id: sweep
                    PropertyAction { target: beam; property: "opacity"; value: 1 }
                    NumberAnimation {
                        target: beam; property: "x"
                        from: -beam.width; to: bd.width + beam.width
                        duration: 3000
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
}
