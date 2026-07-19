import QtQuick
import QtQuick.Particles

// encore: DUST IN THE BEAM. Two faint follow-spot cones lean in from the top
// of the stage — teal from stage-left, warm white from stage-right — and the
// only motion is the dust drifting down through them, catching the light and
// letting it go. The resting stage's whole life (law 3): sparse, dim, slow.
// Click-through scenery.
Item {
    id: root
    anchors.fill: parent
    required property var pal
    property bool occluded: false
    readonly property real s: (pal && pal.uiScale) ? pal.uiScale : 1

    readonly property color teal: pal.neon
    readonly property color spot: pal.amber

    // ── the beams: two static cones, one cheap paint ────────────────────────
    Canvas {
        id: beams
        anchors.fill: parent
        opacity: 0.5
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
        Connections {
            target: root.pal
            function onNeonChanged() { beams.requestPaint() }
            function onAmberChanged() { beams.requestPaint() }
        }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            function cone(x0, spread, drift, col, a) {
                // a beam from a rig point above the frame, widening downward
                const g = ctx.createLinearGradient(0, 0, 0, h * 0.9)
                g.addColorStop(0, Qt.rgba(col.r, col.g, col.b, a))
                g.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0))
                ctx.fillStyle = g
                ctx.beginPath()
                ctx.moveTo(x0 - w * 0.012, -4)
                ctx.lineTo(x0 + w * 0.012, -4)
                ctx.lineTo(x0 + drift + spread, h * 0.9)
                ctx.lineTo(x0 + drift - spread, h * 0.9)
                ctx.closePath()
                ctx.fill()
            }
            cone(w * 0.16, w * 0.10, w * 0.09, root.teal, 0.055)   // stage-left, teal
            cone(w * 0.80, w * 0.11, -w * 0.10, root.spot, 0.05)   // stage-right, warm
        }
    }

    // ── the dust ────────────────────────────────────────────────────────────
    ParticleSystem {
        id: sys
        running: true
        paused: root.occluded
    }

    // motes falling through the stage-left teal beam
    Emitter {
        system: sys
        group: "dustL"
        x: parent.width * 0.10
        y: -10
        width: parent.width * 0.16
        height: 1
        emitRate: 1.1
        lifeSpan: 26000
        velocity: AngleDirection {
            angle: 84; magnitude: 26
            angleVariation: 7; magnitudeVariation: 10
        }
    }
    // motes falling through the stage-right warm beam
    Emitter {
        system: sys
        group: "dustR"
        x: parent.width * 0.72
        y: -10
        width: parent.width * 0.18
        height: 1
        emitRate: 1.1
        lifeSpan: 26000
        velocity: AngleDirection {
            angle: 96; magnitude: 26
            angleVariation: 7; magnitudeVariation: 10
        }
    }

    ItemParticle {
        system: sys
        groups: ["dustL"]
        delegate: Rectangle {
            width: (Math.random() < 0.2 ? 3 : 2) * root.s
            height: width
            radius: width / 2
            color: Qt.alpha(root.teal, 0.8)
            opacity: 0
            // the mote catches the beam, then lets it go — slow, irregular
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: !root.occluded
                NumberAnimation { to: 0.06 + Math.random() * 0.16; duration: 2400 + Math.random() * 2800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.02; duration: 2400 + Math.random() * 2800; easing.type: Easing.InOutSine }
            }
        }
    }
    ItemParticle {
        system: sys
        groups: ["dustR"]
        delegate: Rectangle {
            width: (Math.random() < 0.2 ? 3 : 2) * root.s
            height: width
            radius: width / 2
            color: Qt.alpha(root.spot, 0.85)
            opacity: 0
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: !root.occluded
                NumberAnimation { to: 0.05 + Math.random() * 0.14; duration: 2600 + Math.random() * 3000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.02; duration: 2600 + Math.random() * 3000; easing.type: Easing.InOutSine }
            }
        }
    }
}
