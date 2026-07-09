import QtQuick
import QtQuick.Particles

// nature: late-afternoon meadow behind the miller columns — honey sunlight
// spilling in from the top-left and a few pollen motes drifting through the
// beam while the window is awake.
Item {
    id: chrome

    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBorder: Qt.alpha(pal.neon, 0.22)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "❀ meadow"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // sun flare, top-left
            Canvas {
                width: 380; height: 300
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = ctx.createRadialGradient(40, 10, 0, 40, 10, 340)
                    g.addColorStop(0, Qt.alpha(chrome.pal.neon, 0.13))
                    g.addColorStop(0.55, Qt.alpha(chrome.pal.neon, 0.04))
                    g.addColorStop(1, "transparent")
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                Component.onCompleted: requestPaint()
            }

            // god-rays fanning out of the flare, shimmering while the window is awake
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("godray.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // leaf-green ground at the sill
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 130
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.09) }
                }
            }

            // pollen in the light
            ParticleSystem {
                id: sys
                running: true
                paused: !chrome.awake || !bd.visible
            }
            Emitter {
                system: sys
                x: 0; y: 0
                width: bd.width * 0.5
                height: bd.height * 0.5
                emitRate: 0.9
                lifeSpan: 12000
                velocity: AngleDirection {
                    angle: 60; magnitude: 9
                    angleVariation: 180; magnitudeVariation: 6
                }
            }
            Wander { system: sys; xVariance: 30; yVariance: 30; pace: 20 }
            ItemParticle {
                system: sys
                delegate: Rectangle {
                    width: 3; height: 3; radius: 1.5
                    color: Qt.alpha(chrome.pal.neon, 0.30 + Math.random() * 0.2)
                }
            }
        }
    }
}
