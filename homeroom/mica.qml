import QtQuick
import "chalk.js" as Chalk

// homeroom: the locker room. Below the miller columns runs the corridor's
// locker bank — periwinkle doors, pink stripe labels, vent slits, drawn once
// and deterministic (the same lockers every mount). Morning sun leans in
// from the top and a pair of dust motes hang in it while the window is
// focused. Every directory change is a locker visit: one door's latch-side
// seam flashes warm (a different door each time, hashed off the visit
// count) and a hall pass drops onto the top-right corner, settles crooked,
// and fades. Chrome + voice only; mica's layout stays its own.
Item {
    id: chrome

    required property var pal   // snapshot palette (halo/periwinkle/pink…)
    property var host: null     // mica window — active (focus), navId (cwd)

    readonly property bool awake: host ? host.active === true : false

    readonly property color chalk: pal.text
    readonly property color halo: pal.neon
    readonly property color peri: pal.cyan
    readonly property color pink: pal.magenta
    readonly property color sun: pal.amber
    function chalkA(a) { return Qt.rgba(chalk.r, chalk.g, chalk.b, a) }
    function sunA(a)   { return Qt.rgba(sun.r, sun.g, sun.b, a) }
    function periA(a)  { return Qt.rgba(peri.r, peri.g, peri.b, a) }

    // deterministic hash — the same locker bank on every mount
    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: paper-soft corners, a faint chalk lip
    readonly property color cardBorder: Qt.alpha(chalk, 0.20)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 8

    readonly property string wordmark: "⌂ locker room"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property int band: 66       // locker bank height
            readonly property real doorW: 44
            property int visits: 0               // directories opened this mount

            // morning sun leaning in from the top
            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: Math.min(90, parent.height * 0.25)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.sunA(0.09) }
                    GradientStop { position: 1.0; color: chrome.sunA(0.0) }
                }
            }

            // ── the locker bank, one static draw ───────────────────────────
            Canvas {
                id: bank
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: bd.band
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const W = width, H = height, dw = bd.doorW
                    const n = Math.ceil(W / dw)
                    for (let i = 0; i < n; i++) {
                        const x = i * dw
                        // door face
                        ctx.fillStyle = String(chrome.periA(0.16 + chrome.rnd(i * 7 + 1) * 0.06))
                        ctx.fillRect(x + 1, 4, dw - 2, H - 4)
                        // stripe label
                        ctx.fillStyle = String(Qt.rgba(chrome.pink.r, chrome.pink.g, chrome.pink.b,
                                                       chrome.rnd(i * 13 + 3) < 0.6 ? 0.5 : 0.22))
                        ctx.fillRect(x + 6, 10, dw * 0.45, 4)
                        // vent slits
                        ctx.fillStyle = String(Qt.alpha(chrome.pal.dim, 0.5))
                        for (let v = 0; v < 3; v++)
                            ctx.fillRect(x + 8, H - 26 + v * 6, dw - 20, 1.5)
                        // handle
                        ctx.fillStyle = String(Qt.alpha(chrome.pal.dim, 0.8))
                        ctx.fillRect(x + dw - 9, H * 0.45, 3, 9)
                    }
                    // the corridor floor line
                    ctx.fillStyle = String(chrome.chalkA(0.10))
                    ctx.fillRect(0, H - 2, W, 2)
                }
            }
            // chalk guide line above the lockers
            Canvas {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: bd.band + 6
                height: 8
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0) return
                    Chalk.strokePath(ctx, [[8, 4], [width - 8, 3]], {
                        seed: 1301, color: String(chrome.chalkA(1)), alpha: 0.18, width: 2, ghost: false, dust: 0.03
                    })
                }
            }

            // two dust motes hanging in the sun, only while you're here
            Repeater {
                model: 2
                delegate: Rectangle {
                    id: mote
                    required property int index
                    width: 3; height: 3; radius: 1.5
                    color: chrome.sunA(0.8)
                    x: bd.width * (0.30 + index * 0.33)
                    property real t: index * 0.5
                    y: 30 + 40 * t
                    opacity: 0
                    SequentialAnimation on opacity {
                        running: chrome.awake && bd.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 2600 + mote.index * 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.05; duration: 2600 + mote.index * 900; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on t {
                        running: chrome.awake && bd.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 1; duration: 9000 + mote.index * 2400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 9000 + mote.index * 2400; easing.type: Easing.InOutSine }
                    }
                }
            }

            // ── the visit: one door's seam flashes warm ────────────────────
            Rectangle {
                id: seam
                readonly property int door: Math.floor(chrome.rnd(bd.visits * 31 + 7) * Math.max(1, Math.floor(bd.width / bd.doorW)))
                x: door * bd.doorW + bd.doorW - 4
                anchors.bottom: parent.bottom
                width: 3
                height: bd.band - 4
                color: chrome.sunA(0.9)
                opacity: 0
                SequentialAnimation {
                    id: seamFlash
                    NumberAnimation { target: seam; property: "opacity"; from: 0; to: 0.85; duration: 90 }
                    PauseAnimation { duration: 260 }
                    NumberAnimation { target: seam; property: "opacity"; to: 0; duration: 420 }
                }
            }

            // …and a hall pass drops onto the corner
            Item {
                id: pass
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 22
                anchors.topMargin: 12
                width: 64; height: 26
                opacity: 0
                rotation: 3
                transformOrigin: Item.Top
                Rectangle { anchors.fill: parent; radius: 2; color: Qt.rgba(0.96, 0.96, 0.99, 0.92) }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -4; width: 18; height: 7; rotation: -8
                    color: chrome.chalkA(0.5)
                }
                Text {
                    anchors.centerIn: parent
                    text: "hall pass"
                    font.family: chrome.pal.fontMono
                    font.pixelSize: 8
                    font.letterSpacing: 1
                    color: Qt.alpha(chrome.pal.glass, 0.85)
                }
                SequentialAnimation {
                    id: passDrop
                    ParallelAnimation {
                        NumberAnimation { target: pass; property: "opacity"; from: 0; to: 0.95; duration: 160 }
                        NumberAnimation { target: pass; property: "anchors.topMargin"; from: 2; to: 15; duration: 220; easing.type: Easing.OutQuad }
                        NumberAnimation { target: pass; property: "rotation"; from: -6; to: 4.5; duration: 220; easing.type: Easing.OutQuad }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: pass; property: "anchors.topMargin"; to: 12; duration: 150; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: pass; property: "rotation"; to: 3; duration: 150; easing.type: Easing.InOutQuad }
                    }
                    PauseAnimation { duration: 1400 }
                    NumberAnimation { target: pass; property: "opacity"; to: 0; duration: 500 }
                }
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() {
                    bd.visits++                               // the count always ticks
                    if (chrome.awake) { seamFlash.restart(); passDrop.restart() }
                }
            }
        }
    }
}
