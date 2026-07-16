import QtQuick
import QtQuick.Particles

// wisteria fall — a few petals loosed across the paper, drifting down-left
// like ink flecks; restraint is the motif
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

    // seed from the top and right edges so the diagonal drift covers the page
    Emitter {
        system: sys
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        emitRate: 0.9
        lifeSpan: 30000
        velocity: AngleDirection {
            angle: 115; magnitude: 24
            angleVariation: 8; magnitudeVariation: 10
        }
    }
    Emitter {
        system: sys
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: 1
        emitRate: 0.5
        lifeSpan: 30000
        velocity: AngleDirection {
            angle: 130; magnitude: 26
            angleVariation: 8; magnitudeVariation: 10
        }
    }
    Wander { system: sys; xVariance: 30; yVariance: 14; pace: 22 }

    ItemParticle {
        system: sys
        delegate: Rectangle {
            width: (5 + Math.random() * 3) * root.s
            height: width * 0.62
            radius: height / 2
            color: Math.random() < 0.6 ? Qt.alpha(root.pal.neon, 0.55)   // wisteria
                                       : Qt.alpha(root.pal.cyan, 0.45)   // blush
            property real r0: Math.random() * 360
            rotation: r0
            NumberAnimation on rotation {
                from: r0; to: r0 + (Math.random() < 0.5 ? 360 : -360)
                duration: 16000 + Math.random() * 8000
                loops: Animation.Infinite
                running: !root.occluded
            }
        }
    }
}
