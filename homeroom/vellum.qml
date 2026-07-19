import QtQuick
import "chalk.js" as Chalk

// homeroom: study hall. The editor is a desk by the window — a chalk margin
// rule down the left like a ruled notebook, a slate sill along the bottom
// with a dim doodle, and the morning sunbeam leaning across the pane, but
// only while a PAGE is up: the reading gate (awake && page) governs every
// moving thing, so a text buffer being typed into never stirs. When a page
// composes, the teacher underlines today's reading — one chalk line sweeps
// across the top of the window and settles. Dust drifts in the beam while
// you read; the moment you look away or start writing, the room holds still.
Item {
    id: chrome

    required property var pal   // snapshot palette (halo/periwinkle/pink…)
    property var host: null     // vellum window — active, readingMode, pdfMode

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page   // the only thing that may animate

    readonly property color chalk: pal.text
    readonly property color sun: pal.amber
    function chalkA(a) { return Qt.rgba(chalk.r, chalk.g, chalk.b, a) }
    function sunA(a)   { return Qt.rgba(sun.r, sun.g, sun.b, a) }

    // chassis: paper-soft corners, a faint chalk lip
    readonly property color cardBorder: Qt.alpha(chalk, 0.18)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 8

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the sunbeam across the pane — on with the page, off for writing
            Canvas {
                id: beam
                anchors.fill: parent
                opacity: chrome.page ? 0.5 : 0
                Behavior on opacity { NumberAnimation { duration: 500 } }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    // a diagonal shaft from the upper-right
                    const g = ctx.createLinearGradient(width, 0, width * 0.45, height * 0.6)
                    g.addColorStop(0, String(chrome.sunA(0.12)))
                    g.addColorStop(0.55, String(chrome.sunA(0.04)))
                    g.addColorStop(1, String(chrome.sunA(0)))
                    ctx.fillStyle = g
                    ctx.beginPath()
                    ctx.moveTo(width * 0.55, 0)
                    ctx.lineTo(width, 0)
                    ctx.lineTo(width, height * 0.35)
                    ctx.lineTo(width * 0.25, height)
                    ctx.lineTo(width * 0.05, height)
                    ctx.closePath()
                    ctx.fill()
                }
            }

            // the chalk margin rule down the left
            Canvas {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                x: 26
                width: 8
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (height <= 0) return
                    Chalk.strokePath(ctx, [[4, 14], [3, height - 14]], {
                        seed: 1401, color: String(chrome.chalkA(1)), alpha: 0.14, width: 2, ghost: false, dust: 0.02
                    })
                }
            }

            // slate sill along the bottom, with a sleeping doodle
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 34
                color: Qt.alpha(chrome.pal.glass, 0.45)
            }
            Canvas {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 34
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0) return
                    Chalk.strokePath(ctx, [[8, 4], [width - 8, 3]], {
                        seed: 1403, color: String(chrome.chalkA(1)), alpha: 0.20, width: 1.8, ghost: false, dust: 0.03
                    })
                    // zzz — the room reading over your shoulder, half asleep
                    Chalk.strokePath(ctx, [[width - 60, 14], [width - 48, 14], [width - 60, 24], [width - 48, 24]], {
                        seed: 1409, color: String(chrome.chalkA(1)), alpha: 0.22, width: 1.4, ghost: false, dust: 0
                    })
                    Chalk.strokePath(ctx, [[width - 40, 18], [width - 33, 18], [width - 40, 25], [width - 33, 25]], {
                        seed: 1411, color: String(chrome.chalkA(1)), alpha: 0.16, width: 1.2, ghost: false, dust: 0
                    })
                }
            }

            // dust in the beam — reading light only
            Repeater {
                model: 2
                delegate: Rectangle {
                    id: mote
                    required property int index
                    width: 3; height: 3; radius: 1.5
                    color: chrome.sunA(0.85)
                    x: bd.width * (0.58 + index * 0.16)
                    property real t: index * 0.4
                    y: 40 + 120 * t
                    opacity: 0
                    SequentialAnimation on opacity {
                        running: chrome.stirring && bd.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.30; duration: 2800 + mote.index * 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.04; duration: 2800 + mote.index * 700; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on t {
                        running: chrome.stirring && bd.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 1; duration: 11000 + mote.index * 3000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 11000 + mote.index * 3000; easing.type: Easing.InOutSine }
                    }
                }
            }

            // ── today's reading, underlined in chalk as the page composes ──
            Item {
                id: underline
                x: 40
                y: 30
                width: bd.width - 80
                height: 8
                property real t: -1
                visible: t >= 0
                clip: true
                Canvas {
                    id: underlineChalk
                    width: bd.width - 80
                    height: 8
                    // reveal by clipping the parent to t
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        if (width <= 0) return
                        Chalk.strokePath(ctx, [[2, 4], [width - 2, 3]], {
                            seed: 1451, color: String(chrome.chalkA(1)), alpha: 0.45, width: 2.4, dust: 0.08
                        })
                    }
                    Component.onCompleted: requestPaint()
                }
            }
            // the clip: width follows t
            Binding {
                target: underline
                property: "width"
                value: (bd.width - 80) * Math.max(0, Math.min(1, underline.t))
                when: underline.t >= 0
            }
            SequentialAnimation {
                id: sweep
                PropertyAction  { target: underline; property: "t"; value: 0 }
                NumberAnimation { target: underline; property: "t"; from: 0; to: 1; duration: 600; easing.type: Easing.InOutQuad }
                PauseAnimation  { duration: 2200 }
                NumberAnimation { target: underline; property: "opacity"; from: 1; to: 0; duration: 600 }
                PropertyAction  { target: underline; property: "t"; value: -1 }
                PropertyAction  { target: underline; property: "opacity"; value: 1 }
            }
            Connections {
                target: chrome
                function onPageChanged() { if (chrome.page) sweep.restart() }
            }
        }
    }
}
