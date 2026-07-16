import QtQuick
import QtQuick.Particles

// nature: late-afternoon meadow — honey sunlight spilling in from the top-left
// and a few pollen motes drifting through the beam while the music plays. a
// track change sends a breeze through: the rays lean and swell, and a puff of
// pollen lifts.
Item {
    id: chrome

    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : false
    readonly property bool playing: host && host.np
                                    && host.np.active === true && host.np.isPlaying === true

    readonly property color cardBorder: Qt.alpha(pal.neon, 0.22)
    readonly property int cardBorderWidth: 1

    // the meadow hums
    readonly property string statusPlaying: "▶ ABLOOM"
    readonly property string statusPaused: "⏸ HUSH"
    readonly property string statusStopped: "■ STILL"
    readonly property string wordmark: "❀ meadow"
    readonly property string glyphPinned: "🌼"
    readonly property string glyphPlaylist: "🌿"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // a breeze crossing the meadow — one gust per track change
            property real gust: 0
            SequentialAnimation {
                id: gustAnim
                NumberAnimation { target: bd; property: "gust"; from: 0; to: 1; duration: 260; easing.type: Easing.OutSine }
                NumberAnimation { target: bd; property: "gust"; to: 0; duration: 640; easing.type: Easing.InOutSine }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNpTrackIdChanged() { if (chrome.host.npTrackId) gustAnim.restart() }
            }

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

            // god-rays fanning out of the flare, shimmering while music plays;
            // the gust leans the beams over, then lets them settle back
            ShaderEffect {
                id: rays
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("godray.frag.qsb")
                property real t0: 0
                property real time: t0 + bd.gust * 9
                NumberAnimation on t0 {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.playing && chrome.awake
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

            // leaf-green ground at the sill
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 130
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.09) }
                }
            }

            // pollen in the light — still air while the music holds its breath
            ParticleSystem {
                id: sys
                running: true
                paused: !chrome.playing || !chrome.awake || !bd.visible
            }
            Emitter {
                system: sys
                x: 0; y: 0
                width: bd.width * 0.5
                height: bd.height * 0.5
                emitRate: 0.9 + bd.gust * 22   // the gust shakes pollen off the stems
                lifeSpan: 12000
                velocity: AngleDirection {
                    angle: 60; magnitude: 9 + bd.gust * 24
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
