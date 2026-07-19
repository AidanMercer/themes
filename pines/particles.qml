import QtQuick
import QtQuick.Particles

// pines: the weather itself. Long soft banks of fog breathe slowly across
// the lower tiers of pine — wide, dim, cold — and every so often a bead of
// condensation forms on the cab glass and slips a little way down before it
// thins to nothing. Sparse and slow; the mountain sets the pace.
// Click-through scenery.
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

    // fog banks: born off the left edge, drifting right through the pines
    Emitter {
        system: sys
        group: "fog"
        x: -420
        y: parent.height * 0.45
        width: 1
        height: parent.height * 0.45
        emitRate: 0.22
        lifeSpan: 46000
        velocity: AngleDirection {
            angle: 0; magnitude: 26
            angleVariation: 3; magnitudeVariation: 10
        }
    }
    // condensation on the glass: rare beads that slip down and thin away
    Emitter {
        system: sys
        group: "bead"
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: parent.height * 0.55
        emitRate: 0.035
        lifeSpan: 5200
        velocity: AngleDirection { angle: 90; magnitude: 26; magnitudeVariation: 14 }
    }

    ItemParticle {
        system: sys
        groups: ["fog"]
        delegate: Rectangle {
            width: (260 + Math.random() * 220) * root.s
            height: (46 + Math.random() * 40) * root.s
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.alpha(root.pal.cyan, 0.0) }
                GradientStop { position: 0.5; color: Qt.alpha(root.pal.cyan, 0.05) }
                GradientStop { position: 1.0; color: Qt.alpha(root.pal.cyan, 0.0) }
            }
            opacity: 0
            // the bank breathes: swells up, holds, thins — never a hard edge
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: !root.occluded
                NumberAnimation { to: 0.55 + Math.random() * 0.35; duration: 9000 + Math.random() * 5000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.22; duration: 9000 + Math.random() * 5000; easing.type: Easing.InOutSine }
            }
        }
    }
    ItemParticle {
        system: sys
        groups: ["bead"]
        delegate: Item {
            width: 4 * root.s; height: 18 * root.s
            opacity: 0
            Rectangle {   // the trailing thread
                x: 1.2 * root.s; y: -10 * root.s
                width: 1.2 * root.s; height: 12 * root.s
                color: Qt.alpha(root.pal.cyan, 0.28)
            }
            Rectangle {   // the bead
                width: 3.4 * root.s; height: 5 * root.s; radius: 1.7 * root.s
                color: Qt.alpha(root.pal.text, 0.55)
            }
            SequentialAnimation on opacity {
                running: !root.occluded
                NumberAnimation { to: 0.8; duration: 700; easing.type: Easing.OutQuad }
                PauseAnimation { duration: 2600 }
                NumberAnimation { to: 0; duration: 1700; easing.type: Easing.InQuad }
            }
        }
    }
}
