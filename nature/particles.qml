import QtQuick
import QtQuick.Particles

// pollen & fireflies — honey-gold motes climbing through the god-rays,
// each one breathing slow
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
        group: "pollen"
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 1
        emitRate: 1.5
        lifeSpan: 28000
        velocity: AngleDirection {
            angle: 270; magnitude: 14
            angleVariation: 12; magnitudeVariation: 8
        }
    }
    // sage dust, barely there, sinking the other way
    Emitter {
        system: sys
        group: "dust"
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        emitRate: 0.7
        lifeSpan: 30000
        velocity: AngleDirection {
            angle: 90; magnitude: 10
            angleVariation: 10; magnitudeVariation: 6
        }
    }
    Wander { system: sys; xVariance: 70; pace: 26 }

    ItemParticle {
        system: sys
        groups: ["pollen"]
        delegate: Rectangle {
            width: (2.5 + Math.random() * 1.5) * root.s
            height: width; radius: width / 2
            color: Qt.alpha(root.pal.neon, 0.55)
            opacity: 0.15
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: !root.occluded
                NumberAnimation { to: 0.6 + Math.random() * 0.3; duration: 1800 + Math.random() * 2200; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.08; duration: 2200 + Math.random() * 2600; easing.type: Easing.InOutSine }
            }
        }
    }
    ItemParticle {
        system: sys
        groups: ["dust"]
        delegate: Rectangle {
            width: 2 * root.s; height: width; radius: width / 2
            color: Qt.alpha(root.pal.cyan, 0.20 + Math.random() * 0.14)
        }
    }
}
