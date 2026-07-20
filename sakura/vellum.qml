import QtQuick
import QtQuick.Particles

// sakura: hanami chrome for vellum. While you write, the tree holds its
// breath — only the still canopy light at the top and dusk at the sill. Turn
// to a rendered page (or a pdf) and the air moves again: a slow petal drift
// behind the text, and one petal released as each page composes. Backdrop
// only — the glyphs stay crisp above the scenery.
Item {
    id: chrome

    required property var pal      // snapshot semantics — reload retints
    property var host: null        // active, activePane, readingMode, pdfMode

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    // the only thing that may animate: a page someone is actually reading
    readonly property bool stirring: awake && page

    readonly property color cardBorder: Qt.alpha(pal.neon, 0.26)
    readonly property int cardBorderWidth: 1

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the still constants: canopy light + dusk sill
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 90
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(chrome.pal.neon, 0.07) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 130
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.glass, 0.4) }
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
                emitRate: 0.45
                lifeSpan: 17000
                velocity: AngleDirection {
                    angle: 80; magnitude: 30
                    angleVariation: 10; magnitudeVariation: 10
                }
            }
            // the petal released as the page composes — one-shot burst,
            // fired on page (not stirring) so alt-tab doesn't re-fire it
            Emitter {
                id: turn
                system: sys
                enabled: false
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                lifeSpan: 10000
                velocity: AngleDirection {
                    angle: 84; magnitude: 46
                    angleVariation: 14; magnitudeVariation: 14
                }
            }
            Wander { system: sys; xVariance: 60; pace: 30 }
            Connections {
                target: chrome
                function onPageChanged() { if (chrome.stirring) turn.burst(3) }
            }

            ItemParticle {
                system: sys
                delegate: Canvas {
                    id: pc
                    readonly property real r: 4 + Math.random() * 3
                    width: r * 2.2; height: r * 2.2
                    rotation: Math.random() * 360
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.translate(width / 2, height / 2)
                        ctx.beginPath()
                        ctx.moveTo(0, r * 0.5)
                        ctx.bezierCurveTo(-r * 0.8, 0, -r * 0.6, -r * 0.8, -r * 0.14, -r * 0.9)
                        ctx.lineTo(0, -r * 0.76)
                        ctx.lineTo(r * 0.14, -r * 0.9)
                        ctx.bezierCurveTo(r * 0.6, -r * 0.8, r * 0.8, 0, 0, r * 0.5)
                        ctx.closePath()
                        ctx.fillStyle = String(Qt.alpha(chrome.pal.neon, 0.22 + Math.random() * 0.16))
                        ctx.fill()
                    }
                    Component.onCompleted: requestPaint()
                }
            }
        }
    }
}
