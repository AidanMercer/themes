import QtQuick
import QtQuick.Particles

// sakura: the air under the canopy. A sparse fall of notched petals that
// tumble in three-quarter view as they drift down-right on the breeze, plus a
// few soft out-of-focus motes to match the wallpaper's bokeh. Still air is
// the law: counts stay low, one petal at a time is the mood.
Item {
    id: root
    anchors.fill: parent
    required property var pal
    property bool occluded: false
    readonly property real s: (pal && pal.uiScale) ? pal.uiScale : 1

    ParticleSystem {
        id: sys
        running: true
        paused: root.occluded
    }

    // petals let go from above, drifting down and to the right like the video's
    Emitter {
        system: sys
        group: "petal"
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        emitRate: 1.3
        lifeSpan: 21000
        velocity: AngleDirection {
            angle: 78; magnitude: 42
            angleVariation: 12; magnitudeVariation: 18
        }
    }
    // young sakura leaves — cherry leaves come out coppery-bronze — let go
    // from the branches crowding the left edge and fall close to home
    Emitter {
        system: sys
        group: "leaf"
        anchors { top: parent.top; left: parent.left }
        width: parent.width * 0.26
        height: 1
        emitRate: 0.8
        lifeSpan: 17000
        velocity: AngleDirection {
            angle: 84; magnitude: 52
            angleVariation: 10; magnitudeVariation: 16
        }
    }
    // blurry pale motes, deeper in the haze
    Emitter {
        system: sys
        group: "mote"
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        emitRate: 0.7
        lifeSpan: 26000
        velocity: AngleDirection {
            angle: 85; magnitude: 22
            angleVariation: 8; magnitudeVariation: 8
        }
    }
    Wander { system: sys; xVariance: 110; pace: 34 }

    ItemParticle {
        system: sys
        groups: ["petal"]
        delegate: Canvas {
            id: pc
            readonly property real r: (5 + Math.random() * 4) * root.s
            readonly property real a: 0.34 + Math.random() * 0.22
            width: r * 2.2; height: r * 2.2
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
                ctx.fillStyle = String(Qt.alpha(root.pal.neon, pc.a))
                ctx.fill()
            }
            Component.onCompleted: requestPaint()

            // the flutter: a slow tumble on a tilted axis so the petal
            // foreshortens and recovers — falling in 3/4 view, not spinning flat
            transform: Rotation {
                id: tumble
                origin.x: pc.width / 2
                origin.y: pc.height / 2
                axis { x: 1; y: 0.35; z: 0.2 }
                NumberAnimation on angle {
                    from: Math.random() * 360
                    to: Math.random() * 360 + (Math.random() < 0.5 ? 360 : -360)
                    duration: 7000 + Math.random() * 6000
                    loops: Animation.Infinite
                    running: !root.occluded
                }
            }
        }
    }
    ItemParticle {
        system: sys
        groups: ["leaf"]
        delegate: Canvas {
            id: lc
            readonly property real r: (6 + Math.random() * 4) * root.s
            readonly property real a: 0.30 + Math.random() * 0.20
            width: r * 2.4; height: r * 2.4
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.translate(width / 2, height / 2)
                // almond leaf: two arcs meeting at the tips, a vein up the middle
                ctx.beginPath()
                ctx.moveTo(0, r)
                ctx.quadraticCurveTo(-r * 0.62, 0, 0, -r)
                ctx.quadraticCurveTo(r * 0.62, 0, 0, r)
                ctx.closePath()
                ctx.fillStyle = String(Qt.alpha(root.pal.amber, lc.a))
                ctx.fill()
                ctx.beginPath()
                ctx.moveTo(0, r * 0.8)
                ctx.lineTo(0, -r * 0.8)
                ctx.strokeStyle = String(Qt.alpha(root.pal.amber, lc.a * 0.7))
                ctx.lineWidth = 0.8
                ctx.stroke()
            }
            Component.onCompleted: requestPaint()

            // leaves rock side to side as they fall rather than spinning flat
            transform: Rotation {
                origin.x: lc.width / 2
                origin.y: lc.height / 2
                axis { x: 0.5; y: 0.9; z: 0.3 }
                property real swing: 0
                angle: Math.sin(swing) * 70 + 20
                NumberAnimation on swing {
                    from: Math.random() * 6.28
                    to: Math.random() * 6.28 + 12.57
                    duration: 9000 + Math.random() * 7000
                    loops: Animation.Infinite
                    running: !root.occluded
                }
            }
        }
    }
    ItemParticle {
        system: sys
        groups: ["mote"]
        delegate: Rectangle {
            width: (3 + Math.random() * 3) * root.s
            height: width; radius: width / 2
            color: Math.random() < 0.5 ? Qt.alpha(root.pal.text, 0.12 + Math.random() * 0.10)
                                       : Qt.alpha(root.pal.cyan, 0.10 + Math.random() * 0.10)
        }
    }
}
