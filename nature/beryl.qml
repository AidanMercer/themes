import QtQuick
import QtQuick.Particles

// nature: the meadow at the window's edges — the page covers the middle, so
// the light lives in the chrome bands: honey flare in the tab strip's corner,
// god-rays leaning across the margins (they only cross the middle when a page
// runs transparent), and a grass-blade hedgerow rooted in the status bar.
// every tab switch or committed navigation is a step down the footpath — a
// breeze leans the rays, sways the hedge, and lifts a puff of pollen.
Item {
    id: chrome

    required property var pal
    property var host: null   // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBorder: Qt.alpha(pal.neon, 0.22)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "❀ footpath"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // a breeze crossing the meadow — one gust per step down the path
            property real gust: 0
            SequentialAnimation {
                id: gustAnim
                NumberAnimation { target: bd; property: "gust"; from: 0; to: 1; duration: 260; easing.type: Easing.OutSine }
                NumberAnimation { target: bd; property: "gust"; to: 0; duration: 640; easing.type: Easing.InOutSine }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) gustAnim.restart() }
            }

            // sun flare in the tab strip's corner
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

            // god-rays fanning out of the flare, shimmering while the window is
            // awake — they graze the tab strip and the margins, and only reach
            // mid-window where a transparent page lets the glass show
            ShaderEffect {
                id: rays
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("godray.frag.qsb")
                property real t0: 0
                property real time: t0 + bd.gust * 9
                NumberAnimation on t0 {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // the same rays doubled up for the length of the gust — the light swells
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("godray.frag.qsb")
                property real time: rays.time
                opacity: bd.gust * 0.8
                visible: bd.gust > 0.01
            }

            // leaf-green ground at the sill — the status bar is the meadow's edge
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 130
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.09) }
                }
            }

            // the hedgerow: grass blades rooted in the status bar, leaning as
            // one when the breeze comes through (drawn once, swayed cheap)
            Canvas {
                id: hedge
                width: bd.width + 12
                height: 30
                y: bd.height - height
                x: -6 + bd.gust * 6
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.lineWidth = 1.2
                    const n = Math.floor(width / 18)
                    for (let i = 0; i < n; i++) {
                        // deterministic scatter so a repaint never reseeds the hedge
                        const s = Math.abs(Math.sin(i * 12.9898) * 43758.5453) % 1
                        const bx = i * 18 + s * 14
                        const bh = 10 + s * 16
                        const lean = (s - 0.5) * 10
                        ctx.beginPath()
                        ctx.moveTo(bx, height)
                        ctx.quadraticCurveTo(bx + lean * 0.3, height - bh * 0.6, bx + lean, height - bh)
                        ctx.strokeStyle = Qt.alpha(chrome.pal.cyan, 0.14 + s * 0.14)
                        ctx.stroke()
                    }
                }
            }

            // pollen crossing the tab strip, sinking behind the page
            ParticleSystem {
                id: sys
                running: true
                paused: !chrome.awake || !bd.visible
            }
            Emitter {
                system: sys
                x: 0; y: 0
                width: bd.width
                height: 90
                emitRate: 0.6 + bd.gust * 18   // the gust shakes pollen off the stems
                lifeSpan: 10000
                velocity: AngleDirection {
                    angle: 80; magnitude: 7 + bd.gust * 20
                    angleVariation: 40; magnitudeVariation: 5
                }
            }
            Wander { system: sys; xVariance: 26; yVariance: 18; pace: 18 }
            ItemParticle {
                system: sys
                delegate: Rectangle {
                    width: 3; height: 3; radius: 1.5
                    color: Qt.alpha(chrome.pal.neon, 0.28 + Math.random() * 0.2)
                }
            }
        }
    }
}
