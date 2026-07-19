import QtQuick
import "chalk.js" as Chalk

// homeroom: the hall pass. The browser is permission to leave the room —
// the tab strip rides a chalk guide line, a stripe of locker pink runs
// above the status bar, tiny bunting hangs at the far right of the tabs,
// and morning sun leans over the top corner. Every committed navigation a
// folded paper note slides along the seam under the tabs, fluttering as it
// goes — passed down the corridor, gone. The page owns the middle of the
// window; everything here lives in the chrome bands. Chrome + voice only,
// still whenever you look away.
Item {
    id: chrome

    required property var pal   // snapshot palette (halo/periwinkle/pink…)
    property var host: null     // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    readonly property color chalk: pal.text
    readonly property color pink: pal.magenta
    readonly property color sun: pal.amber
    function chalkA(a) { return Qt.rgba(chalk.r, chalk.g, chalk.b, a) }
    function sunA(a)   { return Qt.rgba(sun.r, sun.g, sun.b, a) }

    // chassis: paper-soft corners, a faint chalk lip
    readonly property color cardBorder: Qt.alpha(chalk, 0.22)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 8

    readonly property string wordmark: "☼ hall pass"

    // the seam between the tab strip and the page
    readonly property int seamY: 42

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // sun over the top-right corner of the chrome band
            Canvas {
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    const g = ctx.createRadialGradient(width * 0.92, 0, 0, width * 0.92, 0, width * 0.4)
                    g.addColorStop(0, String(chrome.sunA(0.12)))
                    g.addColorStop(1, String(chrome.sunA(0)))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, Math.min(height, 120))
                }
            }

            // the chalk guide line the tabs sit on
            Canvas {
                y: chrome.seamY
                width: bd.width
                height: 8
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0) return
                    Chalk.strokePath(ctx, [[10, 3], [width - 10, 4]], {
                        seed: 1501, color: String(chrome.chalkA(1)), alpha: 0.20, width: 2, ghost: false, dust: 0.03
                    })
                }
            }

            // tiny bunting at the far right of the tab strip
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 14
                y: 8
                spacing: 6
                Repeater {
                    model: 3
                    delegate: Canvas {
                        required property int index
                        width: 9; height: 11
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const col = index === 0 ? chrome.pink
                                      : index === 1 ? chrome.pal.neon : chrome.chalk
                            ctx.beginPath()
                            ctx.moveTo(0.5, 0.5); ctx.lineTo(8.5, 0.5); ctx.lineTo(4.5, 10)
                            ctx.closePath()
                            ctx.fillStyle = String(Qt.rgba(col.r, col.g, col.b, 0.42))
                            ctx.fill()
                        }
                        Component.onCompleted: requestPaint()
                    }
                }
            }

            // the locker stripe above the status bar
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26
                width: parent.width
                height: 2
                color: Qt.rgba(chrome.pink.r, chrome.pink.g, chrome.pink.b, 0.30)
            }
        }
    }

    // ── every navigation, a note passed down the corridor ──────────────────
    readonly property Component overlay: Component {
        Item {
            id: ov
            Item {
                id: note
                property real t: -1
                visible: t >= 0
                y: chrome.seamY - 6
                x: -30 + (ov.width + 60) * Math.max(0, t)
                rotation: Math.sin(Math.max(0, t) * 18) * 7    // the flutter
                Rectangle {   // a folded paper note
                    width: 16; height: 11
                    radius: 1
                    color: Qt.rgba(0.96, 0.96, 0.99, 0.95)
                }
                Rectangle {   // the fold
                    x: 7; y: 0
                    width: 1.5; height: 11
                    color: Qt.rgba(0, 0, 0, 0.18)
                }
                NumberAnimation {
                    id: passNote
                    target: note; property: "t"
                    from: 0; to: 1; duration: 800; easing.type: Easing.InOutQuad
                    onStopped: note.t = -1
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) passNote.restart() }
            }
        }
    }
}
