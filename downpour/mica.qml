import QtQuick

// downpour: the files, kept dry behind the glass. The miller columns sit on
// a pane of the storm — a sparse condensation field breathes across the
// backdrop while you rummage (clock parked the moment you look away), and a
// small breath mark fogs the lower-right corner. Every directory change
// spends one droplet: a bead condenses near the top seam and runs a short
// way down the pane, gone before it reaches the file names. Everything else
// holds still. Chrome + voice only; the layout stays mica's own.
Item {
    id: chrome

    required property var pal   // snapshot palette (pane-light/skin/warmth…)
    property var host: null     // mica window — active (focus), navId (cwd)

    readonly property bool awake: host ? host.active === true : false

    readonly property color paneLight: pal.neon
    function paneA(a) { return Qt.rgba(paneLight.r, paneLight.g, paneLight.b, a) }
    function inkA(a)  { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function rnd(n) {
        let x = Math.imul((n + 211) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: a soft breath-mark frame
    readonly property color cardBorder: inkA(0.14)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 18

    readonly property string wordmark: "◦ kept dry"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // sparse condensation — quieter here than on the player's glass
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("fog.frag.qsb")
                property real time: 0
                property real density: 0.11
                property color tint: chrome.paneLight
                opacity: 0.65
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // a breath mark fogging the lower-right corner
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -30
                anchors.bottomMargin: -30
                width: 180; height: 180
                radius: 90
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.inkA(0.05) }
                    GradientStop { position: 0.7; color: chrome.inkA(0.015) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // ── every directory change, one droplet runs from the seam ──────
            Item {
                id: run
                property real t: -1
                property real fx: 0.2
                visible: t >= 0
                x: bd.width * fx
                y: 34
                Rectangle {
                    id: runBead
                    x: -2.6
                    y: 42 * Math.max(0, run.t) * Math.max(0, run.t)
                    width: 5.2; height: 6.6
                    radius: 2.6
                    color: chrome.paneA(0.85 * (1 - Math.max(0, run.t) * 0.5))
                    Rectangle { x: 1; y: 1.2; width: 1.6; height: 1.6; radius: 0.8; color: chrome.inkA(0.85) }
                }
                Rectangle {
                    x: -1.4; y: 0
                    width: 1.4
                    height: runBead.y
                    opacity: 0.38 * (1 - Math.max(0, run.t))
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: chrome.paneA(0.0) }
                        GradientStop { position: 1.0; color: chrome.paneA(0.8) }
                    }
                }
                SequentialAnimation {
                    id: runAnim
                    NumberAnimation { target: run; property: "t"; from: 0; to: 1; duration: 600 }
                    PauseAnimation { duration: 220 }
                    PropertyAction { target: run; property: "t"; value: -1 }
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() {
                    if (!chrome.awake) return
                    run.fx = 0.08 + 0.84 * chrome.rnd(Date.now() % 9973)
                    runAnim.restart()
                }
            }
        }
    }
}
