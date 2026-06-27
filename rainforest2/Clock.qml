import QtQuick
import qs.services
import qs.modules.common

Item {
    id: root
    implicitWidth: 240
    implicitHeight: 240

    readonly property var now: DateTime.clock.date
    readonly property real hourAngle: ((now.getHours() % 12) + now.getMinutes() / 60) * 30
    readonly property real minuteAngle: now.getMinutes() * 6

    readonly property color colRing: Appearance.colors.colOnLayer0
    readonly property color colAccent: Appearance.colors.colPrimary
    readonly property color colMuted: Appearance.colors.colSubtext

    Rectangle {
        id: face
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.color: root.colRing
        border.width: 2
        antialiasing: true
        opacity: 0.85
    }

    Repeater {
        model: 12
        delegate: Text {
            required property int index
            readonly property int hour: index === 0 ? 12 : index
            readonly property real angle: (index * 30 - 90) * Math.PI / 180
            readonly property real radius: face.width / 2 - 20
            text: hour
            color: index % 3 === 0 ? root.colRing : root.colMuted
            opacity: index % 3 === 0 ? 0.95 : 0.55
            font.pixelSize: index % 3 === 0 ? 16 : 13
            font.family: "Google Sans Flex"
            font.weight: index % 3 === 0 ? Font.Medium : Font.Normal
            x: face.width / 2 + radius * Math.cos(angle) - width / 2
            y: face.height / 2 + radius * Math.sin(angle) - height / 2
        }
    }

    Rectangle {
        id: hourHand
        width: 6
        height: face.height * 0.28
        radius: width / 2
        color: root.colRing
        antialiasing: true
        x: face.width / 2 - width / 2
        y: face.height / 2 - height
        transformOrigin: Item.Bottom
        rotation: root.hourAngle
        Behavior on rotation {
            RotationAnimation { duration: 480; easing.type: Easing.OutCubic; direction: RotationAnimation.Shortest }
        }
    }

    Rectangle {
        id: minuteHand
        width: 4
        height: face.height * 0.4
        radius: width / 2
        color: root.colAccent
        antialiasing: true
        x: face.width / 2 - width / 2
        y: face.height / 2 - height
        transformOrigin: Item.Bottom
        rotation: root.minuteAngle
        Behavior on rotation {
            RotationAnimation { duration: 480; easing.type: Easing.OutCubic; direction: RotationAnimation.Shortest }
        }
    }

    Rectangle {
        width: 14; height: 14; radius: 7
        anchors.centerIn: face
        color: root.colAccent
        antialiasing: true
        Rectangle {
            anchors.centerIn: parent
            width: 4; height: 4; radius: 2
            color: root.colRing
            opacity: 0.85
        }
    }
}
