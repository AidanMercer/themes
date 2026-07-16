import QtQuick
import QtQuick.Particles

// data static — neon ticks bleeding upward off the city grid, the odd
// horizontal glitch tearing across
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

    // rising ticks — heat off the net
    Emitter {
        system: sys
        group: "tick"
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 1
        emitRate: 2.2
        lifeSpan: 24000
        velocity: AngleDirection {
            angle: 270; magnitude: 34
            angleVariation: 4; magnitudeVariation: 16
        }
    }
    // glitch streaks — brief, anywhere, gone
    Emitter {
        system: sys
        group: "glitch"
        anchors.fill: parent
        emitRate: 0.25
        lifeSpan: 420
        velocity: AngleDirection { angle: 0; magnitude: 0 }
    }
    Wander { system: sys; xVariance: 24; pace: 60 }

    ItemParticle {
        system: sys
        groups: ["tick"]
        delegate: Rectangle {
            width: 1.5 * root.s
            height: (4 + Math.random() * 4) * root.s
            property real roll: Math.random()
            color: roll < 0.55 ? Qt.alpha(root.pal.neon, 0.40)
                 : roll < 0.90 ? Qt.alpha(root.pal.cyan, 0.38)
                               : Qt.alpha(root.pal.magenta, 0.42)
        }
    }
    ItemParticle {
        system: sys
        groups: ["glitch"]
        delegate: Rectangle {
            width: (26 + Math.random() * 50) * root.s
            height: 1.5 * root.s
            color: Qt.alpha(Math.random() < 0.5 ? root.pal.cyan : root.pal.magenta, 0.5)
            NumberAnimation on opacity { from: 1; to: 0; duration: 400 }
        }
    }
}
