import QtQuick

// sleeper: berth-radio chrome for frostify. The player is the little radio
// shelf by the window: a warm reading-lamp pool that breathes while music
// plays, a wooden sill along the foot of the window, and on every track
// change a lamp passes across the panes — light arrives as passing glows in
// this compartment, nothing pops. Berth voice in the status pill. Same
// grammar as popup.qml: invisible root, frostify mounts backdrop below and
// overlay above its panes.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon/cyan/magenta/…)
    property var host: null     // frostify window — np, npTrackId, active

    readonly property bool playing: host && host.np
                                    && host.np.active === true && host.np.isPlaying === true
    readonly property bool awake: host ? host.active === true : false

    function teaA(a)   { return Qt.rgba(pal.amber.r, pal.amber.g, pal.amber.b, a) }
    function greenA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function linenA(a) { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function woodA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    // chassis: paper corners, warm edge
    readonly property color cardBorder: Qt.alpha(pal.amber, 0.4)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 8

    // berth voice
    readonly property string statusPlaying: "♪ NIGHT PROGRAMME"
    readonly property string statusPaused: "❙❙ GONE COLD"
    readonly property string statusStopped: "■ LIGHTS OUT"
    readonly property string wordmark: "☾ berth radio"
    readonly property string glyphPrev: "«"
    readonly property string glyphNext: "»"
    readonly property string glyphNowPlaying: "☾"
    readonly property string glyphLiked: "●"
    readonly property string glyphPinned: "◆"
    readonly property string glyphRecent: "○"
    readonly property string glyphDesktop: "⌂"
    readonly property string glyphPlaylist: "◇"

    // ── backdrop: the shelf under the window ────────────────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // murky city green resting in the lower window corners
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.75; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.greenA(0.05) }
                }
            }
            // the reading lamp's pool, top right — breathing only while playing
            Rectangle {
                id: lampPool
                anchors.right: parent.right
                anchors.top: parent.top
                width: parent.width * 0.4
                height: parent.height * 0.3
                opacity: 0.5
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.teaA(0.10) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
                SequentialAnimation on opacity {
                    running: chrome.playing && chrome.awake
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.9; duration: 2600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.4; duration: 2600; easing.type: Easing.InOutSine }
                }
            }
            // the wooden sill along the foot
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                width: parent.width
                height: 1
                color: chrome.teaA(0.3)
            }
            // doily punch-dots along the top edge
            Row {
                anchors.top: parent.top
                anchors.topMargin: 5
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 11
                Repeater {
                    model: Math.max(4, Math.floor((bd.width - 80) / 19))
                    Rectangle { width: 2; height: 2; radius: 1; color: chrome.linenA(0.22) }
                }
            }
        }
    }

    // ── overlay: the passing lamp on every track change ─────────────────────
    readonly property Component overlay: Component {
        Item {
            id: ovl
            clip: true
            Rectangle {
                id: passing
                property real t: -1
                visible: t >= 0
                width: ovl.width * 0.35
                height: ovl.height * 1.6
                y: -ovl.height * 0.3
                x: -width + (ovl.width + width * 2) * Math.max(0, t)
                rotation: 12
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: chrome.teaA(0.0) }
                    GradientStop { position: 0.5; color: chrome.teaA(0.10) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
            }
            SequentialAnimation {
                id: sweep
                NumberAnimation { target: passing; property: "t"; from: 0; to: 1; duration: 1100; easing.type: Easing.InOutSine }
                PropertyAction { target: passing; property: "t"; value: -1 }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNpTrackIdChanged() { if (chrome.host.npTrackId && chrome.awake) sweep.restart() }
            }
        }
    }
}
