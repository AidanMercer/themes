import QtQuick
import QtQuick.Particles

// dust — a few periwinkle motes hanging in the glass, barely moving
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

    Emitter {
        system: sys
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 1
        emitRate: 0.8
        lifeSpan: 32000
        velocity: AngleDirection {
            angle: 270; magnitude: 10
            angleVariation: 12; magnitudeVariation: 6
        }
    }
    Wander { system: sys; xVariance: 50; pace: 20 }

    ItemParticle {
        system: sys
        delegate: Rectangle {
            width: (1.5 + Math.random() * 1.5) * root.s
            height: width; radius: width / 2
            color: Math.random() < 0.7 ? Qt.alpha(root.pal.neon, 0.30)
                                       : Qt.alpha(root.pal.cyan, 0.26)
        }
    }
}
