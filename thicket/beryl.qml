import QtQuick

// thicket: on the scent — the browser is the watcher tracking something
// through the brush. The page owns the middle of the window (opaque by
// design), so the thicket lives in the chrome bands: a fringe of leaf
// silhouettes hangs from the tab strip's seam like the hedge over a game
// trail, and a small spray holds the status-bar corner by the wordmark.
// Every committed navigation is a fresh scent: a scatter of loose leaves
// darts along the seam and a pair of pale eyes glints open mid-seam for a
// blink before vanishing — something noticed you move. Both layers stand
// down in page fullscreen automatically. Nothing animates unfocused.
Item {
    id: chrome

    required property var pal   // snapshot palette (ember/iris/ember-red/…)
    property var host: null     // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    readonly property color ember: pal.neon
    readonly property color iris: pal.cyan
    function emberA(a) { return Qt.rgba(ember.r, ember.g, ember.b, a) }
    function irisA(a)  { return Qt.rgba(iris.r, iris.g, iris.b, a) }
    function leafA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    function rnd(n) {
        let x = Math.imul((n + 733) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: foliage glass, leaf-dark lip
    readonly property color cardBorder: Qt.alpha(pal.dim, 0.65)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 10

    readonly property string wordmark: "❧ on the scent"

    // the seam between the tab strip and the page
    readonly property int seamY: 42

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the hedge fringe hanging from the tab-strip seam — one draw
            Canvas {
                id: fringe
                anchors.left: parent.left
                anchors.right: parent.right
                y: chrome.seamY
                height: 12
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0) return
                    let x = 6, i = 0
                    while (x < width - 6) {
                        const len = 6 + chrome.rnd(i * 17 + 3) * 8
                        const wid = 2.2 + chrome.rnd(i * 29 + 5) * 2.2
                        const ang = Math.PI / 2 + (chrome.rnd(i * 11 + 1) - 0.5) * 0.9
                        const teal = chrome.rnd(i * 41 + 6) < 0.25
                        ctx.save()
                        ctx.translate(x, 0); ctx.rotate(ang)
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.quadraticCurveTo(len * 0.42, -wid, len, -wid * 0.08)
                        ctx.quadraticCurveTo(len * 0.46, wid * 0.9, 0, 0)
                        ctx.closePath()
                        ctx.fillStyle = teal ? "rgba(31,58,50,0.7)" : "rgba(7,12,10,0.75)"
                        ctx.fill()
                        ctx.restore()
                        x += 6 + chrome.rnd(i * 7 + 2) * 10
                        i++
                    }
                }
            }

            // spray in the status-bar corner, by the wordmark — one draw
            Canvas {
                id: corner
                width: 120; height: 30
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    for (let i = 0; i < 5; i++) {
                        const ang = Math.PI + 0.25 + (i / 5) * 0.9 + (chrome.rnd(i * 7 + 50) - 0.5) * 0.25
                        const len = 18 + chrome.rnd(i * 13 + 51) * 20
                        const wid = 4.5 + chrome.rnd(i * 17 + 52) * 4
                        ctx.save()
                        ctx.translate(width + 2, height * 0.75); ctx.rotate(ang)
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.quadraticCurveTo(len * 0.42, -wid, len, -wid * 0.08)
                        ctx.quadraticCurveTo(len * 0.46, wid * 0.9, 0, 0)
                        ctx.closePath()
                        ctx.fillStyle = chrome.rnd(i * 41 + 53) < 0.35 ? "rgba(23,44,38,0.8)" : "rgba(6,10,8,0.85)"
                        ctx.fill()
                        ctx.restore()
                    }
                }
            }
        }
    }

    // ── the fresh scent: leaves scatter + eyes glint on every navigation ────
    readonly property Component overlay: Component {
        Item {
            id: ov

            Item {
                id: scatter
                property real t: -1
                visible: t >= 0
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        readonly property real ph: index * 0.12
                        readonly property real k: Math.max(0, Math.min(1, scatter.t - ph))
                        x: -22 + (ov.width + 44) * k
                        y: chrome.seamY - 4 + index * 5 + Math.sin(k * Math.PI * 2 + index * 2) * 6
                        width: 8 - index; height: 3; radius: 1.5
                        rotation: k * 480 * (index % 2 === 0 ? 1 : -1)
                        opacity: scatter.t < 0 ? 0 : (k <= 0 || k >= 1 ? 0 : 0.8)
                        color: index === 1 ? "rgba(35,66,58,0.9)" : Qt.rgba(0.05, 0.08, 0.07, 0.9)
                    }
                }
                NumberAnimation {
                    id: scatterAnim
                    target: scatter; property: "t"
                    from: 0; to: 1.36; duration: 700
                    easing.type: Easing.OutQuad
                    onStopped: scatter.t = -1
                }
            }

            // the eyes, mid-seam: open, look, gone
            Item {
                id: glance
                width: 16; height: 5
                x: ov.width * 0.5 - 8
                y: chrome.seamY + 8
                opacity: 0
                transformOrigin: Item.Center
                Rectangle {
                    x: 0; y: 1; width: 5.5; height: 4; radius: 2
                    color: chrome.pal.cyan
                    Rectangle { x: 1.5; y: 1; width: 1.8; height: 1.8; radius: 0.9; color: Qt.rgba(1, 1, 1, 0.9) }
                }
                Rectangle {
                    x: 10.5; y: 0; width: 5.5; height: 4; radius: 2
                    color: chrome.pal.cyan
                    Rectangle { x: 1.5; y: 1; width: 1.8; height: 1.8; radius: 0.9; color: Qt.rgba(1, 1, 1, 0.9) }
                }
                SequentialAnimation {
                    id: glanceAnim
                    PropertyAction { target: glance; property: "scaleY"; value: 0.1 }
                    NumberAnimation { target: glance; property: "opacity"; to: 0.9; duration: 90 }
                    NumberAnimation { target: glance; property: "scaleY"; to: 1; duration: 130; easing.type: Easing.OutQuint }
                    PauseAnimation { duration: 620 }
                    NumberAnimation { target: glance; property: "scaleY"; to: 0.08; duration: 70 }
                    NumberAnimation { target: glance; property: "opacity"; to: 0; duration: 90 }
                }
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() {
                    if (!chrome.awake) return
                    scatterAnim.restart()
                    glance.x = ov.width * (0.3 + Math.random() * 0.4)
                    glanceAnim.restart()
                }
            }
        }
    }
}
