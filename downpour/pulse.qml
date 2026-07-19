import QtQuick

// downpour: the monitor is the pane the storm actually beats against. How
// hard it rains on this glass IS the machine's load — the condensation
// field's density rides host.load, so an idle machine keeps a near-dry
// pane and a pinned one runs wet, beads crowding in. Re-sorting the table
// spends one small droplet; actually killing a process is the heavy drop —
// a big warm-rose bead (the one warmth in this world) breaks and runs the
// whole pane, its trail lingering a beat. Chrome + voice only.
Item {
    id: chrome

    required property var pal   // snapshot palette (pane-light/skin/warmth…)
    property var host: null     // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0

    readonly property color paneLight: pal.neon
    readonly property color warmth: pal.magenta
    function paneA(a) { return Qt.rgba(paneLight.r, paneLight.g, paneLight.b, a) }
    function warmA(a) { return Qt.rgba(warmth.r, warmth.g, warmth.b, a) }
    function inkA(a)  { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function rnd(n) {
        let x = Math.imul((n + 389) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: a soft breath-mark frame
    readonly property color cardBorder: inkA(0.14)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 18

    readonly property string wordmark: "◦ how hard it rains"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the storm on this glass follows the machine
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("fog.frag.qsb")
                property real time: 0
                property real density: 0.07 + chrome.load * 0.45
                property color tint: chrome.paneLight
                opacity: 0.7
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // a fog bank that thickens as the machine runs hot
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 110
                opacity: 0.5 + chrome.load * 0.5
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.inkA(0.05 + chrome.load * 0.05) }
                }
            }
        }
    }

    readonly property Component overlay: Component {
        Item {
            id: ov

            // the small droplet a re-sort spends
            Item {
                id: sortRun
                property real t: -1
                property real fx: 0.3
                visible: t >= 0
                x: ov.width * fx
                y: 30
                Rectangle {
                    id: sortBead
                    x: -2.4
                    y: 30 * Math.max(0, sortRun.t) * Math.max(0, sortRun.t)
                    width: 4.8; height: 6
                    radius: 2.4
                    color: chrome.paneA(0.85 * (1 - Math.max(0, sortRun.t) * 0.5))
                }
                Rectangle {
                    x: -1.3; y: 0
                    width: 1.3
                    height: sortBead.y
                    opacity: 0.36 * (1 - Math.max(0, sortRun.t))
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: chrome.paneA(0.0) }
                        GradientStop { position: 1.0; color: chrome.paneA(0.8) }
                    }
                }
                SequentialAnimation {
                    id: sortAnim
                    NumberAnimation { target: sortRun; property: "t"; from: 0; to: 1; duration: 560 }
                    PropertyAction { target: sortRun; property: "t"; value: -1 }
                }
            }

            // the heavy drop a kill spends — warm, full height, lingering
            Item {
                id: killRun
                property real t: -1
                property real fx: 0.5
                visible: t >= 0
                x: ov.width * fx
                Rectangle {
                    id: killBead
                    x: -4
                    y: (ov.height - 30) * Math.max(0, killRun.t) * Math.max(0, killRun.t)
                    width: 8; height: 10.4
                    radius: 4
                    color: chrome.warmA(0.9 * (1 - Math.max(0, killRun.t) * 0.35))
                    Rectangle { x: 1.6; y: 1.9; width: 2.2; height: 2.2; radius: 1.1; color: chrome.inkA(0.85) }
                }
                Rectangle {
                    x: -2; y: 0
                    width: 2
                    height: killBead.y
                    opacity: 0.5 * (1 - Math.max(0, killRun.t) * 0.8)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: chrome.warmA(0.0) }
                        GradientStop { position: 1.0; color: chrome.warmA(0.85) }
                    }
                }
                SequentialAnimation {
                    id: killAnim
                    NumberAnimation { target: killRun; property: "t"; from: 0; to: 1; duration: 850; easing.type: Easing.InQuad }
                    PauseAnimation { duration: 400 }
                    PropertyAction { target: killRun; property: "t"; value: -1 }
                }
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onSortIdChanged() {
                    if (!chrome.awake) return
                    sortRun.fx = 0.1 + 0.8 * chrome.rnd(Date.now() % 9973)
                    sortAnim.restart()
                }
                function onKillPulseChanged() {
                    if (!chrome.awake) return
                    killRun.fx = 0.2 + 0.6 * chrome.rnd(Date.now() % 7919)
                    killAnim.restart()
                }
            }
        }
    }
}
