import QtQuick
import QtQuick.Particles

// starlight — motes twinkling in the deep navy, and every so often one
// falls past the vending machine
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

    // hanging stars — near-still, born and dying inside their own twinkle
    Emitter {
        system: sys
        group: "star"
        anchors.fill: parent
        emitRate: 1.4
        lifeSpan: 24000
        velocity: AngleDirection {
            angle: 0; magnitude: 2
            angleVariation: 180; magnitudeVariation: 2
        }
    }
    // a shooting star roughly twice a minute, out of the top right
    Emitter {
        system: sys
        group: "streak"
        anchors { top: parent.top; right: parent.right }
        width: parent.width * 0.5
        height: parent.height * 0.3
        emitRate: 0.035
        lifeSpan: 1100
        velocity: AngleDirection {
            angle: 155; magnitude: 760
            angleVariation: 6; magnitudeVariation: 120
        }
    }

    ItemParticle {
        system: sys
        groups: ["star"]
        delegate: Rectangle {
            width: (1.5 + Math.random() * 1.5) * root.s
            height: width; radius: width / 2
            color: Math.random() < 0.85 ? Qt.alpha(root.pal.text, 0.8)
                                        : Qt.alpha(root.pal.neon, 0.8)  // vending amber
            opacity: 0
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: !root.occluded
                NumberAnimation { to: 0.5 + Math.random() * 0.4; duration: 2400 + Math.random() * 3000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.04; duration: 2400 + Math.random() * 3000; easing.type: Easing.InOutSine }
            }
        }
    }
    ItemParticle {
        system: sys
        groups: ["streak"]
        delegate: Rectangle {
            width: 80 * root.s; height: 1.5 * root.s
            rotation: 155
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.alpha(root.pal.text, 0.85) }
            }
            NumberAnimation on opacity { from: 1; to: 0; duration: 1050 }
        }
    }
}
