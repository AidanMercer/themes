import QtQuick

// sailing: dusk at sea behind the page. The horizon blush and the deep water at
// the hull are always there, but the swell only rolls while a page is up —
// becalmed to a single static draw the moment you start writing, the same way
// mica's sea goes still when you look away.
Item {
    id: chrome

    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page

    readonly property color cardBorder: Qt.alpha(pal.dim, 0.55)
    readonly property int cardBorderWidth: 1

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
        }
    }
}
