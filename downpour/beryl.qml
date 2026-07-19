import QtQuick

// downpour: the storm, watched through the browser's chrome. The page owns
// the middle of the window, so the water keeps to the bands: a sagging
// meniscus seam under the tab strip with a few beads clinging to it, a
// sparse condensation field surfacing only through the window margins and
// the status bar, and a breath mark fogging the top-right of the tab-strip
// sky. Every committed navigation spends one droplet at the seam — a short
// run under the tabs, gone before the page notices. Chrome + voice only;
// everything holds still when you look away, and stands down in fullscreen.
Item {
    id: chrome

    required property var pal   // snapshot palette (pane-light/skin/warmth…)
    property var host: null     // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    readonly property color paneLight: pal.neon
    function paneA(a) { return Qt.rgba(paneLight.r, paneLight.g, paneLight.b, a) }
    function inkA(a)  { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function rnd(n) {
        let x = Math.imul((n + 977) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: a soft breath-mark frame
    readonly property color cardBorder: inkA(0.14)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 16

    readonly property string wordmark: "◦ watching the storm"

    // the seam between the tab strip and the page
    readonly property int seamY: 42

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // condensation in the margins — the page's scrim hides the middle
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("fog.frag.qsb")
                property real time: 0
                property real density: 0.10
                property color tint: chrome.paneLight
                opacity: 0.6
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // the meniscus seam the tabs sit on
            Canvas {
                id: seam
                y: chrome.seamY
                width: parent.width
                height: 12
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width
                    ctx.beginPath()
                    ctx.moveTo(0, 2)
                    const seg = w / 6
                    let px = 0, py = 2
                    for (let k = 1; k <= 6; k++) {
                        const ny = 1.5 + 3 * chrome.rnd(k * 13 + 2)
                        ctx.quadraticCurveTo(px + seg * 0.5, py + 2.2, k * seg, ny)
                        px = k * seg; py = ny
                    }
                    ctx.strokeStyle = String(chrome.paneA(0.24))
                    ctx.lineWidth = 1.1
                    ctx.stroke()
                    for (let i = 0; i < 5; i++) {
                        const bx = w * (0.10 + 0.19 * i + 0.05 * chrome.rnd(i * 43 + 11))
                        ctx.beginPath()
                        ctx.ellipse(bx, 3.5, 2.6, 3.4)
                        ctx.fillStyle = String(chrome.paneA(0.30))
                        ctx.fill()
                    }
                }
            }

            // a breath mark in the tab-strip sky, far right
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: -20
                y: -26
                width: 130; height: 130
                radius: 65
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.inkA(0.045) }
                    GradientStop { position: 0.7; color: chrome.inkA(0.012) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    // ── every navigation, one droplet leaves the seam ───────────────────────
    readonly property Component overlay: Component {
        Item {
            id: ov
            Item {
                id: run
                property real t: -1
                property real fx: 0.3
                visible: t >= 0
                x: ov.width * fx
                y: chrome.seamY + 6
                Rectangle {
                    id: runBead
                    x: -2.4
                    y: 24 * Math.max(0, run.t) * Math.max(0, run.t)
                    width: 4.8; height: 6
                    radius: 2.4
                    color: chrome.paneA(0.85 * (1 - Math.max(0, run.t) * 0.5))
                    Rectangle { x: 1; y: 1.1; width: 1.5; height: 1.5; radius: 0.8; color: chrome.inkA(0.85) }
                }
                Rectangle {
                    x: -1.3; y: 0
                    width: 1.3
                    height: runBead.y
                    opacity: 0.36 * (1 - Math.max(0, run.t))
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: chrome.paneA(0.0) }
                        GradientStop { position: 1.0; color: chrome.paneA(0.8) }
                    }
                }
                SequentialAnimation {
                    id: runAnim
                    NumberAnimation { target: run; property: "t"; from: 0; to: 1; duration: 560 }
                    PauseAnimation { duration: 200 }
                    PropertyAction { target: run; property: "t"; value: -1 }
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() {
                    if (!chrome.awake) return
                    run.fx = 0.08 + 0.8 * chrome.rnd(Date.now() % 9973)
                    runAnim.restart()
                }
            }
        }
    }
}
