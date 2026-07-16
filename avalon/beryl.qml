import QtQuick
import QtQuick.Particles

// avalon: errantry — the browser is the knight's wandering. the chrome bands
// are the meadow's edges: sunlight pools along the tab-strip canopy, a
// hedgerow of grass blades stands against the status-bar sill, and sun-bokeh
// with drifting petals lives behind the page, surfacing at the margins and in
// full wherever a stripped page runs transparent. every navigation is a new
// path taken — light runs the canopy once, then stillness. same grammar as
// mica.qml: invisible root, pal/host; both layers melt away in fullscreen.
Item {
    id: chrome

    required property var pal
    property var host: null    // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    // gold hairline, like avalon's lock panel edge
    readonly property color cardBorder: Qt.alpha(pal.cyan, 0.30)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "⚘ errantry"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // sun-bokeh behind the page — the meadow showing through
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("bokeh.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // sunlight pooling on the canopy — the tab strip's band of gold
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 96
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(chrome.pal.cyan, 0.06) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // moss rising off the sill, under the status bar
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 180
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.neon, 0.08) }
                }
            }

            // the hedgerow: grass blades standing along the very bottom edge,
            // each leaning where the wind set it — painted once, never stirred
            Canvas {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 24
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                function hash(n) { const v = Math.sin(n) * 43758.5453; return v - Math.floor(v) }
                onPaint: {
                    const ctx = getContext("2d")
                    const w = width, h = height
                    ctx.reset()
                    ctx.lineWidth = 1.2
                    ctx.lineCap = "round"
                    for (let x = 4; x < w - 4; x += 7) {
                        const r1 = hash(x * 12.9898), r2 = hash(x * 78.233)
                        const bh = 6 + r1 * 14              // blade height
                        const lean = (r2 - 0.5) * 8         // wind-set lean
                        ctx.beginPath()
                        ctx.moveTo(x, h)
                        ctx.quadraticCurveTo(x + lean * 0.3, h - bh * 0.6, x + lean, h - bh)
                        ctx.strokeStyle = r2 < 0.7 ? chrome.pal.neon : chrome.pal.dim
                        ctx.globalAlpha = 0.20 + r1 * 0.16
                        ctx.stroke()
                    }
                }
            }

            // sparse petals for the margins and the see-through pages
            ParticleSystem {
                id: sys
                running: true
                paused: !chrome.awake || !bd.visible
            }
            Emitter {
                system: sys
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                emitRate: 0.45
                lifeSpan: 18000
                velocity: AngleDirection {
                    angle: 95; magnitude: 42
                    angleVariation: 10; magnitudeVariation: 16
                }
            }
            Wander { system: sys; xVariance: 70; pace: 45 }
            ItemParticle {
                system: sys
                delegate: Rectangle {
                    width: 7; height: 5; radius: 2.5
                    rotation: Math.random() * 360
                    color: Math.random() < 0.6 ? Qt.alpha(chrome.pal.cyan, 0.40)   // buttercup
                                               : Qt.alpha(chrome.pal.text, 0.32)   // cream
                }
            }
        }
    }

    // ── the path taken: light runs the canopy once per navigation, along the
    // tab strip only, then the overlay holds perfectly still ──
    readonly property Component overlay: Component {
        Item {
            id: ov
            Item {
                id: canopy
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 130
                Rectangle {
                    id: sheen
                    width: 70
                    height: canopy.height * 1.6
                    y: -canopy.height * 0.3
                    x: -width
                    rotation: -16
                    opacity: 0
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.alpha(chrome.pal.cyan, 0.12) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }
            SequentialAnimation {
                id: glint
                PropertyAction { target: sheen; property: "opacity"; value: 1 }
                NumberAnimation {
                    target: sheen; property: "x"
                    from: -sheen.width; to: canopy.width + sheen.width
                    duration: 700
                    easing.type: Easing.InOutSine
                }
                PropertyAction { target: sheen; property: "opacity"; value: 0 }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) glint.restart() }
            }
        }
    }
}
