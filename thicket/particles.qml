import QtQuick
import QtQuick.Particles

// thicket: the air in the underbrush. Almost nothing moves — that's the
// point. Every dozen seconds or so ONE leaf is flicked loose somewhere and
// darts down a short arc, spinning once, gone before it reaches the ground:
// stillness, then the dart, then stillness. And rarely — a couple of times a
// song — a pair of pale eyes opens in the dark near a screen edge, watches
// for a couple of seconds, and blinks shut. No drift loops, no confetti.
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

    // one leaf at a time, flicked loose from the canopy
    Emitter {
        system: sys
        group: "leafdark"
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: parent.height * 0.3
        emitRate: 0.055
        lifeSpan: 3800
        velocity: AngleDirection {
            angle: 100; magnitude: 150
            angleVariation: 22; magnitudeVariation: 60
        }
        acceleration: AngleDirection { angle: 90; magnitude: 40 }
    }
    Emitter {
        system: sys
        group: "leafteal"
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: parent.height * 0.3
        emitRate: 0.025
        lifeSpan: 3800
        velocity: AngleDirection {
            angle: 80; magnitude: 140
            angleVariation: 20; magnitudeVariation: 50
        }
        acceleration: AngleDirection { angle: 90; magnitude: 40 }
    }

    ItemParticle {
        system: sys
        groups: ["leafdark"]
        delegate: Rectangle {
            id: ld
            width: (7 + Math.random() * 5) * root.s
            height: width * 0.42
            radius: height / 2
            color: Qt.rgba(0.06, 0.09, 0.08, 0.85)
            property real r0: Math.random() * 360
            rotation: r0
            // most of a turn over the fall — a single motion, not a loop
            NumberAnimation on rotation {
                running: !root.occluded
                from: ld.r0
                to: ld.r0 + (Math.random() < 0.5 ? -300 : 300)
                duration: 3800
                easing.type: Easing.OutQuad
            }
        }
    }
    ItemParticle {
        system: sys
        groups: ["leafteal"]
        delegate: Rectangle {
            id: lt
            width: (6 + Math.random() * 4) * root.s
            height: width * 0.42
            radius: height / 2
            color: Qt.rgba(0.11, 0.22, 0.19, 0.8)
            property real r0: Math.random() * 360
            rotation: r0
            NumberAnimation on rotation {
                running: !root.occluded
                from: lt.r0
                to: lt.r0 + (Math.random() < 0.5 ? -300 : 300)
                duration: 3800
                easing.type: Easing.OutQuad
            }
        }
    }

    // ── the corner eyeshine: something opens its eyes, watches, blinks shut ──
    Item {
        id: eyes
        width: 26 * root.s
        height: 9 * root.s
        opacity: 0
        transformOrigin: Item.Center

        Rectangle {
            x: 0; y: 2 * root.s
            width: 9 * root.s; height: 6 * root.s; radius: 3 * root.s
            color: root.pal.cyan
            Rectangle {
                x: 2 * root.s; y: 1.5 * root.s
                width: 2.5 * root.s; height: 2.5 * root.s; radius: 1.25 * root.s
                color: Qt.rgba(1, 1, 1, 0.9)
            }
        }
        Rectangle {
            x: 17 * root.s; y: 0
            width: 9 * root.s; height: 6 * root.s; radius: 3 * root.s
            color: root.pal.cyan
            Rectangle {
                x: 2 * root.s; y: 1.5 * root.s
                width: 2.5 * root.s; height: 2.5 * root.s; radius: 1.25 * root.s
                color: Qt.rgba(1, 1, 1, 0.9)
            }
        }

        SequentialAnimation {
            id: watchOnce
            // open where it stands
            NumberAnimation { target: eyes; property: "opacity"; to: 0.75; duration: 140; easing.type: Easing.OutQuint }
            NumberAnimation { target: eyes; property: "scaleY"; from: 0.1; to: 1; duration: 150; easing.type: Easing.OutQuint }
            // watch, one mid-hold blink
            PauseAnimation { duration: 1100 }
            NumberAnimation { target: eyes; property: "scaleY"; to: 0.1; duration: 70 }
            NumberAnimation { target: eyes; property: "scaleY"; to: 1; duration: 110; easing.type: Easing.OutQuint }
            PauseAnimation { duration: 1000 }
            // gone
            NumberAnimation { target: eyes; property: "scaleY"; to: 0.05; duration: 80 }
            NumberAnimation { target: eyes; property: "opacity"; to: 0; duration: 100 }
        }
    }
    Timer {
        id: watchTimer
        interval: 90000 + Math.random() * 120000
        repeat: true
        running: !root.occluded
        onTriggered: {
            interval = 90000 + Math.random() * 120000
            if (watchOnce.running) return
            // near an edge, in the darker thirds — never mid-screen
            const left = Math.random() < 0.5
            eyes.x = left ? root.width * (0.03 + Math.random() * 0.10)
                          : root.width * (0.86 + Math.random() * 0.10)
            eyes.y = root.height * (0.55 + Math.random() * 0.35)
            watchOnce.restart()
        }
    }
}
