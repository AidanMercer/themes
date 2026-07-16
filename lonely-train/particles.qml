import QtQuick
import QtQuick.Particles

// passing lights — the world sliding by the carriage window: sodium lamps
// near, dusk-blue town lights far, everything moving one way
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

    // far lights — small, slow, cold blue
    Emitter {
        system: sys
        group: "far"
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: 1
        emitRate: 0.9
        lifeSpan: 60000
        velocity: AngleDirection {
            angle: 180; magnitude: 46
            angleVariation: 2; magnitudeVariation: 12
        }
    }
    // near lamps — bigger sodium bokeh, sliding past faster
    Emitter {
        system: sys
        group: "near"
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: 1
        emitRate: 0.35
        lifeSpan: 30000
        velocity: AngleDirection {
            angle: 180; magnitude: 130
            angleVariation: 1; magnitudeVariation: 30
        }
    }
    // the odd signal lamp
    Emitter {
        system: sys
        group: "signal"
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: 1
        emitRate: 0.05
        lifeSpan: 30000
        velocity: AngleDirection { angle: 180; magnitude: 110; magnitudeVariation: 20 }
    }

    ItemParticle {
        system: sys
        groups: ["far"]
        delegate: Rectangle {
            width: (2 + Math.random() * 1.5) * root.s
            height: width; radius: width / 2
            color: Qt.alpha(root.pal.cyan, 0.22 + Math.random() * 0.16)
        }
    }
    ItemParticle {
        system: sys
        groups: ["near"]
        delegate: Rectangle {
            width: (5 + Math.random() * 4) * root.s
            height: width; radius: width / 2
            color: Qt.alpha(root.pal.neon, 0.20 + Math.random() * 0.18)
            border.color: Qt.alpha(root.pal.neon, 0.14)
            border.width: 1
        }
    }
    ItemParticle {
        system: sys
        groups: ["signal"]
        delegate: Rectangle {
            width: 4 * root.s; height: width; radius: width / 2
            color: Qt.alpha(root.pal.magenta, 0.5)
        }
    }
}
