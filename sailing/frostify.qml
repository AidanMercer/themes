import QtQuick

// sailing: dusk at sea behind the panes — a lavender horizon low in the frame
// and one long swell rolling through it while the music plays; the water goes
// still when it stops.
Item {
    id: chrome

    required property var pal
    property var host: null

    readonly property bool playing: host && host.np
                                    && host.np.active === true && host.np.isPlaying === true
    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBorder: Qt.alpha(pal.dim, 0.55)
    readonly property int cardBorderWidth: 1

    // logbook voice
    readonly property string statusPlaying: "▶ UNDER SAIL"
    readonly property string statusPaused: "⏸ BECALMED"
    readonly property string statusStopped: "■ ANCHORED"
    readonly property string wordmark: "⚓ adrift"
    readonly property string glyphPinned: "☸"
    readonly property string glyphRecent: "🧭"
    readonly property string glyphPlaylist: "⛵"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the whole sea in one pass: horizon blush, rolling wave contours,
            // deep water at the hull — becalmed to a static draw when paused
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("sea.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.playing && chrome.awake && bd.visible
                }
            }
        }
    }
}
