import QtQuick

// gunsmoke: ledger chrome for frostify — THE SALOON. The band plays behind
// the fog: a low fog bank breathes at the foot of the window while music
// runs and holds dead still otherwise. Double-rule frame, corner rivets.
// Every track change is a hammer event — one frame of bone flash across the
// window and a wisp of powder smoke curling off the top rail, then quiet.
// Layout stays frostify's own; this is chrome, effects and voice.
Item {
    id: chrome

    required property var pal   // snapshot palette (bone/gunmetal/oxblood/…)
    property var host: null     // frostify window — np, npTrackId, active

    readonly property bool playing: host && host.np
                                    && host.np.active === true && host.np.isPlaying === true
    readonly property bool awake: host ? host.active === true : false

    function boneA(a)  { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function steelA(a) { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function ashA(a)   { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    // chassis: paper corners, bone hairline
    readonly property color cardBorder: Qt.alpha(pal.neon, 0.3)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 6

    // the saloon's voice
    readonly property string statusPlaying: "▶ THE BAND PLAYS"
    readonly property string statusPaused: "⏸ HELD"
    readonly property string statusStopped: "■ SILENCE"
    readonly property string wordmark: "№ 1887 · THE SALOON"
    readonly property string glyphPrev: "«"
    readonly property string glyphNext: "»"
    readonly property string glyphPlay: "▶"
    readonly property string glyphPause: "⏸"
    readonly property string glyphNowPlaying: "▸"
    readonly property string glyphLiked: "✦"
    readonly property string glyphPinned: "✦"
    readonly property string glyphRecent: "·"
    readonly property string glyphDesktop: "▪"
    readonly property string glyphPlaylist: "≡"

    // ── backdrop: rules, rivets, and the fog at the foot ────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // double ledger rule inside the top edge
            Rectangle { x: 12; y: 8; width: parent.width - 24; height: 1; color: chrome.boneA(0.28) }
            Rectangle { x: 12; y: 11; width: parent.width - 24; height: 1; color: chrome.boneA(0.10) }
            // corner rivets
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 3; height: 3; radius: 1.5
                    x: index % 2 === 0 ? 5 : bd.width - 8
                    y: index < 2 ? 5 : bd.height - 8
                    color: chrome.boneA(0.4)
                }
            }

            // the fog bank at the foot — breathes only while the band plays
            Rectangle {
                id: fog
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * 0.22
                opacity: chrome.playing ? 1 : 0.35
                // smoke law: slow to leave
                Behavior on opacity { NumberAnimation { duration: 900 } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.steelA(0.07) }
                }
                SequentialAnimation on height {
                    running: chrome.playing && chrome.awake
                    loops: Animation.Infinite
                    NumberAnimation { to: bd.height * 0.28; duration: 5200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: bd.height * 0.20; duration: 5200; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // ── overlay: the track-change hammer ────────────────────────────────────
    readonly property Component overlay: Component {
        Item {
            id: ov

            // one frame of bone across the window
            Rectangle {
                id: flash
                anchors.fill: parent
                color: chrome.boneA(1)
                opacity: 0
            }
            SequentialAnimation {
                id: hammer
                PropertyAction { target: flash; property: "opacity"; value: 0.12 }
                PauseAnimation { duration: 50 }
                NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 260; easing.type: Easing.OutQuad }
            }

            // powder smoke off the top rail
            Item {
                id: puff
                x: ov.width * 0.5
                y: 26
                property real t: -1
                visible: t >= 0
                readonly property real tt: Math.max(0, t)
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        x: (index - 1) * 10 + Math.sin((puff.tt + index * 0.4) * 6) * 5
                        y: -puff.tt * (18 + index * 7)
                        width: (5 + index * 2) * (1 + puff.tt * 1.5)
                        height: width
                        radius: width / 2
                        color: chrome.boneA(0.18 * (1 - puff.tt))
                    }
                }
                NumberAnimation {
                    id: puffAnim
                    target: puff; property: "t"
                    from: 0; to: 1; duration: 900; easing.type: Easing.OutQuad
                    onStopped: puff.t = -1
                }
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNpTrackIdChanged() {
                    if (chrome.awake) { hammer.restart(); puffAnim.restart() }
                }
            }
        }
    }
}
