import QtQuick
import QtQuick.Particles

// sea spray — fine spindrift lifted off the swell, wandering hard in the
// wind; a lamp-lit fleck now and then off the deck
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
        group: "spray"
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: parent.height * 0.15
        emitRate: 3.2
        lifeSpan: 11000
        velocity: AngleDirection {
            angle: 285; magnitude: 34
            angleVariation: 18; magnitudeVariation: 18
        }
    }
    // brass lamp motes, rare, warm
    Emitter {
        system: sys
        group: "lamp"
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: parent.height * 0.1
        emitRate: 0.06
        lifeSpan: 14000
        velocity: AngleDirection { angle: 280; magnitude: 22; angleVariation: 12 }
    }
    Wander { system: sys; xVariance: 110; pace: 55 }

    ItemParticle {
        system: sys
        groups: ["spray"]
        delegate: Rectangle {
            width: (1.5 + Math.random() * 1.5) * root.s
            height: width; radius: width / 2
            color: Qt.alpha(root.pal.text, 0.18 + Math.random() * 0.22)
        }
    }
    ItemParticle {
        system: sys
        groups: ["lamp"]
        delegate: Rectangle {
            width: 3 * root.s; height: width; radius: width / 2
            color: Qt.alpha(root.pal.amber, 0.55)
        }
    }
}
