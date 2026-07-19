import QtQuick

// downpour: the call, taken indoors — the driest pane in the house, because
// this is the app Aidan takes calls in. No shader field here: just two
// still beads keeping to the titlebar's corners, the faintest breath
// pooling at the top of the glass, and on every Teams navigation a single
// small droplet slides a short way under the titlebar and dries. Backdrop
// sits under the glass bars and the stripped page; the overlay carries no
// input and almost no motion.
Item {
    id: chrome

    required property var pal   // snapshot palette (pane-light/skin/warmth…)
    property var host: null     // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property color paneLight: pal.neon
    function paneA(a) { return Qt.rgba(paneLight.r, paneLight.g, paneLight.b, a) }
    function inkA(a)  { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function rnd(n) {
        let x = Math.imul((n + 641) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    readonly property string wordmark: "◦ dry inside"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the faintest breath at the top of the glass
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 60
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.inkA(0.035) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // two still beads, keeping to the corners
            Rectangle {
                x: 12; y: 10
                width: 4.6; height: 5.8
                radius: 2.3
                color: chrome.paneA(0.30)
                Rectangle { x: 0.9; y: 1.1; width: 1.4; height: 1.4; radius: 0.7; color: chrome.inkA(0.6) }
            }
            Rectangle {
                x: bd.width - 20; y: bd.height - 18
                width: 3.8; height: 4.8
                radius: 1.9
                color: chrome.paneA(0.24)
            }
        }
    }

    readonly property Component overlay: Component {
        Item {
            id: ov
            Item {
                id: run
                property real t: -1
                property real fx: 0.4
                visible: t >= 0
                x: ov.width * fx
                y: 26
                Rectangle {
                    id: runBead
                    x: -2.2
                    y: 18 * Math.max(0, run.t) * Math.max(0, run.t)
                    width: 4.4; height: 5.6
                    radius: 2.2
                    color: chrome.paneA(0.7 * (1 - Math.max(0, run.t) * 0.5))
                }
                Rectangle {
                    x: -1.2; y: 0
                    width: 1.2
                    height: runBead.y
                    opacity: 0.3 * (1 - Math.max(0, run.t))
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: chrome.paneA(0.0) }
                        GradientStop { position: 1.0; color: chrome.paneA(0.7) }
                    }
                }
                SequentialAnimation {
                    id: runAnim
                    NumberAnimation { target: run; property: "t"; from: 0; to: 1; duration: 520 }
                    PropertyAction { target: run; property: "t"; value: -1 }
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() {
                    if (!chrome.awake) return
                    run.fx = 0.1 + 0.8 * chrome.rnd(Date.now() % 9973)
                    runAnim.restart()
                }
            }
        }
    }
}
