import QtQuick
import QtQuick.Particles

// vinland: the deck watch — pulse reads the ship's vitals under the night
// sky. the aurora burns brighter as the machine strains and the snow thickens
// into a squall; a tally stave down the port side fills notch by notch with
// the load, the last cuts running to blood. a re-sort sights the north star;
// a kill opens a wound in the sky — blood-gold flare, bled away in a breath.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon=ice, cyan=gold, magenta=blood)
    property var host: null     // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0

    readonly property color cardBorder: Qt.alpha(pal.neon, 0.22)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "❄ deck watch"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // aurora curtains — the sky burns brighter as the ship strains
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("aurora.frag.qsb")
                property real time: 0
                opacity: 0.72 + 0.28 * chrome.load
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
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

            // snowfall that thickens into a squall as the load climbs —
            // more flakes, a harder wind, the same night
            ParticleSystem {
                id: sys
                running: true
                paused: !chrome.awake || !bd.visible
            }
            Emitter {
                system: sys
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                emitRate: 1.4 + chrome.load * 2.4
                lifeSpan: 22000
                velocity: AngleDirection {
                    angle: 90; magnitude: 26 + chrome.load * 30
                    angleVariation: 6 + chrome.load * 10; magnitudeVariation: 10
                }
            }
            Wander { system: sys; xVariance: 40; pace: 30 }
            ItemParticle {
                system: sys
                delegate: Rectangle {
                    width: Math.random() < 0.3 ? 3 : 2
                    height: width; radius: width / 2
                    color: Qt.alpha(chrome.pal.text, 0.20 + Math.random() * 0.25)
                }
            }

            // the watch tally — a carved stave down the port side; a notch
            // fills for every tenth of strain, and the last two cut in blood
            Item {
                id: tally
                x: 8; width: 18; height: 170
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {   // the stave itself, a straight cut
                    x: 8; width: 1; height: parent.height
                    color: Qt.alpha(chrome.pal.neon, 0.30)
                }
                Repeater {
                    model: 9
                    Rectangle {
                        required property int index
                        readonly property bool lit: chrome.load >= (index + 1) / 10
                        x: 8; y: tally.height - 14 - index * 18
                        width: 8; height: 1
                        transformOrigin: Item.Left
                        rotation: index % 2 ? 205 : -25   // twig cuts, alternating sides
                        color: index >= 7 ? chrome.pal.magenta : chrome.pal.neon
                        opacity: lit ? 0.9 : 0.16
                        Behavior on opacity { NumberAnimation { duration: 350 } }
                    }
                }
            }

            // the north star, sighted at the masthead — a re-sort of the table
            // is the watch taking a fresh bearing, and the star glints for it
            Canvas {
                id: star
                width: 44; height: 44
                anchors { right: parent.right; top: parent.top; rightMargin: 18; topMargin: 16 }
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
                SequentialAnimation {
                    id: glint
                    NumberAnimation { target: star; property: "scale"; to: 1.25; duration: 450; easing.type: Easing.OutQuad }
                    NumberAnimation { target: star; property: "scale"; to: 1.0; duration: 750; easing.type: Easing.InOutQuad }
                }
                Connections {
                    target: chrome.host
                    enabled: chrome.host !== null
                    function onSortIdChanged() { if (chrome.awake) glint.restart() }
                }
            }
        }
    }

    // ── the kill: the aurora flares blood-gold above the gauges — a wound
    // opened in the sky, bled out inside a breath, then the night again ──
    readonly property Component overlay: Component {
        Item {
            Rectangle {
                id: veil
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: parent.height * 0.55
                opacity: 0
                visible: opacity > 0.01   // transient by design — nothing resident over the table
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(chrome.pal.magenta, 0.42) }
                    GradientStop { position: 0.38; color: Qt.alpha(chrome.pal.cyan, 0.12) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            SequentialAnimation {
                id: bloodFlare
                NumberAnimation { target: veil; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutQuad }
                NumberAnimation { target: veil; property: "opacity"; to: 0; duration: 950; easing.type: Easing.InQuad }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onKillPulseChanged() { if (chrome.awake) bloodFlare.restart() }
            }
        }
    }
}
