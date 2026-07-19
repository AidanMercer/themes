import QtQuick

// gunsmoke: ledger chrome for vellum — WRITING IN THE LEDGER ITSELF. The
// editor is the dead man's book: a double vertical margin rule down the left
// (every ledger page has one), a double rule under the head, and fog resting
// at the foot of the page that breathes only while a page is up in a focused
// window (the reading gate — a buffer being typed into never stirs). When a
// page composes, a powder line burns across the top edge — one spark
// crossing left to right, its trail thinning like a lit fuse — vellum's
// hammer-event at page scale.
Item {
    id: chrome

    required property var pal   // snapshot palette (bone/gunmetal/oxblood/…)
    property var host: null     // vellum window — active, readingMode, pdfMode

    // the reading gate: nothing moves behind a text column being typed into
    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page   // the only thing that may animate

    function boneA(a)  { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function steelA(a) { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }

    // chassis: paper corners, bone hairline
    readonly property color cardBorder: Qt.alpha(pal.neon, 0.26)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 6

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // double rule under the head
            Rectangle { x: 12; y: 8; width: parent.width - 24; height: 1; color: chrome.boneA(0.22) }
            Rectangle { x: 12; y: 11; width: parent.width - 24; height: 1; color: chrome.boneA(0.08) }

            // the ledger's margin: a double vertical rule down the left
            Rectangle { x: 44; y: 16; width: 1; height: parent.height - 32; color: chrome.boneA(0.10) }
            Rectangle { x: 48; y: 16; width: 1; height: parent.height - 32; color: chrome.boneA(0.05) }

            // corner rivets, foot only — the head belongs to the rules
            Rectangle { x: 5; y: bd.height - 8; width: 3; height: 3; radius: 1.5; color: chrome.boneA(0.35) }
            Rectangle { x: bd.width - 8; y: bd.height - 8; width: 3; height: 3; radius: 1.5; color: chrome.boneA(0.35) }

            // fog at the foot of the page — stirs only while reading
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * 0.14
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.steelA(0.055) }
                }
                opacity: chrome.page ? 1 : 0.3
                Behavior on opacity { NumberAnimation { duration: 700 } }
                SequentialAnimation on height {
                    running: chrome.stirring && bd.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: bd.height * 0.18; duration: 6500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: bd.height * 0.13; duration: 6500; easing.type: Easing.InOutSine }
                }
            }

            // ── the page composes: a powder line burns across the top edge ──
            Item {
                id: fuse
                property real t: -1
                visible: t >= 0
                readonly property real tt: Math.max(0, t)
                y: 9
                // the spark
                Rectangle {
                    x: fuse.tt * bd.width - 2
                    y: -1
                    width: 4; height: 4; radius: 2
                    color: chrome.boneA(1)
                }
                // the burnt trail, thinning behind the spark
                Rectangle {
                    x: Math.max(0, fuse.tt * bd.width - 120)
                    width: Math.min(120, fuse.tt * bd.width)
                    height: 1.5
                    color: chrome.boneA(0.35 * (1 - fuse.tt * 0.6))
                }
                NumberAnimation {
                    id: fuseAnim
                    target: fuse; property: "t"
                    from: 0; to: 1; duration: 600; easing.type: Easing.InOutQuad
                    onStopped: fuse.t = -1
                }
            }
            Connections {
                target: chrome
                // gate on page, not stirring — alt-tab must not re-fire it
                function onPageChanged() { if (chrome.stirring) fuseAnim.restart() }
            }
        }
    }
}
