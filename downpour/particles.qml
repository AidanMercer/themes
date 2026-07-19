import QtQuick

// downpour: the pane keeps condensing. A dozen beads live on the glass —
// each one condenses somewhere new (grows from nothing), sits a long while
// trembling almost imperceptibly, then either dries back into the air or
// loses its grip and runs: a short vertical fall with a thinning tail,
// gone before it reaches anything. No falling rain, no streak fields —
// water on this desktop sits, and breaks. Sparse, dim, slow.
// Click-through scenery; the whole pane holds still while occluded.
Item {
    id: root
    anchors.fill: parent
    required property var pal
    property bool occluded: false
    readonly property real s: (pal && pal.uiScale) ? pal.uiScale : 1

    readonly property color paneLight: pal.neon
    readonly property color ink: pal.text
    function paneA(a) { return Qt.rgba(paneLight.r, paneLight.g, paneLight.b, a) }
    function inkA(a)  { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    Repeater {
        model: 12
        delegate: Item {
            id: bead
            required property int index
            property real runY: 0
            property real bodyA: 0
            readonly property real bw: (4 + (index % 3) * 1.6) * root.s

            // start scattered; each cycle repositions
            x: Math.random() * root.width
            y: Math.random() * root.height * 0.9

            // the bead itself
            Rectangle {
                y: bead.runY
                width: bead.bw
                height: bead.bw * 1.28
                radius: bead.bw / 2
                color: root.paneA(0.5)
                opacity: bead.bodyA
                Rectangle {
                    x: bead.bw * 0.22; y: bead.bw * 0.22
                    width: bead.bw * 0.28; height: bead.bw * 0.28
                    radius: width / 2
                    color: root.inkA(0.75)
                }
            }
            // the tail it leaves when it runs
            Rectangle {
                x: bead.bw / 2 - 0.8
                y: 0
                width: 1.4
                height: Math.max(0, bead.runY)
                opacity: bead.bodyA * 0.45
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.paneA(0.0) }
                    GradientStop { position: 1.0; color: root.paneA(0.7) }
                }
            }

            SequentialAnimation {
                running: !root.occluded
                loops: Animation.Infinite

                // wait for a breath, somewhere on the glass
                PauseAnimation { duration: 2000 + (bead.index % 7) * 1700 }
                ScriptAction {
                    script: {
                        bead.x = Math.random() * root.width
                        bead.y = root.height * (0.04 + Math.random() * 0.82)
                        bead.runY = 0
                        bead.bodyA = 0
                    }
                }
                // condense
                NumberAnimation { target: bead; property: "bodyA"; to: 0.55; duration: 2600; easing.type: Easing.InOutSine }
                // dwell — the glass holds it
                PauseAnimation { duration: 5000 + (bead.index % 5) * 2600 }
                // one in three loses its grip and runs; the rest dry in place
                NumberAnimation {
                    target: bead; property: "runY"
                    to: bead.index % 3 === 0 ? (34 + (bead.index % 4) * 22) * root.s : 0
                    duration: 640
                    easing.type: Easing.InQuad
                }
                // dry back into the air
                NumberAnimation { target: bead; property: "bodyA"; to: 0; duration: 1900; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 1200 + (bead.index % 6) * 900 }
            }
        }
    }
}
