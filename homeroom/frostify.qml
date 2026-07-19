import QtQuick
import "chalk.js" as Chalk

// homeroom: the morning broadcast. Music in the empty classroom — sun
// washing in from the top-right of the window, bunting strung along the
// top that sways only while the music actually plays, a chalk rule and a
// slate doodle band along the bottom. Every track change, a new photo is
// pinned to the bottom-right corner: it drops in, sticks, and settles a
// little crooked, the way everything on this board does. Chrome + voice
// only; the layout stays frostify's own.
Item {
    id: chrome

    required property var pal   // snapshot palette (halo/periwinkle/pink…)
    property var host: null     // frostify window — active (focus), np, npTrackId

    readonly property bool awake: host ? host.active === true : false
    readonly property bool playing: host && host.np
                                    && host.np.active === true && host.np.isPlaying === true

    readonly property color chalk: pal.text
    readonly property color halo: pal.neon
    readonly property color pink: pal.magenta
    readonly property color sun: pal.amber
    function chalkA(a) { return Qt.rgba(chalk.r, chalk.g, chalk.b, a) }
    function sunA(a)   { return Qt.rgba(sun.r, sun.g, sun.b, a) }

    // chassis: paper-soft corners, a faint chalk lip
    readonly property color cardBorder: Qt.alpha(chalk, 0.22)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 8

    // the broadcast's voice
    readonly property string statusPlaying: "♪ on air (quietly)"
    readonly property string statusPaused: "▮▮ between songs"
    readonly property string statusStopped: "□ before the bell"
    readonly property string wordmark: "☼ morning broadcast"
    readonly property string glyphPrev: "◁◁"
    readonly property string glyphPlay: "▷"
    readonly property string glyphPause: "▮▮"
    readonly property string glyphNext: "▷▷"
    readonly property string glyphNowPlaying: "♪"
    readonly property string glyphLiked: "♥"
    readonly property string glyphPinned: "◦"
    readonly property string glyphRecent: "↺"
    readonly property string glyphDesktop: "⌂"
    readonly property string glyphPlaylist: "≡"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // morning sun, washing in from the upper-right
            Canvas {
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    const g = ctx.createRadialGradient(width * 0.85, 0, 0, width * 0.85, 0, width * 0.75)
                    g.addColorStop(0, String(chrome.sunA(0.13)))
                    g.addColorStop(1, String(chrome.sunA(0)))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
            }

            // the bunting string
            Rectangle {
                x: 0; y: 12
                width: parent.width
                height: 1
                color: chrome.chalkA(0.16)
            }
            // flags — swaying gently, but only while the music plays
            Row {
                x: 18; y: 12
                spacing: Math.max(28, (bd.width - 60) / 12)
                Repeater {
                    model: 9
                    delegate: Canvas {
                        id: flag
                        required property int index
                        width: 14; height: 17
                        transformOrigin: Item.Top
                        rotation: 0
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const col = index % 3 === 0 ? chrome.pink
                                      : index % 3 === 1 ? chrome.halo : chrome.chalk
                            ctx.beginPath()
                            ctx.moveTo(1, 1); ctx.lineTo(13, 1); ctx.lineTo(7, 15)
                            ctx.closePath()
                            ctx.fillStyle = String(Qt.rgba(col.r, col.g, col.b, 0.34))
                            ctx.fill()
                        }
                        Component.onCompleted: requestPaint()
                        SequentialAnimation on rotation {
                            running: chrome.playing && chrome.awake && bd.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 2.4; duration: 1700 + (flag.index % 4) * 300; easing.type: Easing.InOutSine }
                            NumberAnimation { to: -2.4; duration: 1700 + (flag.index % 4) * 300; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }

            // slate band along the bottom with a chalk rule and a doodle
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 44
                color: Qt.alpha(chrome.pal.glass, 0.5)
            }
            Canvas {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 44
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0) return
                    Chalk.strokePath(ctx, [[10, 6], [width - 10, 5]], {
                        seed: 1201, color: String(chrome.chalkA(1)), alpha: 0.25, width: 2, dust: 0.05
                    })
                    // a little chalk quaver by the left edge
                    Chalk.strokePath(ctx, [[22, 34], [22, 18], [30, 15], [30, 31]], {
                        seed: 1207, color: String(chrome.chalkA(1)), alpha: 0.35, width: 1.8, ghost: false, dust: 0
                    })
                }
            }

            // ── every track change: a new photo is pinned bottom-right ─────
            Item {
                id: photo
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 26
                anchors.bottomMargin: 54
                width: 54; height: 44
                opacity: 0
                rotation: 4
                transformOrigin: Item.Top
                Rectangle {   // the mat
                    anchors.fill: parent
                    radius: 2
                    color: Qt.rgba(0.96, 0.96, 0.99, 0.9)
                }
                Rectangle {   // the picture: a wash of the halo's morning
                    x: 4; y: 4
                    width: parent.width - 8; height: parent.height - 14
                    radius: 1
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.alpha(chrome.halo, 0.75) }
                        GradientStop { position: 1.0; color: Qt.alpha(chrome.pink, 0.45) }
                    }
                }
                Rectangle {   // tape
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -5
                    width: 22; height: 8
                    rotation: -6
                    color: chrome.chalkA(0.5)
                }
                SequentialAnimation {
                    id: pinPhoto
                    ParallelAnimation {
                        NumberAnimation { target: photo; property: "opacity"; from: 0; to: 0.9; duration: 200 }
                        NumberAnimation { target: photo; property: "anchors.bottomMargin"; from: 66; to: 51; duration: 240; easing.type: Easing.OutQuad }
                        NumberAnimation { target: photo; property: "rotation"; from: -7; to: 5.5; duration: 240; easing.type: Easing.OutQuad }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: photo; property: "anchors.bottomMargin"; to: 54; duration: 180; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: photo; property: "rotation"; to: 4; duration: 180; easing.type: Easing.InOutQuad }
                    }
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNpTrackIdChanged() { if (chrome.awake) pinPhoto.restart() }
            }
        }
    }
}
