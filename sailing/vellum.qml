import QtQuick

// sailing: dusk at sea behind the page. The horizon blush and the deep water
// at the hull are always there, but the swell only rolls while a page is up —
// becalmed to a single static draw the moment you start writing, the same way
// mica's sea goes still when you look away. A brass reading lamp hangs from
// the deckhead top-right: lit while you read, banked low while you write, and
// the wick catches — one flare, then steady — as each page composes.
Item {
    id: chrome

    required property var pal
    property var host: null    // vellum window — active, readingMode, pdfMode

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page

    readonly property color cardBorder: Qt.alpha(pal.dim, 0.55)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 14   // porthole-round, the popup's corner

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the whole sea in one pass: horizon blush, rolling wave contours,
            // deep water at the hull
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("sea.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.stirring && bd.visible
                }
            }

            // the reading lamp: a brass point on a short hanger wire. The
            // opacity and the flare are the only things that ever move — a
            // property fade on the reading gate and a 700ms one-shot.
            Item {
                id: lamp
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.rightMargin: 22
                width: 24; height: 30
                opacity: chrome.page ? 0.95 : 0.4
                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                property real flare: 0    // spiked to 1 as a page composes, decays to steady

                // hanger wire from the deckhead
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 0; width: 1; height: 14
                    color: Qt.alpha(chrome.pal.amber, 0.55)
                }
                // the halo swells with the flare, then settles
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 17 - height / 2
                    width: 16 + 14 * lamp.flare
                    height: width
                    radius: width / 2
                    color: Qt.alpha(chrome.pal.amber, 0.10 + 0.22 * lamp.flare)
                }
                // the wick
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 17 - height / 2
                    width: 5; height: 5; radius: 2.5
                    color: Qt.alpha(chrome.pal.amber, 0.75 + 0.25 * lamp.flare)
                }

                NumberAnimation {
                    id: flareAnim
                    target: lamp; property: "flare"
                    from: 1; to: 0; duration: 700
                    easing.type: Easing.OutQuad
                }
                Connections {
                    target: chrome
                    function onPageChanged() { if (chrome.stirring) flareAnim.restart() }
                }
            }
        }
    }
}
