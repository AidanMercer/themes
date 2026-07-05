import QtQuick

// Cyberpunk: CRT shutter for the lock transition.
//
// The shell's LockStage drives host.progress 0→1 as the lock engages and back
// 1→0 on unlock, so one set of geometry plays both ways: near-black shutters
// split open like a tube warming up when locking, and collapse back into a
// bright beam when the password lands. Beam is neon with cyan/magenta ghosts,
// same chromatic grammar as the clock. Invisible (and free) at progress 1.
Item {
    id: fx

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host

    readonly property real p: host.progress
    // bright while the shutters are nearly closed, gone once they're open
    readonly property real beam: Math.max(0, Math.min(1, (1 - p) * 2.2 - 0.1))

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: parent.height / 2 * (1 - fx.p)
        color: "#05060c"
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: parent.height / 2 * (1 - fx.p)
        color: "#05060c"
    }

    Rectangle {
        width: parent.width; height: 3
        y: parent.height / 2 - height / 2 + 2
        color: fx.pal.magenta
        opacity: fx.beam * 0.55
    }
    Rectangle {
        width: parent.width; height: 3
        y: parent.height / 2 - height / 2 - 2
        color: fx.pal.cyan
        opacity: fx.beam * 0.55
    }
    Rectangle {
        width: parent.width; height: 2
        y: parent.height / 2 - height / 2
        color: fx.pal.neon
        opacity: fx.beam
    }
}
