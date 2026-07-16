import QtQuick
import QtQuick.Particles

// vinland: the althing — where the crews meet to talk terms. the hall keeps
// its voice low: the aurora breathes at half the sky's usual pace and stays
// faint, only a little snow drifts past the eaves, and a carved beam runs
// under the floor line. a rail navigation is a speaker taking the stone —
// the north star over the door gives one quiet glint, nothing more. nothing
// here is ever louder than the person talking.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon=ice, cyan=gold, magenta=blood)
    property var host: null     // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property string wordmark: "❄ the althing"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // aurora at half pace, kept faint — it surfaces through the
            // stripped teams regions and barely through the glass bars
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("aurora.frag.qsb")
                property real time: 0
                opacity: 0.55
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 7200000   // half the sky's usual pace
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // faint frost at the foot of the hall
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 90
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.neon, 0.05) }
                }
            }

            // a little snow past the eaves — sparse by law of the hall
            ParticleSystem {
                id: sys
                running: true
                paused: !chrome.awake || !bd.visible
            }
            Emitter {
                system: sys
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                emitRate: 0.7
                lifeSpan: 22000
                velocity: AngleDirection {
                    angle: 90; magnitude: 22
                    angleVariation: 5; magnitudeVariation: 8
                }
            }
            Wander { system: sys; xVariance: 30; pace: 24 }
            ItemParticle {
                system: sys
                delegate: Rectangle {
                    width: Math.random() < 0.3 ? 3 : 2
                    height: width; radius: width / 2
                    color: Qt.alpha(chrome.pal.text, 0.10 + Math.random() * 0.16)
                }
            }

            // the carved beam over the floor line — a hairline with twig-rune
            // cuts leaning off it, sitting under the status glass
            Canvas {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 16
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = chrome.pal.neon
                    ctx.globalAlpha = 0.16
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(14, 8); ctx.lineTo(width - 14, 8)
                    ctx.stroke()
                    let side = 1
                    for (let x = 40; x < width - 30; x += 72) {
                        ctx.beginPath()
                        ctx.moveTo(x, 8); ctx.lineTo(x + 5, 8 - side * 5)
                        ctx.stroke()
                        side = -side
                    }
                }
            }

            // the north star over the door — the small diamond seal, not the
            // full cross; the hall wears its sign quietly
            Canvas {
                id: star
                width: 22; height: 22
                x: 16; y: 14
                opacity: 0.55
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const c = width / 2, R = width / 2 - 1
                    ctx.beginPath()
                    ctx.moveTo(c, c - R)
                    ctx.quadraticCurveTo(c, c, c + R, c)
                    ctx.quadraticCurveTo(c, c, c, c + R)
                    ctx.quadraticCurveTo(c, c, c - R, c)
                    ctx.quadraticCurveTo(c, c, c, c - R)
                    ctx.closePath()
                    ctx.fillStyle = chrome.pal.neon
                    ctx.globalAlpha = 0.9
                    ctx.fill()
                }
                Component.onCompleted: requestPaint()
                // a speaker takes the stone: one quiet glint
                SequentialAnimation {
                    id: glint
                    NumberAnimation { target: star; property: "scale"; to: 1.18; duration: 400; easing.type: Easing.OutQuad }
                    NumberAnimation { target: star; property: "scale"; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                }
                Connections {
                    target: chrome.host
                    enabled: chrome.host !== null
                    function onNavIdChanged() { if (chrome.awake) glint.restart() }
                }
            }
        }
    }
}
