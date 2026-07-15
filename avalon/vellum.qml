import QtQuick
import QtQuick.Particles

// avalon: the meadow behind the page. While you're writing the field holds
// still — only the moss scrim at the sill and the gold hairline. Turn to the
// rendered page and the sun-bokeh drifts up again, buttercup petals fall, and a
// narrow gold sheen sweeps the glass as the page composes itself.
Item {
    id: chrome

    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : false
    // vellum is showing a page (markdown reading view / pdf) rather than a buffer
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    // scenery only moves for a page someone is actually looking at — never
    // behind the text column while it's being typed into
    readonly property bool stirring: awake && page

    // gold hairline, like avalon's lock panel edge
    readonly property color cardBorder: Qt.alpha(pal.cyan, 0.30)
    readonly property int cardBorderWidth: 1

    // ── excalibur glint: a narrow gold sheen sweeps once as the page turns ──
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
                opacity: 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.alpha(chrome.pal.cyan, 0.08) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                SequentialAnimation {
                    id: glint
                    PropertyAction { target: sheen; property: "opacity"; value: 1 }
                    NumberAnimation {
                        target: sheen; property: "x"
                        from: -sheen.width; to: ov.width + sheen.width
                        duration: 1400
                        easing.type: Easing.InOutSine
                    }
                    PropertyAction { target: sheen; property: "opacity"; value: 0 }
                }
                Connections {
                    target: chrome
                    function onPageChanged() { if (chrome.stirring) glint.restart() }
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
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.stirring
                }
            }

            // moss rising off the sill — the one constant, page or no page
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 220
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.neon, 0.07) }
                }
            }

            ParticleSystem {
                id: sys
                running: true
                paused: !chrome.stirring || !bd.visible
            }
            Emitter {
                system: sys
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                emitRate: 0.5
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
                    color: Math.random() < 0.6 ? Qt.alpha(chrome.pal.cyan, 0.35)   // buttercup
                                               : Qt.alpha("#f0ead0", 0.30)          // cream
                }
            }
        }
    }
}
