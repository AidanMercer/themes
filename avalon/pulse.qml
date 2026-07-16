import QtQuick
import QtQuick.Particles

// avalon: the meadow keeps vigil over the sleeping machine. the sun-bokeh
// drifts like it always does — the sun doesn't care how hard the cores work —
// but the breeze reads the cpu: petals fall straight and sparse over an idle
// meadow, then stream sideways when the cores burn, and the moss on the sill
// dries to hay. re-sorting the table turns the wind (a soft glint crosses the
// glass); killing a process draws the blade — one hard gold slash, rust at
// its edges, and a storm of petals scattered from the cut. same grammar as
// mica.qml: invisible root, pulse mounts backdrop below and overlay above.
Item {
    id: chrome

    required property var pal
    property var host: null    // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0

    // gold hairline, like avalon's lock panel edge
    readonly property color cardBorder: Qt.alpha(pal.cyan, 0.30)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "⚘ keeping vigil"

    // ── the meadow behind the gauges: serene sun, weather-vane petals ──
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // sun-bokeh drifting up through the glass, indifferent to the load
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

            // moss on the sill — the constant
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 220
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.neon, 0.07) }
                }
            }

            // …which dries to hay as the machine heats — the load, made weather
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 220
                opacity: chrome.load
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.amber, 0.12) }
                }
            }

            // the breeze reads the cpu: calm fall at idle, sideways stream at full burn
            ParticleSystem {
                id: sys
                running: true
                paused: !chrome.awake || !bd.visible
            }
            Emitter {
                system: sys
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                emitRate: 0.5 + chrome.load * 2.8
                lifeSpan: 16000
                velocity: AngleDirection {
                    angle: 95 - chrome.load * 30
                    magnitude: 38 + chrome.load * 90
                    angleVariation: 10; magnitudeVariation: 16
                }
            }
            Wander { system: sys; xVariance: 60 + chrome.load * 80; pace: 45 + chrome.load * 110 }
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

    // ── events above the panels: a re-sort turns the wind; a kill draws the blade ──
    readonly property Component overlay: Component {
        Item {
            id: ov

            // soft glint — the wind turning over the table
            Rectangle {
                id: sheen
                width: 50
                height: parent.height * 1.5
                y: -parent.height * 0.25
                x: -width
                rotation: -16
                opacity: 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.alpha(chrome.pal.cyan, 0.07) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            SequentialAnimation {
                id: sortGlint
                PropertyAction { target: sheen; property: "opacity"; value: 1 }
                NumberAnimation {
                    target: sheen; property: "x"
                    from: -sheen.width; to: ov.width + sheen.width
                    duration: 650
                    easing.type: Easing.InOutSine
                }
                PropertyAction { target: sheen; property: "opacity"; value: 0 }
            }

            // the blade — bright gold with rust at the edges, faster than the eye
            Rectangle {
                id: slash
                width: 90
                height: parent.height * 1.6
                y: -parent.height * 0.3
                x: -width
                rotation: -16
                opacity: 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.35; color: Qt.alpha(chrome.pal.magenta, 0.10) }
                    GradientStop { position: 0.5; color: Qt.alpha(chrome.pal.cyan, 0.26) }
                    GradientStop { position: 0.65; color: Qt.alpha(chrome.pal.magenta, 0.10) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // petals scattered from the cut, catching the air as they slow
            ParticleSystem {
                id: stormSys
                running: true
                paused: !chrome.awake || !ov.visible
            }
            Emitter {
                id: storm
                system: stormSys
                enabled: false      // only ever burst by the blade
                anchors.centerIn: parent
                width: 60; height: 60
                lifeSpan: 1000
                lifeSpanVariation: 400
                velocity: AngleDirection {
                    angle: 0; angleVariation: 360
                    magnitude: 260; magnitudeVariation: 120
                }
            }
            Friction { system: stormSys; factor: 1.4 }
            ItemParticle {
                system: stormSys
                delegate: Rectangle {
                    width: 7; height: 5; radius: 2.5
                    rotation: Math.random() * 360
                    color: Math.random() < 0.5 ? Qt.alpha(chrome.pal.magenta, 0.50)   // rust
                                               : Qt.alpha(chrome.pal.cyan, 0.45)      // buttercup
                }
            }

            SequentialAnimation {
                id: bladeStorm
                ScriptAction { script: storm.burst(26) }
                PropertyAction { target: slash; property: "opacity"; value: 1 }
                NumberAnimation {
                    target: slash; property: "x"
                    from: -slash.width; to: ov.width + slash.width
                    duration: 480
                    easing.type: Easing.InOutQuart
                }
                PropertyAction { target: slash; property: "opacity"; value: 0 }
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onSortIdChanged() { if (chrome.awake) sortGlint.restart() }
                function onKillPulseChanged() { if (chrome.awake) bladeStorm.restart() }
            }
        }
    }
}
