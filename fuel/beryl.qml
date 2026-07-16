import QtQuick

// fuel: the forecourt seen from the road. beryl's page covers the center, so
// the station lives in the chrome bands — an icy tube humming over the tab
// strip, the canopy stripe + frozen mist under the status bar, breath leaking
// through the margins (the whole scene only surfaces on transparent pages).
// every committed navigation is pulling into a new bay: both tubes re-strike
// cold, top and bottom at once, then hand back to the steady burn.
Item {
    id: chrome

    required property var pal
    property var host: null   // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBorder: Qt.alpha(pal.neon, 0.28)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "⛽ OPEN ROAD"

    readonly property Component backdrop: Component {
        Item {
            // icy fluorescent haze rising off the ground, breathing like a tube hum
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 120
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.10) }
                }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: chrome.awake
                    NumberAnimation { to: 0.7; duration: 5200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 5200; easing.type: Easing.InOutSine }
                }
            }

            // frozen mist creeping over the ground under the status bar
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("mist.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // the tube over the tab strip — icy light falling on the tabs,
            // humming a slower breath than the canopy below
            Item {
                id: tube
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.topMargin: 2
                height: 24
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 22
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.alpha(chrome.pal.cyan, 0.13) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    height: 2
                    radius: 1
                    color: Qt.alpha(chrome.pal.cyan, 0.50)
                }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: chrome.awake
                    NumberAnimation { to: 0.7; duration: 4400; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 4400; easing.type: Easing.InOutSine }
                }
            }

            // the stripe + its bloom
            Item {
                id: canopy
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                anchors.bottomMargin: 2
                height: 30
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 26
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.neon, 0.20) }
                    }
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    height: 2.5
                    radius: 1
                    color: Qt.alpha(chrome.pal.neon, 0.75)
                }
                // tube flicker — a couple of dips, then a long steady burn
                SequentialAnimation {
                    running: chrome.awake
                    loops: Animation.Infinite
                    onStopped: canopy.opacity = 1
                    PauseAnimation { duration: 7000 }
                    NumberAnimation { target: canopy; property: "opacity"; to: 0.45; duration: 60 }
                    NumberAnimation { target: canopy; property: "opacity"; to: 1.0; duration: 90 }
                    NumberAnimation { target: canopy; property: "opacity"; to: 0.7; duration: 50 }
                    NumberAnimation { target: canopy; property: "opacity"; to: 1.0; duration: 140 }
                }
            }

            // re-strike — pulling into a new bay, both tubes arc cold at once:
            // a hard fluorescent stutter over the tab strip and the stripe,
            // then the steady burn takes back over
            Item {
                id: strike
                anchors.fill: parent
                opacity: 0
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    anchors.topMargin: 2; anchors.leftMargin: 10; anchors.rightMargin: 10
                    height: 2
                    radius: 1
                    color: Qt.alpha(chrome.pal.cyan, 0.95)
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    anchors.topMargin: 2
                    height: 10
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.alpha(chrome.pal.cyan, 0.28) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    anchors.bottomMargin: 2; anchors.leftMargin: 10; anchors.rightMargin: 10
                    height: 2.5
                    radius: 1
                    color: Qt.alpha(chrome.pal.cyan, 0.95)
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    anchors.bottomMargin: 2
                    height: 12
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.30) }
                    }
                }
            }
            SequentialAnimation {
                id: restrike
                PropertyAction { target: strike; property: "opacity"; value: 1 }
                PauseAnimation { duration: 45 }
                PropertyAction { target: strike; property: "opacity"; value: 0 }
                PauseAnimation { duration: 70 }
                PropertyAction { target: strike; property: "opacity"; value: 0.85 }
                PauseAnimation { duration: 55 }
                PropertyAction { target: strike; property: "opacity"; value: 0 }
                PauseAnimation { duration: 110 }
                PropertyAction { target: strike; property: "opacity"; value: 1 }
                NumberAnimation { target: strike; property: "opacity"; to: 0; duration: 340; easing.type: Easing.OutQuad }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) restrike.restart() }
            }
        }
    }
}
