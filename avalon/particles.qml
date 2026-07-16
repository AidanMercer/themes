import QtQuick
import QtQuick.Particles

// meadow drift — buttercup petals and cream motes loosed over the flower field
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

    // petals let go from above the top edge, tumbling down on the breeze
    Emitter {
        system: sys
        group: "petal"
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        emitRate: 1.6
        lifeSpan: 26000
        velocity: AngleDirection {
            angle: 90; magnitude: 30
            angleVariation: 10; magnitudeVariation: 14
        }
    }
    // finer pollen-cream motes, slower, deeper in the field
    Emitter {
        system: sys
        group: "mote"
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        emitRate: 1.1
        lifeSpan: 30000
        velocity: AngleDirection {
            angle: 90; magnitude: 16
            angleVariation: 8; magnitudeVariation: 8
        }
    }
    Wander { system: sys; xVariance: 90; pace: 40 }

    ItemParticle {
        system: sys
        groups: ["petal"]
        delegate: Rectangle {
            width: (6 + Math.random() * 3) * root.s
            height: width * 0.7
            radius: height / 2
            color: Math.random() < 0.65 ? Qt.alpha(root.pal.cyan, 0.42)   // buttercup
                                        : Qt.alpha(root.pal.text, 0.34)   // moss-cream
            property real r0: Math.random() * 360
            rotation: r0
            NumberAnimation on rotation {
                from: r0; to: r0 + (Math.random() < 0.5 ? 360 : -360)
                duration: 9000 + Math.random() * 8000
                loops: Animation.Infinite
                running: !root.occluded
            }
        }
    }
    ItemParticle {
        system: sys
        groups: ["mote"]
        delegate: Rectangle {
            width: (2 + Math.random() * 1.5) * root.s
            height: width; radius: width / 2
            color: Qt.alpha(root.pal.text, 0.16 + Math.random() * 0.18)
        }
    }
}
