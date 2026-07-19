import QtQuick

// gunsmoke: ledger chrome for cobalt — THE MARSHAL'S OFFICE. Restrained by
// order: this is the window Aidan takes calls in, so the chrome is only the
// stationery — a double rule under the titlebar, corner rivets, the
// faintest fog resting at the foot (static, no loops), all mounted UNDER
// the glass bars and the page. A rail navigation is one small wisp of
// powder smoke off the titlebar seam, then stillness.
Item {
    id: chrome

    required property var pal   // snapshot palette (bone/gunmetal/oxblood/…)
    property var host: null     // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    function boneA(a)  { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function steelA(a) { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }

    readonly property string wordmark: "№ 1887 · MARSHAL'S WIRE"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // double rule under the titlebar
            Rectangle { x: 12; y: 8; width: parent.width - 24; height: 1; color: chrome.boneA(0.22) }
            Rectangle { x: 12; y: 11; width: parent.width - 24; height: 1; color: chrome.boneA(0.08) }
            // corner rivets
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 3; height: 3; radius: 1.5
                    x: index % 2 === 0 ? 5 : bd.width - 8
                    y: index < 2 ? 5 : bd.height - 8
                    color: chrome.boneA(0.32)
                }
            }
            // fog at the foot — static, the office holds still
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * 0.10
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.steelA(0.05) }
                }
            }
        }
    }

    // ── a rail hop: one wisp off the titlebar, then quiet ──────────────────
    readonly property Component overlay: Component {
        Item {
            id: ov
            Item {
                id: puff
                x: ov.width * 0.5
                y: 30
                property real t: -1
                visible: t >= 0
                readonly property real tt: Math.max(0, t)
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        x: (index - 1) * 8 + Math.sin((puff.tt + index * 0.4) * 6) * 4
                        y: -puff.tt * (14 + index * 5)
                        width: (4 + index * 2) * (1 + puff.tt * 1.4)
                        height: width
                        radius: width / 2
                        color: chrome.boneA(0.13 * (1 - puff.tt))
                    }
                }
                NumberAnimation {
                    id: puffAnim
                    target: puff; property: "t"
                    from: 0; to: 1; duration: 800; easing.type: Easing.OutQuad
                    onStopped: puff.t = -1
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) puffAnim.restart() }
            }
        }
    }
}
