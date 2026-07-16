import QtQuick
import QtQuick.Particles

// forecourt drizzle — thin rain slanting through the canopy light, icy
// cyan-white; a stray orange fleck where the neon catches a drop
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
        group: "rain"
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        emitRate: 9
        lifeSpan: 7000
        velocity: AngleDirection {
            angle: 96; magnitude: 240
            angleVariation: 2; magnitudeVariation: 70
        }
    }
    Emitter {
        system: sys
        group: "glint"
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        emitRate: 0.12
        lifeSpan: 7000
        velocity: AngleDirection { angle: 96; magnitude: 220; magnitudeVariation: 40 }
    }

    ItemParticle {
        system: sys
        groups: ["rain"]
        delegate: Rectangle {
            width: 1 * root.s
            height: (6 + Math.random() * 5) * root.s
            rotation: 6
            color: Qt.alpha(root.pal.cyan, 0.16 + Math.random() * 0.20)
        }
    }
    ItemParticle {
        system: sys
        groups: ["glint"]
        delegate: Rectangle {
            width: 1.5 * root.s
            height: 8 * root.s
            rotation: 6
            color: Qt.alpha(root.pal.neon, 0.5)
        }
    }
}
