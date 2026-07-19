import QtQuick

// gunsmoke: ledger chrome for mica — THE ARCHIVE. The miller columns sit on
// ruled ledger paper: faint horizontal ruling across the lower band, double
// rule under the head, corner rivets, fog pooling at the foot. Every
// directory change FILES the entry: an oxblood-free ink stamp — "FILED", set
// crooked in serif blacks — slams down bottom-right (hammer law) and thins
// away like smoke, while a wisp curls off the seam. Idle motion: none worth
// the candle — one fog bank breathes, and only while the window is watched.
Item {
    id: chrome

    required property var pal   // snapshot palette (bone/gunmetal/oxblood/…)
    property var host: null     // mica window — active (focus), navId (cwd)

    readonly property bool awake: host ? host.active === true : false

    readonly property string serif: "Noto Serif"
    function boneA(a)  { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function steelA(a) { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function ashA(a)   { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    // chassis: paper corners, bone hairline
    readonly property color cardBorder: Qt.alpha(pal.neon, 0.28)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 6

    readonly property string wordmark: "№ 1887 · THE ARCHIVE"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // double rule under the head
            Rectangle { x: 12; y: 8; width: parent.width - 24; height: 1; color: chrome.boneA(0.26) }
            Rectangle { x: 12; y: 11; width: parent.width - 24; height: 1; color: chrome.boneA(0.09) }
            // corner rivets
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 3; height: 3; radius: 1.5
                    x: index % 2 === 0 ? 5 : bd.width - 8
                    y: index < 2 ? 5 : bd.height - 8
                    color: chrome.boneA(0.38)
                }
            }

            // ledger ruling across the lower band — the page under the files
            Canvas {
                id: ruling
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.min(220, parent.height * 0.4)
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = String(chrome.boneA(0.045))
                    ctx.lineWidth = 1
                    for (let y = 12; y < height; y += 26) {
                        ctx.beginPath(); ctx.moveTo(14, y); ctx.lineTo(width - 14, y); ctx.stroke()
                    }
                }
            }

            // fog pooling at the foot, breathing only while watched
            Rectangle {
                id: fog
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * 0.16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.steelA(0.06) }
                }
                SequentialAnimation on opacity {
                    running: chrome.awake && bd.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.55; duration: 6000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 6000; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // ── every directory change files the entry ──────────────────────────────
    readonly property Component overlay: Component {
        Item {
            id: ov

            // the FILED stamp, set crooked, slams and thins away
            Item {
                id: stamp
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 34
                anchors.bottomMargin: 40
                width: filedText.implicitWidth + 22
                height: filedText.implicitHeight + 10
                rotation: -7
                opacity: 0
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 2
                    border.color: chrome.boneA(0.75)
                }
                Text {
                    id: filedText
                    anchors.centerIn: parent
                    text: "FILED"
                    font.family: chrome.serif
                    font.pixelSize: 15
                    font.weight: Font.Black
                    font.letterSpacing: 6
                    color: chrome.boneA(0.85)
                }
            }
            SequentialAnimation {
                id: stampAnim
                // hammer: the slam
                ParallelAnimation {
                    NumberAnimation { target: stamp; property: "scale"; from: 1.5; to: 1; duration: 90; easing.type: Easing.OutQuad }
                    PropertyAction { target: stamp; property: "opacity"; value: 0.9 }
                }
                PauseAnimation { duration: 450 }
                // smoke: the thinning
                NumberAnimation { target: stamp; property: "opacity"; to: 0; duration: 650; easing.type: Easing.OutQuad }
            }

            // the wisp off the seam
            Item {
                id: puff
                x: ov.width * 0.5
                y: 24
                property real t: -1
                visible: t >= 0
                readonly property real tt: Math.max(0, t)
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        x: (index - 1) * 9 + Math.sin((puff.tt + index * 0.4) * 6) * 4
                        y: -puff.tt * (16 + index * 6)
                        width: (4 + index * 2) * (1 + puff.tt * 1.5)
                        height: width
                        radius: width / 2
                        color: chrome.boneA(0.16 * (1 - puff.tt))
                    }
                }
                NumberAnimation {
                    id: puffAnim
                    target: puff; property: "t"
                    from: 0; to: 1; duration: 850; easing.type: Easing.OutQuad
                    onStopped: puff.t = -1
                }
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() {
                    if (chrome.awake) { stampAnim.restart(); puffAnim.restart() }
                }
            }
        }
    }
}
