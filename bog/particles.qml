import QtQuick
import QtQuick.Particles

// bog: the air over the pond at slow noon. Pollen motes hang in the light
// shafts falling through the canopy — tiny warm specks drifting down so
// slowly they seem to be deciding whether to bother — and once in a long
// while a leaf lets go of the tall grass and sees itself down to the water,
// swaying side to side, turning as it goes. One dragonfly crosses the pond
// on rare occasions, on its way to somewhere unhurried. Sparse, dim, soft.
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

    // pollen in the noon shafts — upper middle where the light comes down
    Emitter {
        system: sys
        group: "pollen"
        x: parent.width * 0.12
        y: 0
        width: parent.width * 0.55
        height: parent.height * 0.45
        emitRate: 1.7
        lifeSpan: 21000
        velocity: AngleDirection {
            angle: 100; magnitude: 6
            angleVariation: 30; magnitudeVariation: 4
        }
    }
    // a leaf lets go of the grass, now and then
    Emitter {
        system: sys
        group: "leaf"
        x: parent.width * 0.05
        y: parent.height * 0.12
        width: parent.width * 0.9
        height: parent.height * 0.1
        emitRate: 0.045
        lifeSpan: 15000
        velocity: AngleDirection {
            angle: 92; magnitude: 34
            angleVariation: 8; magnitudeVariation: 10
        }
    }
    // the crossing dragonfly, rare
    Emitter {
        system: sys
        group: "dfly"
        x: -4
        y: parent.height * 0.52
        width: 1
        height: parent.height * 0.12
        emitRate: 0.008
        lifeSpan: 24000
        velocity: AngleDirection { angle: 0; magnitude: 110; magnitudeVariation: 30 }
    }

    ItemParticle {
        system: sys
        groups: ["pollen"]
        delegate: Rectangle {
            width: (Math.random() < 0.3 ? 3 : 2) * root.s
            height: width
            radius: width / 2
            color: Math.random() < 0.75 ? Qt.alpha(root.pal.neon, 0.9)
                                        : Qt.alpha(root.pal.text, 0.8)
            opacity: 0
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: !root.occluded
                NumberAnimation { to: 0.10 + Math.random() * 0.20; duration: 2600 + Math.random() * 3000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.03; duration: 2600 + Math.random() * 3000; easing.type: Easing.InOutSine }
            }
        }
    }

    ItemParticle {
        system: sys
        groups: ["leaf"]
        delegate: Item {
            id: leafP
            width: 14 * root.s; height: 8 * root.s
            opacity: 0
            // the sway: the leaf slips side to side as it falls
            property real swayX: 0
            transform: Translate { x: leafP.swayX }
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Math.random() < 0.6 ? Qt.alpha(root.pal.cyan, 0.6)
                                           : Qt.alpha(root.pal.amber, 0.5)
                rotation: -14
            }
            SequentialAnimation on swayX {
                loops: Animation.Infinite
                running: !root.occluded
                NumberAnimation { to: 26 * root.s; duration: 1900; easing.type: Easing.InOutSine }
                NumberAnimation { to: -26 * root.s; duration: 1900; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on rotation {
                loops: Animation.Infinite
                running: !root.occluded
                NumberAnimation { to: 22; duration: 1900; easing.type: Easing.InOutSine }
                NumberAnimation { to: -22; duration: 1900; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on opacity {
                id: driftFade
                running: !root.occluded
                NumberAnimation { to: 0.5; duration: 1600; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 10800 }
                NumberAnimation { to: 0; duration: 2400; easing.type: Easing.InOutSine }
            }
            // pooled delegate — one-shot ends at 0; re-arm per attach
            ItemParticle.onAttached: driftFade.restart()
        }
    }

    ItemParticle {
        system: sys
        groups: ["dfly"]
        delegate: Item {
            id: dflyP
            width: 16 * root.s; height: 8 * root.s
            opacity: 0
            property real hover: 0
            transform: Translate { y: dflyP.hover }
            // thin body + wing shimmer
            Rectangle { x: 2 * root.s; y: 3 * root.s; width: 10 * root.s; height: 1.4 * root.s; radius: root.s; color: Qt.alpha(root.pal.cyan, 0.8) }
            Rectangle { x: 4 * root.s; y: 0; width: 4 * root.s; height: 2.6 * root.s; radius: root.s; rotation: -28; color: Qt.alpha(root.pal.neon, 0.35) }
            Rectangle { x: 8 * root.s; y: 0; width: 4 * root.s; height: 2.6 * root.s; radius: root.s; rotation: 24; color: Qt.alpha(root.pal.neon, 0.35) }
            SequentialAnimation on hover {
                loops: Animation.Infinite
                running: !root.occluded
                NumberAnimation { to: -7 * root.s; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 5 * root.s; duration: 1100; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on opacity {
                id: skimFade
                running: !root.occluded
                NumberAnimation { to: 0.55; duration: 2200 }
                PauseAnimation { duration: 18000 }
                NumberAnimation { to: 0; duration: 3000 }
            }
            // pooled delegate — one-shot ends at 0; re-arm per attach
            ItemParticle.onAttached: skimFade.restart()
        }
    }
}
