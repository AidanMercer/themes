import QtQuick
import QtQuick.Particles

// nature: the clearing — this is where the meetings happen, so the meadow
// keeps its voice down. the honey flare and one slow, low god-ray shimmer
// surface through teams' stripped glass; the air holds perfectly still
// between navigations. a rail switch — chat, calendar, activity — sends a
// single soft breeze through the clearing: the rays lean and brighten, a few
// pollen motes lift, and then everything settles again.
Item {
    id: chrome

    required property var pal
    property var host: null   // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property string wordmark: "❀ clearing"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // a breeze through the clearing — one gust per rail navigation
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

            // sun flare, top-left — softer here than in the other rooms
            Canvas {
                width: 380; height: 300
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = ctx.createRadialGradient(40, 10, 0, 40, 10, 340)
                    g.addColorStop(0, Qt.alpha(chrome.pal.neon, 0.09))
                    g.addColorStop(0.55, Qt.alpha(chrome.pal.neon, 0.03))
                    g.addColorStop(1, "transparent")
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                Component.onCompleted: requestPaint()
            }

            // god-rays kept low and slow — the only thing that moves between
            // navigations, and only while the window is awake
            ShaderEffect {
                id: rays
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("godray.frag.qsb")
                property real t0: 0
                property real time: t0 + bd.gust * 9
                opacity: 0.55
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
                opacity: bd.gust * 0.6
                visible: bd.gust > 0.01
            }

            // leaf-green ground at the sill
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 110
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.07) }
                }
            }

            // pollen only rides the gust — the air in the clearing holds still
            // through a call, so the emitter rests at zero between breezes
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
                emitRate: bd.gust * 12
                lifeSpan: 8000
                velocity: AngleDirection {
                    angle: 60; magnitude: 8 + bd.gust * 18
                    angleVariation: 180; magnitudeVariation: 5
                }
            }
            Wander { system: sys; xVariance: 24; yVariance: 24; pace: 16 }
            ItemParticle {
                system: sys
                delegate: Rectangle {
                    width: 3; height: 3; radius: 1.5
                    color: Qt.alpha(chrome.pal.neon, 0.22 + Math.random() * 0.16)
                }
            }
        }
    }
}
