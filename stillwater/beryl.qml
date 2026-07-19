import QtQuick

// stillwater: crossing over. The browser is the water between shores — the
// seam under the tab strip is the waterline, and the page below it is the
// deep. A few tiny lamps stand on the seam off at the right, doubled beneath
// as two-pixel slivers, and a small bank of shore light sits behind the
// status bar's wordmark corner, clear of the url text. Every committed
// navigation is a crossing: one light glides the seam left to right, streak
// trailing, and is gone. Designed for the chrome bands only — the page
// covers the middle. Everything holds still when you look away.
Item {
    id: chrome

    required property var pal   // snapshot palette (lamp/twilight/rose…)
    property var host: null     // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    readonly property color lamp: pal.neon
    readonly property color sky: pal.cyan
    function lampA(a) { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function skyA(a)  { return Qt.rgba(sky.r, sky.g, sky.b, a) }

    // deterministic hash — the same shore on every mount
    function rnd(n) {
        let x = Math.imul((n + 811) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: soft water glass, a thin twilight lip
    readonly property color cardBorder: Qt.alpha(sky, 0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 10

    readonly property string wordmark: "◦ crossing over"

    // the seam between the tab strip and the page: the waterline
    readonly property int seamY: 42

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the waterline along the seam, dying toward the left so the
            // active tab's title stays crisp
            Rectangle {
                x: 0; y: chrome.seamY
                width: parent.width
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.35; color: chrome.skyA(0.20) }
                    GradientStop { position: 1.0; color: chrome.skyA(0.28) }
                }
            }
            // tiny lamps on the seam, right side, doubled beneath
            Repeater {
                model: 4
                Item {
                    required property int index
                    readonly property real lv: 0.3 + chrome.rnd(index * 29 + 7) * 0.55
                    x: Math.round(bd.width * (0.68 + index * 0.075))
                    y: chrome.seamY
                    Rectangle {
                        x: -1.5; y: -2
                        width: 3; height: 3
                        radius: 1.5
                        color: chrome.lampA(0.25 + 0.5 * lv)
                    }
                    Rectangle { x: -1; y: 3; width: 2; height: 2; color: chrome.lampA(lv * 0.3) }
                    Rectangle { x: 0; y: 7; width: 2; height: 1.5; color: chrome.lampA(lv * 0.15) }
                }
            }

            // one lamp on the seam breathes while the window is looked at
            Rectangle {
                id: seamLamp
                x: Math.round(bd.width * 0.62) - 2
                y: chrome.seamY - 3
                width: 4; height: 4
                radius: 2
                color: chrome.lamp
                opacity: 0.45
                SequentialAnimation on opacity {
                    running: chrome.awake && bd.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.18; duration: 2800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.65; duration: 2800; easing.type: Easing.InOutSine }
                }
            }

            // a small bank of shore light behind the wordmark corner
            Canvas {
                id: bank
                width: Math.min(200, bd.width * 0.28)
                height: 26
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 6
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const wl = 10, W = width
                    ctx.fillStyle = String(chrome.skyA(0.18))
                    ctx.fillRect(0, wl, W, 1)
                    const n = Math.max(3, Math.floor(W / 42))
                    for (let i = 0; i < n; i++) {
                        const fx = 0.05 + chrome.rnd(i * 17 + 3) * 0.9
                        const lv = 0.3 + chrome.rnd(i * 29 + 7) * 0.5
                        const cx = Math.round(W * fx)
                        ctx.fillStyle = String(chrome.lampA(0.2 + 0.4 * lv))
                        ctx.fillRect(cx - 1, wl - 3, 3, 3)
                        ctx.fillStyle = String(chrome.lampA(lv * 0.25))
                        ctx.fillRect(cx - 0.5, wl + 3, 2, 2)
                        ctx.fillStyle = String(chrome.lampA(lv * 0.12))
                        ctx.fillRect(cx, wl + 8, 2, 1.5)
                    }
                }
            }
        }
    }

    // ── every navigation, a light takes the seam ────────────────────────────
    readonly property Component overlay: Component {
        Item {
            id: ov
            Item {
                id: ferry
                property real t: -1
                visible: t >= 0
                y: chrome.seamY
                x: ov.width * Math.max(0, t) - 10
                Rectangle { x: -2; y: -3; width: 4; height: 4; radius: 2; color: chrome.lamp }
                Rectangle { x: -16; y: -1; width: 14; height: 1; color: chrome.lampA(0.25) }
                Rectangle { x: -1; y: 3; width: 2; height: 2; color: chrome.lampA(0.35) }
                NumberAnimation {
                    id: ferryAnim
                    target: ferry; property: "t"
                    from: 0; to: 1; duration: 1200; easing.type: Easing.InOutSine
                    onStopped: ferry.t = -1
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) ferryAnim.restart() }
            }
        }
    }
}
