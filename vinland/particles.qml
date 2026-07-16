import QtQuick
import QtQuick.Particles

// snowfall — two depths of snow over the night march; the rare gold fleck
// is thorfinn's one warm color, spent sparingly
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

    // far snow — small, slow, half-lost in the dark
    Emitter {
        system: sys
        group: "far"
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        emitRate: 2.4
        lifeSpan: 30000
        velocity: AngleDirection {
            angle: 90; magnitude: 20
            angleVariation: 5; magnitudeVariation: 8
        }
    }
    // near snow — bigger flakes, driven a little harder
    Emitter {
        system: sys
        group: "near"
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        emitRate: 1.4
        lifeSpan: 22000
        velocity: AngleDirection {
            angle: 90; magnitude: 42
            angleVariation: 8; magnitudeVariation: 14
        }
    }
    // the gold — one ember every half minute or so
    Emitter {
        system: sys
        group: "gold"
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        emitRate: 0.035
        lifeSpan: 26000
        velocity: AngleDirection {
            angle: 90; magnitude: 24
            angleVariation: 10; magnitudeVariation: 6
        }
    }
    Wander { system: sys; xVariance: 55; pace: 35 }

    ItemParticle {
        system: sys
        groups: ["far"]
        delegate: Rectangle {
            width: 2 * root.s; height: width; radius: width / 2
            color: Qt.alpha(root.pal.text, 0.16 + Math.random() * 0.16)
        }
    }
    ItemParticle {
        system: sys
        groups: ["near"]
        delegate: Rectangle {
            width: (3 + Math.random()) * root.s
            height: width; radius: width / 2
            color: Qt.alpha(root.pal.text, 0.30 + Math.random() * 0.24)
        }
    }
    ItemParticle {
        system: sys
        groups: ["gold"]
        delegate: Rectangle {
            width: 3 * root.s; height: width; radius: width / 2
            color: Qt.alpha(root.pal.cyan, 0.7)
        }
    }
}
