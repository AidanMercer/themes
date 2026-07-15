import QtQuick
import QtQuick.Particles

// vinland: the night sea behind the page. Frost gathers at the sill and the
// north star holds the corner whatever you're doing; the aurora only breathes
// and the snow only falls over a page, and the star glints once as it composes.
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

            // aurora curtains — animated only over a page
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("aurora.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.stirring
                }
            }

            // frost mist along the bottom
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 150
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.neon, 0.07) }
                }
            }

            // slow snowfall
            ParticleSystem {
                id: sys
                running: true
                paused: !chrome.stirring || !bd.visible
            }
            Emitter {
                system: sys
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                emitRate: 1.6
                lifeSpan: 22000
                velocity: AngleDirection {
                    angle: 90; magnitude: 26
                    angleVariation: 6; magnitudeVariation: 10
                }
            }
            Wander { system: sys; xVariance: 40; pace: 30 }
            ItemParticle {
                system: sys
                delegate: Rectangle {
                    width: Math.random() < 0.3 ? 3 : 2
                    height: width; radius: width / 2
                    color: Qt.alpha(chrome.pal.text, 0.16 + Math.random() * 0.22)
                }
            }

            // the north star — a carved four-point cross, top-left
            Canvas {
                id: star
                width: 44; height: 44
                x: 30; y: 26
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const c = width / 2
                    ctx.strokeStyle = chrome.pal.neon
                    ctx.lineCap = "round"
                    ctx.globalAlpha = 0.55
                    ctx.lineWidth = 1.6
                    ctx.beginPath()
                    ctx.moveTo(c, c - 16); ctx.lineTo(c, c + 16)
                    ctx.moveTo(c - 12, c); ctx.lineTo(c + 12, c)
                    ctx.stroke()
                    ctx.globalAlpha = 0.9
                    ctx.fillStyle = chrome.pal.text
                    ctx.beginPath(); ctx.arc(c, c, 1.6, 0, Math.PI * 2); ctx.fill()
                }
                Component.onCompleted: requestPaint()
                // a quiet glint as the page composes
                SequentialAnimation {
                    id: glint
                    NumberAnimation { target: star; property: "scale"; to: 1.25; duration: 500; easing.type: Easing.OutQuad }
                    NumberAnimation { target: star; property: "scale"; to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                }
                Connections {
                    target: chrome
                    function onPageChanged() { if (chrome.stirring) glint.restart() }
                }
            }
        }
    }
}
