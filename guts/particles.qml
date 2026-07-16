import QtQuick
import QtQuick.Particles

// ink in the wind — halftone flecks torn off the page, driven sideways;
// once in a while one runs red
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
        group: "ink"
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: 1
        emitRate: 1.8
        lifeSpan: 20000
        velocity: AngleDirection {
            angle: 8; magnitude: 70
            angleVariation: 10; magnitudeVariation: 30
        }
    }
    Emitter {
        system: sys
        group: "blood"
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: 1
        emitRate: 0.06
        lifeSpan: 18000
        velocity: AngleDirection { angle: 10; magnitude: 80; angleVariation: 8 }
    }
    Wander { system: sys; yVariance: 40; pace: 45 }

    ItemParticle {
        system: sys
        groups: ["ink"]
        delegate: Rectangle {
            width: (2 + Math.random() * 2) * root.s
            height: width
            radius: width * 0.2
            rotation: Math.random() * 90
            color: Qt.alpha(root.pal.text, 0.30 + Math.random() * 0.25)
        }
    }
    ItemParticle {
        system: sys
        groups: ["blood"]
        delegate: Rectangle {
            width: 3.5 * root.s; height: width
            radius: width * 0.2
            rotation: Math.random() * 90
            color: Qt.alpha(root.pal.neon, 0.55)
        }
    }
}
