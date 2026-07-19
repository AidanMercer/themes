import QtQuick
import QtQuick.Particles

// gunsmoke: the air of the hunt. Low fog wisps — broad, faint, blue-grey —
// crawl leftward through the bottom half of the screen the way powder smoke
// hangs after a volley, and a thin drift of ash motes falls slowly through
// the frame. Sparse, dim, soft. The wallpaper already rains; the desktop
// only smokes. Click-through scenery.
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

    // fog wisps, crawling left through the lower half
    Emitter {
        system: sys
        group: "fog"
        x: parent.width
        y: parent.height * 0.45
        width: 1
        height: parent.height * 0.5
        emitRate: 0.35
        lifeSpan: 34000
        velocity: AngleDirection {
            angle: 180; magnitude: 26
            angleVariation: 6; magnitudeVariation: 12
        }
    }
    // ash motes, sifting down and drifting with the wind
    Emitter {
        system: sys
        group: "ash"
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 1
        emitRate: 0.9
        lifeSpan: 20000
        velocity: AngleDirection {
            angle: 105; magnitude: 34
            angleVariation: 12; magnitudeVariation: 14
        }
    }

    ItemParticle {
        system: sys
        groups: ["fog"]
        delegate: Rectangle {
            width: (140 + Math.random() * 140) * root.s
            height: width * 0.34
            radius: height / 2
            color: Qt.alpha(root.pal.cyan, 0.9)
            opacity: 0
            // the wisp breathes as it crosses — thin, thicker, thin
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: !root.occluded
                NumberAnimation { to: 0.030 + Math.random() * 0.035; duration: 5000 + Math.random() * 4000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.012; duration: 5000 + Math.random() * 4000; easing.type: Easing.InOutSine }
            }
        }
    }
    ItemParticle {
        system: sys
        groups: ["ash"]
        delegate: Rectangle {
            width: (Math.random() < 0.3 ? 2.5 : 1.8) * root.s
            height: width
            radius: width / 2
            color: Math.random() < 0.7 ? Qt.alpha(root.pal.neon, 0.8)
                                       : Qt.alpha(root.pal.dim, 0.9)
            opacity: 0
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: !root.occluded
                NumberAnimation { to: 0.10 + Math.random() * 0.16; duration: 2400 + Math.random() * 2400; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.03; duration: 2400 + Math.random() * 2400; easing.type: Easing.InOutSine }
            }
        }
    }
}
