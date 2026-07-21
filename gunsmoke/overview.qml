import QtQuick

// gunsmoke: the Super+Tab exposé. Every window is a poster nailed up in the
// fog: a hard paper-slab shadow and a nail head above each frame
// (tileUnderlay), corner rivets and a number on the paper (tileOverlay).
// The poster under your eye takes the wax seal — the one oxblood mark on
// the wall (active = the accent is spent). The wall itself breathes: two
// slow fog banks crawl behind the posters while the exposé is up, and the
// tag in the corner counts the windows.
//
// visual-only by contract: no input handlers; every loop gates on
// overview.open (the shell tears the layers down ~300ms after close).
Item {
    id: chrome

    required property var pal        // neon=bone, cyan=gunmetal, magenta=oxblood
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property string serif: "Noto Serif"
    readonly property string mono: pal.fontMono
    function boneA(a)  { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function steelA(a) { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function ashA(a)   { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function px(v) { return Math.round(v * pal.uiScale) }
    // wall tones: pal.glass pulled down toward the night, so config.toml
    // retints the boards along with everything else
    function wall(k) { return Qt.rgba(pal.glass.r * k, pal.glass.g * k, pal.glass.b * k, 1) }

    // ── scalars: paper frames on a dark wall ──
    readonly property color scrimColor: wall(0.42)
    readonly property real scrimOpacity: 0.7
    readonly property bool shadowOn: false                  // hard slab drawn below
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.95)
    readonly property color cardBorder: ashA(0.8)
    readonly property color cardBorderHot: pal.neon
    readonly property color cardBorderCenter: steelA(0.75)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 2
    readonly property int cardBorderWidthCenter: 1
    readonly property int cardRadius: 2                     // paper corners
    readonly property color cardHighlight: "transparent"
    readonly property color thumbBg: wall(0.6)
    readonly property int thumbRadius: 0
    readonly property color titleColor: steelA(0.8)
    readonly property color titleHotColor: pal.neon
    readonly property string titleFont: pal.fontMono
    readonly property string hintFont: pal.fontMono
    readonly property color hintColor: steelA(0.75)
    readonly property string hintText: "⏎ SELECT · ESC CLOSE"
    readonly property string emptyText: "NO WINDOWS"

    // ── backdrop: the wall — fog banks + the wall tag ──
    readonly property Component backdrop: Component {
        Item {
            id: bd
            opacity: chrome.overview.reveal

            // two fog banks crawling behind the posters, slow, opposite ways
            Rectangle {
                id: fogA
                width: bd.width * 0.55
                height: bd.height * 0.30
                radius: height / 2
                y: bd.height * 0.62
                color: chrome.steelA(0.05)
                SequentialAnimation on x {
                    running: chrome.overview.open
                    loops: Animation.Infinite
                    NumberAnimation { from: -fogA.width * 0.4; to: bd.width * 0.7; duration: 46000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -fogA.width * 0.4; duration: 46000; easing.type: Easing.InOutSine }
                }
            }
            Rectangle {
                id: fogB
                width: bd.width * 0.4
                height: bd.height * 0.22
                radius: height / 2
                y: bd.height * 0.16
                color: chrome.boneA(0.035)
                SequentialAnimation on x {
                    running: chrome.overview.open
                    loops: Animation.Infinite
                    NumberAnimation { from: bd.width * 0.8; to: -fogB.width * 0.5; duration: 58000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: bd.width * 0.8; duration: 58000; easing.type: Easing.InOutSine }
                }
            }

            // the wall tag, top-left: the window count in the ledger's hand
            Row {
                x: chrome.px(30); y: chrome.px(26)
                spacing: 8
                Rectangle { width: chrome.px(30); height: 1; color: chrome.ashA(1); anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: String(chrome.overview.windows.length).padStart(2, "0") + " WINDOWS"
                    font.family: chrome.mono
                    font.pixelSize: chrome.px(10)
                    font.letterSpacing: 3
                    color: chrome.ashA(1)
                }
            }

            // the wall's foot: one dim rule where the boards meet
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: chrome.px(28)
                width: parent.width
                height: 1
                color: chrome.ashA(0.35)
            }
        }
    }

    // ── per-tile: paper-slab shadow + the nail it hangs from ──
    readonly property Component tileUnderlay: Component {
        Item {
            property var tile: null
            // hard slab, offset down-right — paper on boards, no soft blur
            Rectangle {
                x: chrome.px(4); y: chrome.px(4)
                width: parent.width; height: parent.height
                color: chrome.wall(0.27)
                opacity: 0.85
            }
            // the nail head above the poster
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -chrome.px(4)
                width: chrome.px(5); height: chrome.px(5); radius: chrome.px(2.5)
                color: chrome.boneA(0.8)
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.6)
            }
        }
    }

    // ── per-tile: rivets, the file number, and the wax seal on the hot mark ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false
            readonly property bool ctr: tile ? tile.isCenter === true : false

            // corner rivets on the paper
            Repeater {
                model: 4
                delegate: Rectangle {
                    required property int index
                    width: chrome.px(3); height: width; radius: width / 2
                    x: index % 2 === 0 ? chrome.px(3) : ov.width - width - chrome.px(3)
                    y: index < 2 ? chrome.px(3) : ov.height - height - chrome.px(3)
                    color: ov.hot ? chrome.boneA(0.9) : chrome.ashA(0.9)
                }
            }

            // the wax seal — the wall's one red mark, pressed onto the poster
            // under your eye. It STAMPS when it lands (hammer law).
            Rectangle {
                id: seal
                visible: ov.hot
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: chrome.px(8)
                anchors.bottomMargin: chrome.px(8)
                width: chrome.px(14); height: width; radius: width / 2
                color: chrome.pal.magenta
                Rectangle {
                    anchors.centerIn: parent
                    width: chrome.px(5); height: chrome.px(5); radius: chrome.px(2.5)
                    color: Qt.rgba(0, 0, 0, 0.35)
                }
                onVisibleChanged: if (visible) press.restart()
                NumberAnimation {
                    id: press
                    target: seal; property: "scale"
                    from: 1.6; to: 1; duration: 90; easing.type: Easing.OutQuad
                }
            }

            // tag on the poster you rode in on
            Rectangle {
                visible: ov.ctr
                x: chrome.px(6)
                y: -chrome.px(9)
                width: claimed.implicitWidth + chrome.px(12)
                height: chrome.px(16)
                color: chrome.wall(0.6)
                border.color: chrome.boneA(0.6)
                border.width: 1
                Text {
                    id: claimed
                    anchors.centerIn: parent
                    text: "CURRENT"
                    font.family: chrome.serif
                    font.pixelSize: chrome.px(10)
                    font.weight: Font.Black
                    font.letterSpacing: 2
                    color: chrome.boneA(0.9)
                }
            }

            // the tile number, bottom-left in the ledger's data hand
            Text {
                anchors.left: parent.left
                anchors.leftMargin: chrome.px(8)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: chrome.px(5)
                text: "№ " + String((ov.tile ? ov.tile.index : 0) + 1).padStart(2, "0")
                font.family: chrome.mono
                font.pixelSize: chrome.px(8)
                color: ov.hot ? chrome.boneA(0.9) : chrome.ashA(0.9)
            }
        }
    }
}
