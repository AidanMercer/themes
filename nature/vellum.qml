import QtQuick
import QtQuick.Particles

// nature: late-afternoon meadow behind the page. Honey sunlight spills in from
// the top-left and the leaf-green ground sits at the sill all day; the god-rays
// only shimmer and the pollen only drifts once you've stopped typing and the
// page is up. a page turning in sends a breeze through: the rays lean and
// swell, and a puff of pollen lifts.
Item {
    id: chrome

    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page

    readonly property color cardBorder: Qt.alpha(pal.neon, 0.22)
    readonly property int cardBorderWidth: 1

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // a breeze crossing the meadow — one gust per page turn
            property real gust: 0
            SequentialAnimation {
                id: gustAnim
                NumberAnimation { target: bd; property: "gust"; from: 0; to: 1; duration: 260; easing.type: Easing.OutSine }
                NumberAnimation { target: bd; property: "gust"; to: 0; duration: 640; easing.type: Easing.InOutSine }
            }
            Connections {
                target: chrome
                function onPageChanged() { if (chrome.stirring) gustAnim.restart() }
            }

            // sun flare, top-left
            Canvas {
                width: 380; height: 300
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = ctx.createRadialGradient(40, 10, 0, 40, 10, 340)
                    g.addColorStop(0, Qt.alpha(chrome.pal.neon, 0.11))
                    g.addColorStop(0.55, Qt.alpha(chrome.pal.neon, 0.035))
                    g.addColorStop(1, "transparent")
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                Component.onCompleted: requestPaint()
            }

            // god-rays fanning out of the flare, shimmering only over a page;
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
                    running: chrome.stirring
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
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.08) }
                }
            }

            // pollen in the light
            ParticleSystem {
                id: sys
                running: true
                paused: !chrome.stirring || !bd.visible
            }
            Emitter {
                system: sys
                x: 0; y: 0
                width: bd.width * 0.5
                height: bd.height * 0.5
                emitRate: 0.7 + bd.gust * 22   // the gust shakes pollen off the stems
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
                    color: Qt.alpha(chrome.pal.neon, 0.25 + Math.random() * 0.2)
                }
            }
        }
    }
}
