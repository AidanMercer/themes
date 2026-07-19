import QtQuick
import "chalk.js" as Chalk

// homeroom: the staff room. Calls happen here, so the room keeps its head
// down: under the glass bars, just a breath of morning sun from the top and
// two faint chalk corner ticks; above the page, nothing resident at all.
// Each rail navigation — chat, calendar, activity — is one chalk underline
// swept under the titlebar, then stillness. Chrome + voice only.
Item {
    id: chrome

    required property var pal   // snapshot palette (halo/periwinkle/pink…)
    property var host: null     // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property color chalk: pal.text
    readonly property color sun: pal.amber
    function chalkA(a) { return Qt.rgba(chalk.r, chalk.g, chalk.b, a) }
    function sunA(a)   { return Qt.rgba(sun.r, sun.g, sun.b, a) }

    readonly property string wordmark: "▪ staff room"

    readonly property Component backdrop: Component {
        Item {
            // morning sun, barely, from the top
            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: Math.min(70, parent.height * 0.2)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.sunA(0.07) }
                    GradientStop { position: 1.0; color: chrome.sunA(0.0) }
                }
            }
            // chalk corner ticks
            Canvas {
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    const c = String(chrome.chalkA(1))
                    Chalk.strokePath(ctx, [[8, 30], [8, 8], [30, 8]],
                        { seed: 1801, color: c, alpha: 0.16, width: 1.8, ghost: false, dust: 0 })
                    Chalk.strokePath(ctx, [[width - 8, height - 30], [width - 8, height - 8], [width - 30, height - 8]],
                        { seed: 1807, color: c, alpha: 0.16, width: 1.8, ghost: false, dust: 0 })
                }
            }
        }
    }

    // ── one chalk underline per rail hop, then quiet ───────────────────────
    readonly property Component overlay: Component {
        Item {
            id: ov

            Item {
                id: line
                x: 14
                y: 40
                width: ov.width * 0.34
                height: 8
                property real t: -1
                visible: t >= 0
                clip: true
                Canvas {
                    width: ov.width * 0.34
                    height: 8
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        if (width <= 0) return
                        Chalk.strokePath(ctx, [[2, 4], [width - 2, 3]], {
                            seed: 1901, color: String(chrome.chalkA(1)), alpha: 0.4, width: 2, ghost: false, dust: 0.04
                        })
                    }
                    Component.onCompleted: requestPaint()
                }
            }
            Binding {
                target: line
                property: "width"
                value: ov.width * 0.34 * Math.max(0, Math.min(1, line.t * 1.3))
                when: line.t >= 0
            }
            SequentialAnimation {
                id: hop
                PropertyAction  { target: line; property: "t"; value: 0 }
                NumberAnimation { target: line; property: "t"; from: 0; to: 1; duration: 550; easing.type: Easing.InOutQuad }
                PauseAnimation  { duration: 500 }
                NumberAnimation { target: line; property: "opacity"; from: 1; to: 0; duration: 350 }
                PropertyAction  { target: line; property: "t"; value: -1 }
                PropertyAction  { target: line; property: "opacity"; value: 1 }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) hop.restart() }
            }
        }
    }
}
