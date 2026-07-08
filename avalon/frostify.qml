import QtQuick
import QtQuick.Particles

// avalon: buttercup petals drift down the glass while frostify has your eye,
// over a faint moss scrim rising from the bottom — the meadow behind the panes.
Item {
    id: chrome

    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : false

    // gold hairline, like the lock panel's edge
    readonly property color cardBorder: Qt.alpha(pal.cyan, 0.30)
    readonly property int cardBorderWidth: 1

    // the meadow's voice
    readonly property string statusPlaying: "▶ IN BLOOM"
    readonly property string statusPaused: "⏸ RESTING"
    readonly property string statusStopped: "■ FALLOW"
    readonly property string wordmark: "⚘ avalon"
    readonly property string glyphPinned: "❀"
    readonly property string glyphPlaylist: "❧"
    readonly property string glyphRecent: "◷"
    readonly property string glyphDesktop: "⌂"

    readonly property bool playing: host && host.np
                                    && host.np.active === true && host.np.isPlaying === true

    // ── excalibur glint: a narrow gold sheen sweeps the glass now and then ──
    readonly property Component overlay: Component {
        Item {
            id: ov
            Rectangle {
                id: sheen
                width: 70
                height: parent.height * 1.5
                y: -parent.height * 0.25
                x: -width
                rotation: -16
                visible: glint.running
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.alpha(chrome.pal.cyan, 0.10) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                SequentialAnimation {
                    id: glint
                    running: chrome.playing && chrome.awake && ov.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: 16000 }
                    NumberAnimation {
                        target: sheen; property: "x"
                        from: -sheen.width; to: ov.width + sheen.width
                        duration: 1400
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // sun-bokeh drifting up through the glass
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("bokeh.frag.qsb")
                property real time: 0
                // `width`/`height` are the item's own — the shader keeps discs round
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.playing && chrome.awake
                }
            }

            // moss scrim anchoring the bottom, radial-ish via two stops
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 220
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.neon, 0.08) }
                }
            }

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
                    color: Math.random() < 0.6 ? Qt.alpha(chrome.pal.cyan, 0.45)   // buttercup
                                               : Qt.alpha("#f0ead0", 0.40)          // cream
                }
            }
        }
    }
}
