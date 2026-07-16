import QtQuick
import QtQuick.Particles

// nature: the meadow reads the machine as weather. honey sunlight spills in
// from the top-left, and as host.load climbs the afternoon turns hot — the
// light runs amber, the air hazes at the sill, the pollen stirs faster.
// re-sorting the table sends a breeze through (rays lean and swell, pollen
// puffs); a kill is a cloud crossing the sun — the light drops, the meadow
// goes pine-dark for a beat, and the pollen scatters hard on the cold gust.
Item {
    id: chrome

    required property var pal
    property var host: null   // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0

    readonly property color cardBorder: Qt.alpha(pal.neon, 0.22)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "❀ heartwood"

    // a breeze crossing the meadow — one gust per re-sort
    property real gust: 0
    SequentialAnimation {
        id: gustAnim
        NumberAnimation { target: chrome; property: "gust"; from: 0; to: 1; duration: 260; easing.type: Easing.OutSine }
        NumberAnimation { target: chrome; property: "gust"; to: 0; duration: 640; easing.type: Easing.InOutSine }
    }

    // the cloud — a kill drags it across the sun, then it blows past
    property real shade: 0
    SequentialAnimation {
        id: cloudAnim
        NumberAnimation { target: chrome; property: "shade"; from: 0; to: 1; duration: 280; easing.type: Easing.OutSine }
        NumberAnimation { target: chrome; property: "shade"; to: 0; duration: 820; easing.type: Easing.InOutSine }
    }

    Connections {
        target: chrome.host
        enabled: chrome.host !== null
        function onSortIdChanged() { if (chrome.awake) gustAnim.restart() }
        function onKillPulseChanged() { if (chrome.awake) cloudAnim.restart() }
    }

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // sun flare, top-left — it dims while the cloud is over it
            Canvas {
                width: 380; height: 300
                opacity: 1 - chrome.shade * 0.7
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

            // the hot layer — the same sun gone amber as the machine strains
            Canvas {
                width: 380; height: 300
                opacity: chrome.load * (1 - chrome.shade)
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = ctx.createRadialGradient(40, 10, 0, 40, 10, 340)
                    g.addColorStop(0, Qt.alpha(chrome.pal.amber, 0.12))
                    g.addColorStop(0.55, Qt.alpha(chrome.pal.amber, 0.04))
                    g.addColorStop(1, "transparent")
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                Component.onCompleted: requestPaint()
            }

            // god-rays fanning out of the flare, shimmering while the window is
            // awake; a gust leans them over, the cloud all but puts them out
            ShaderEffect {
                id: rays
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("godray.frag.qsb")
                property real t0: 0
                property real time: t0 + chrome.gust * 9
                opacity: 1 - chrome.shade * 0.85
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
                opacity: chrome.gust * 0.8
                visible: chrome.gust > 0.01
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

            // heat haze off the ground — the air thickens as the load climbs
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: bd.height * 0.45
                opacity: chrome.load
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.amber, 0.10) }
                }
            }

            // pollen in the light — quicker on a straining machine, shaken
            // loose by the gust, scattered hard by the cloud's cold edge
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
                emitRate: 0.9 + chrome.load * 2.5 + chrome.gust * 22 + chrome.shade * 26
                lifeSpan: 12000
                velocity: AngleDirection {
                    angle: 60
                    magnitude: 9 + chrome.load * 10 + chrome.gust * 24 + chrome.shade * 30
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

    // the cloud's shadow lies over the gauges themselves — heavier toward the
    // sky, gone the moment it blows past
    readonly property Component overlay: Component {
        Rectangle {
            visible: chrome.shade > 0.01
            opacity: chrome.shade
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(chrome.pal.glass, 0.38) }
                GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.glass, 0.16) }
            }
        }
    }
}
