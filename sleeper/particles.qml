import QtQuick
import QtQuick.Particles

// sleeper: dust in the window light. The compartment air holds a thin drift
// of motes, visible only where the green city light falls through the glass —
// they hang, sink slowly, and sway a little with the carriage. Now and then
// one catches the moon and glints pale for a moment. Sparse, dim, round.
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

    // motes in the window's column of light
    Emitter {
        system: sys
        group: "mote"
        x: parent.width * 0.20
        y: parent.height * 0.26
        width: parent.width * 0.52
        height: parent.height * 0.52
        emitRate: 1.8
        lifeSpan: 20000
        velocity: AngleDirection {
            angle: 100; magnitude: 5
            angleVariation: 30; magnitudeVariation: 4
        }
    }
    // the odd glint drifting nearer the moon's slice of window
    Emitter {
        system: sys
        group: "glint"
        x: parent.width * 0.30
        y: parent.height * 0.02
        width: parent.width * 0.30
        height: parent.height * 0.22
        emitRate: 0.10
        lifeSpan: 12000
        velocity: AngleDirection { angle: 95; magnitude: 4; angleVariation: 20; magnitudeVariation: 3 }
    }

    ItemParticle {
        system: sys
        groups: ["mote"]
        delegate: Rectangle {
            width: (Math.random() < 0.3 ? 3 : 2) * root.s
            height: width
            radius: width / 2
            color: Math.random() < 0.7 ? Qt.alpha(root.pal.neon, 0.8)
                                       : Qt.alpha(root.pal.text, 0.7)
            opacity: 0
            // each mote breathes in and out of the light — a slow sway, no bounce
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: !root.occluded
                NumberAnimation { to: 0.07 + Math.random() * 0.14; duration: 2600 + Math.random() * 2800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.02; duration: 2600 + Math.random() * 2800; easing.type: Easing.InOutSine }
            }
        }
    }
    ItemParticle {
        system: sys
        groups: ["glint"]
        delegate: Rectangle {
            width: 3 * root.s
            height: width
            radius: width / 2
            color: Qt.alpha(root.pal.cyan, 0.9)
            opacity: 0
            SequentialAnimation on opacity {
                id: glintFade
                running: !root.occluded
                NumberAnimation { to: 0.4; duration: 2200; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.08; duration: 2400; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.3; duration: 2200; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: 2600; easing.type: Easing.InOutSine }
            }
            // pooled delegate — one-shot ends at 0; re-arm per attach
            ItemParticle.onAttached: glintFade.restart()
        }
    }
}
