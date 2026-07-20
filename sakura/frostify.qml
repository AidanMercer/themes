import QtQuick
import QtQuick.Particles

// sakura: hanami chrome for frostify. The player sits under the canopy —
// warm pink light along the top of the glass, a sparse petal drift while a
// track is actually playing, and a small flurry shaken loose every time the
// track changes. Voice: playback states in the theme's dialect.
Item {
    id: chrome

    required property var pal      // snapshot semantics — reload retints
    property var host: null        // frostify's window: np, npTrackId, active…

    readonly property bool awake: host ? host.active === true : false
    readonly property bool spinning: host && host.np ? host.np.isPlaying === true : false

    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.93)
    readonly property color cardBorder: Qt.alpha(pal.neon, 0.30)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 16

    // the theme's dialect
    readonly property string wordmark: "❀ hanami"
    readonly property string statusPlaying: "❀ in bloom"
    readonly property string statusPaused: "· holding still"
    readonly property string statusStopped: "· quiet air"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // canopy light along the top of the window
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 120
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(chrome.pal.neon, 0.09) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            // dusk pooling at the sill
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 140
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.glass, 0.5) }
                }
            }

            ParticleSystem {
                id: sys
                running: true
                paused: !(chrome.awake && chrome.spinning) || !bd.visible
            }
            // the steady drift while music plays
            Emitter {
                system: sys
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                emitRate: 0.6
                lifeSpan: 16000
                velocity: AngleDirection {
                    angle: 80; magnitude: 34
                    angleVariation: 12; magnitudeVariation: 12
                }
            }
            // the flurry shaken loose on a track change
            Emitter {
                id: flurry
                system: sys
                enabled: false
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                lifeSpan: 9000
                velocity: AngleDirection {
                    angle: 82; magnitude: 60
                    angleVariation: 16; magnitudeVariation: 20
                }
            }
            Wander { system: sys; xVariance: 80; pace: 36 }
            Connections {
                target: chrome.host
                function onNpTrackIdChanged() { if (chrome.awake) flurry.burst(7) }
            }

            ItemParticle {
                system: sys
                delegate: Canvas {
                    id: pc
                    readonly property real r: 4 + Math.random() * 3.5
                    width: r * 2.2; height: r * 2.2
                    rotation: Math.random() * 360
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.translate(width / 2, height / 2)
                        ctx.beginPath()
                        ctx.moveTo(0, r * 0.5)
                        ctx.bezierCurveTo(-r * 0.8, 0, -r * 0.6, -r * 0.8, -r * 0.14, -r * 0.9)
                        ctx.lineTo(0, -r * 0.76)
                        ctx.lineTo(r * 0.14, -r * 0.9)
                        ctx.bezierCurveTo(r * 0.6, -r * 0.8, r * 0.8, 0, 0, r * 0.5)
                        ctx.closePath()
                        ctx.fillStyle = String(Qt.alpha(chrome.pal.neon, 0.30 + Math.random() * 0.2))
                        ctx.fill()
                    }
                    Component.onCompleted: requestPaint()
                }
            }
        }
    }
}
