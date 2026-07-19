import QtQuick
import QtQuick.Particles

// homeroom: the air of the room at seven in the morning. Dust motes hang in
// the light shafts — warm-white specks drifting slowly down and left along
// the sun's angle, breathing in and out of visibility — and every so often
// a pinch of chalk dust lets go of the board's tray and sifts straight down.
// Sparse, pale, slow. Click-through scenery.
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

    // dust motes riding the morning light, upper-right to lower-left
    Emitter {
        system: sys
        group: "mote"
        x: parent.width * 0.25
        y: -10
        width: parent.width * 0.75
        height: parent.height * 0.4
        emitRate: 1.4
        lifeSpan: 26000
        velocity: AngleDirection {
            angle: 122; magnitude: 9
            angleVariation: 10; magnitudeVariation: 5
        }
    }
    // chalk dust sifting off the board tray, center of the room
    Emitter {
        system: sys
        group: "chalkfall"
        x: parent.width * 0.30
        y: parent.height * 0.50
        width: parent.width * 0.34
        height: 4
        emitRate: 0.12
        lifeSpan: 5200
        velocity: AngleDirection { angle: 90; magnitude: 14; magnitudeVariation: 6 }
    }

    ItemParticle {
        system: sys
        groups: ["mote"]
        delegate: Rectangle {
            width: (Math.random() < 0.3 ? 3 : 2) * root.s
            height: width
            radius: width / 2
            color: Math.random() < 0.7 ? Qt.alpha(root.pal.amber, 0.9)
                                       : Qt.alpha(root.pal.text, 0.85)
            opacity: 0
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: !root.occluded
                NumberAnimation { to: 0.10 + Math.random() * 0.20; duration: 2400 + Math.random() * 2800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.03; duration: 2400 + Math.random() * 2800; easing.type: Easing.InOutSine }
            }
        }
    }
    ItemParticle {
        system: sys
        groups: ["chalkfall"]
        delegate: Item {
            width: 6 * root.s; height: 8 * root.s
            opacity: 0
            Rectangle { x: 0; y: 0; width: 2 * root.s; height: 2 * root.s; radius: root.s; color: Qt.alpha(root.pal.text, 0.8) }
            Rectangle { x: 3 * root.s; y: 3 * root.s; width: 1.6 * root.s; height: 1.6 * root.s; radius: root.s; color: Qt.alpha(root.pal.text, 0.6) }
            Rectangle { x: 1 * root.s; y: 5 * root.s; width: 1.4 * root.s; height: 1.4 * root.s; radius: root.s; color: Qt.alpha(root.pal.text, 0.5) }
            SequentialAnimation on opacity {
                id: fallFade
                running: !root.occluded
                NumberAnimation { to: 0.5; duration: 700 }
                PauseAnimation { duration: 3000 }
                NumberAnimation { to: 0; duration: 1400 }
            }
            // pooled delegate — one-shot ends at 0; re-arm per attach
            ItemParticle.onAttached: fallFade.restart()
        }
    }
}
