import QtQuick
import QtQuick.Particles

// stillwater: the water's own quiet life. Below the horizon, sparse 2px
// glints — starlight caught on the surface — drift almost imperceptibly and
// breathe in and out over long seconds. Now and then a single ripple ring
// blooms flat on the water, spreads slowly, and is gone: something unseen
// touched the mirror. Above the line, nothing — the sky holds still.
// Sparse, dim, near-still. Click-through scenery.
Item {
    id: root
    anchors.fill: parent
    required property var pal
    property bool occluded: false
    readonly property real s: (pal && pal.uiScale) ? pal.uiScale : 1
    readonly property real hzY: height * 0.527

    ParticleSystem {
        id: sys
        running: true
        paused: root.occluded
    }

    // glints on the water — born anywhere below the line, drifting a little
    Emitter {
        system: sys
        group: "glint"
        y: root.hzY + 30
        width: parent.width
        height: Math.max(1, parent.height - root.hzY - 60)
        emitRate: 0.9
        lifeSpan: 16000
        velocity: AngleDirection {
            angle: 0; magnitude: 2
            angleVariation: 180; magnitudeVariation: 2
        }
    }
    // a rare ripple — once every half minute or so, somewhere on the water
    Emitter {
        system: sys
        group: "ripple"
        y: root.hzY + 60
        width: parent.width * 0.9
        x: parent.width * 0.05
        height: Math.max(1, parent.height - root.hzY - 140)
        emitRate: 0.035
        lifeSpan: 9000
        velocity: AngleDirection { angle: 0; magnitude: 0 }
    }

    ItemParticle {
        system: sys
        groups: ["glint"]
        delegate: Rectangle {
            width: (Math.random() < 0.2 ? 3 : 2) * root.s
            height: width
            radius: width / 2
            color: Math.random() < 0.75 ? Qt.alpha(root.pal.neon, 0.9)
                                        : Qt.alpha(root.pal.cyan, 0.8)
            opacity: 0
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: !root.occluded
                NumberAnimation { to: 0.06 + Math.random() * 0.16; duration: 3200 + Math.random() * 3600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.015; duration: 3200 + Math.random() * 3600; easing.type: Easing.InOutSine }
            }
        }
    }
    ItemParticle {
        system: sys
        groups: ["ripple"]
        delegate: Item {
            id: rip
            width: 90 * root.s
            height: width
            opacity: 0
            Rectangle {
                id: ring
                anchors.centerIn: parent
                width: 6
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(root.pal.neon, 0.5)
                transform: Scale { origin.y: ring.height / 2; yScale: 0.24 }
            }
            // one slow bloom per life; timed to the emitter's lifeSpan
            SequentialAnimation {
                running: !root.occluded
                loops: Animation.Infinite
                ParallelAnimation {
                    NumberAnimation { target: ring; property: "width"; from: 6; to: 84 * root.s; duration: 4200; easing.type: Easing.OutSine }
                    SequentialAnimation {
                        NumberAnimation { target: rip; property: "opacity"; from: 0; to: 0.5; duration: 700; easing.type: Easing.OutQuad }
                        NumberAnimation { target: rip; property: "opacity"; to: 0; duration: 3500; easing.type: Easing.InOutSine }
                    }
                }
                PauseAnimation { duration: 4800 }
            }
        }
    }
}
