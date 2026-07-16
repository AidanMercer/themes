import QtQuick
import QtQuick.Particles

// road8: the night air over the city. Warm square embers — stray light off a
// thousand windows — drift up from the valley in lazy pixel steps, and every
// so often another car crosses the far hillside: a pair of red taillight
// pixels sliding left, or pale headlights sliding right. Somebody else out
// on the road tonight. Sparse, dim, square. Click-through scenery.
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

    // city embers, rising slow out of the light below the horizon
    Emitter {
        system: sys
        group: "ember"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: parent.height * 0.5
        emitRate: 1.6
        lifeSpan: 22000
        velocity: AngleDirection {
            angle: 270; magnitude: 7
            angleVariation: 14; magnitudeVariation: 5
        }
    }
    // a car crossing the far hills — taillights heading away (leftward)…
    Emitter {
        system: sys
        group: "tailcar"
        x: parent.width
        y: parent.height * 0.60
        width: 1
        height: parent.height * 0.06
        emitRate: 0.014
        lifeSpan: 16000
        velocity: AngleDirection { angle: 180; magnitude: 160; magnitudeVariation: 40 }
    }
    // …and one coming the other way, headlights pale
    Emitter {
        system: sys
        group: "headcar"
        x: -1
        y: parent.height * 0.64
        width: 1
        height: parent.height * 0.05
        emitRate: 0.010
        lifeSpan: 16000
        velocity: AngleDirection { angle: 0; magnitude: 150; magnitudeVariation: 40 }
    }

    ItemParticle {
        system: sys
        groups: ["ember"]
        delegate: Rectangle {
            // square pixels, never round
            width: (Math.random() < 0.25 ? 3 : 2) * root.s
            height: width
            color: Math.random() < 0.8 ? Qt.alpha(root.pal.neon, 0.8)
                                       : Qt.alpha(root.pal.text, 0.7)
            opacity: 0
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: !root.occluded
                NumberAnimation { to: 0.10 + Math.random() * 0.22; duration: 2000 + Math.random() * 2600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.03; duration: 2000 + Math.random() * 2600; easing.type: Easing.InOutSine }
            }
        }
    }
    ItemParticle {
        system: sys
        groups: ["tailcar"]
        delegate: Item {
            width: 9 * root.s; height: 2 * root.s
            opacity: 0
            Rectangle { x: 0; width: 3 * root.s; height: 2 * root.s; color: root.pal.magenta }
            Rectangle { x: 5 * root.s; width: 3 * root.s; height: 2 * root.s; color: root.pal.magenta }
            SequentialAnimation on opacity {
                running: !root.occluded
                NumberAnimation { to: 0.75; duration: 2400 }
                PauseAnimation { duration: 10500 }
                NumberAnimation { to: 0; duration: 2600 }
            }
        }
    }
    ItemParticle {
        system: sys
        groups: ["headcar"]
        delegate: Item {
            width: 9 * root.s; height: 2 * root.s
            opacity: 0
            Rectangle { x: 0; width: 3 * root.s; height: 2 * root.s; color: Qt.alpha(root.pal.text, 0.9) }
            Rectangle { x: 5 * root.s; width: 3 * root.s; height: 2 * root.s; color: Qt.alpha(root.pal.text, 0.9) }
            SequentialAnimation on opacity {
                running: !root.occluded
                NumberAnimation { to: 0.6; duration: 2400 }
                PauseAnimation { duration: 10500 }
                NumberAnimation { to: 0; duration: 2600 }
            }
        }
    }
}
